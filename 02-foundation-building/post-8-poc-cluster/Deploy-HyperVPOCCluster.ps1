#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Hyper-V Renaissance Series — Post 8: POC Cluster Deployment
    Deploys a complete 2-node Hyper-V POC cluster end-to-end.

.DESCRIPTION
    Automates the full POC cluster build from Post 8 of the Hyper-V Renaissance blog series:
      - Node prerequisite validation
      - Role and feature installation
      - SET virtual switch and vNIC configuration
      - iSCSI storage configuration (or Windows iSCSI Target setup)
      - Cluster validation (Test-Cluster)
      - Cluster creation with shared storage and CSVs
      - Quorum configuration
      - Highly available VM deployment
      - Live migration and failover testing

    Run this script on HV-NODE-01 after both nodes are domain-joined and
    Windows Server 2025 Datacenter is installed. Adjust the Variables section
    before running.

.PARAMETER NodeNumber
    Node identifier ("01" or "02"). Drives per-node IP addressing.

.PARAMETER SkipNodeConfig
    Skip node configuration phases and jump directly to cluster creation.
    Use when both nodes are already configured independently.

.EXAMPLE
    # Configure this node (run locally on each node)
    .\Deploy-HyperVPOCCluster.ps1 -NodeNumber "01"

    # After both nodes are configured, create the cluster from node 01
    .\Deploy-HyperVPOCCluster.ps1 -NodeNumber "01" -SkipNodeConfig

.NOTES
    Series:  The Hyper-V Renaissance
    Post:    8 — POC Like You Mean It
    Repo:    https://github.com/thisismydemo/hyper-v-renaissance
    Author:  thisismydemo
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateSet("01","02")]
    [string]$NodeNumber = "01",

    [Parameter()]
    [switch]$SkipNodeConfig
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# VARIABLES — Edit these before running
# ============================================================

$Config = @{
    # Node identity
    NodeName        = "HV-NODE-$NodeNumber"
    MgmtIP          = "10.10.10.1$NodeNumber"
    MigrationIP     = "10.10.20.1$NodeNumber"
    StorageIP       = "10.10.30.1$NodeNumber"
    Gateway         = "10.10.10.1"
    DNS             = @("10.10.10.5", "10.10.10.6")
    DomainName      = "yourdomain.local"

    # Cluster identity (used only on Node 01 during cluster creation)
    ClusterName     = "HV-CLUSTER-01"
    ClusterIP       = "10.10.10.20"
    ClusterNodes    = @("HV-NODE-01", "HV-NODE-02")

    # Storage
    iSCSITargetIP   = "10.10.30.100"
    iSCSITargetIP2  = "10.10.30.101"   # Second path for MPIO

    # VM defaults (created during cluster verification phase)
    TestVMName      = "POC-TestVM-01"
    TestVMMemGB     = 2
}

# ============================================================
# HELPERS
# ============================================================

function Write-Phase {
    param([string]$Message)
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Write-Pass  { param([string]$Msg) Write-Host "  [PASS] $Msg" -ForegroundColor Green }
function Write-Fail  { param([string]$Msg) Write-Host "  [FAIL] $Msg" -ForegroundColor Red }
function Write-Info  { param([string]$Msg) Write-Host "  [INFO] $Msg" -ForegroundColor White }
function Write-Warn  { param([string]$Msg) Write-Host "  [WARN] $Msg" -ForegroundColor Yellow }

# ============================================================
# PHASE 0 — PREREQUISITES
# ============================================================

if (-not $SkipNodeConfig) {

    Write-Phase "Phase 0: Prerequisites"

    # Verify domain membership
    $CSDomain = (Get-CimInstance Win32_ComputerSystem).Domain
    if ($CSDomain -eq $Config.DomainName) {
        Write-Pass "Domain joined: $CSDomain"
    } else {
        Write-Fail "Not joined to $($Config.DomainName) — current domain: $CSDomain"
        Write-Warn "Join the domain first, reboot, then re-run this script."
        exit 1
    }

    # Verify Windows Server 2025
    $OSCaption = (Get-CimInstance Win32_OperatingSystem).Caption
    if ($OSCaption -like "*2025*") {
        Write-Pass "OS: $OSCaption"
    } else {
        Write-Warn "OS: $OSCaption — Windows Server 2025 Datacenter is recommended."
    }

    # Verify physical NICs
    $PhysicalNICs = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
    Write-Info "Physical NICs up: $($PhysicalNICs.Count)"
    if ($PhysicalNICs.Count -lt 2) {
        Write-Fail "Minimum 2 physical NICs required. Found: $($PhysicalNICs.Count)"
        exit 1
    }

    # ============================================================
    # PHASE 1 — ROLES AND FEATURES
    # ============================================================

    Write-Phase "Phase 1: Roles and Features"

    $Features = @(
        "Hyper-V",
        "Failover-Clustering",
        "Multipath-IO",
        "RSAT-Clustering-PowerShell",
        "RSAT-Hyper-V-Tools",
        "Hyper-V-PowerShell",
        "Data-Center-Bridging"
    )

    $Missing = $Features | Where-Object {
        (Get-WindowsFeature -Name $_).InstallState -ne "Installed"
    }

    if ($Missing) {
        Write-Info "Installing: $($Missing -join ', ')"
        Install-WindowsFeature -Name $Missing -IncludeManagementTools -Restart
        # Script resumes after reboot via -Restart
    } else {
        Write-Pass "All required roles already installed."
    }

    # Verify after install
    foreach ($Feature in $Features) {
        $State = (Get-WindowsFeature -Name $Feature).InstallState
        if ($State -eq "Installed") { Write-Pass "$Feature" }
        else { Write-Fail "$Feature — InstallState: $State" }
    }

    # ============================================================
    # PHASE 2 — NETWORKING (SET Switch)
    # ============================================================

    Write-Phase "Phase 2: Networking — SET Virtual Switch"

    $ExistingSwitch = Get-VMSwitch -Name "SET-Switch" -ErrorAction SilentlyContinue
    if (-not $ExistingSwitch) {
        $NICNames = (Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }).Name

        New-VMSwitch -Name "SET-Switch" `
            -NetAdapterName $NICNames `
            -EnableEmbeddedTeaming $true `
            -AllowManagementOS $true `
            -MinimumBandwidthMode Weight
        Write-Pass "SET switch created with NICs: $($NICNames -join ', ')"
    } else {
        Write-Pass "SET-Switch already exists."
    }

    # Rename management vNIC
    $MgmtVNIC = Get-VMNetworkAdapter -ManagementOS | Where-Object { $_.Name -eq "SET-Switch" }
    if ($MgmtVNIC) {
        Rename-VMNetworkAdapter -ManagementOS -Name "SET-Switch" -NewName "Management"
    }

    # Create additional vNICs if not already present
    $vNICNames = (Get-VMNetworkAdapter -ManagementOS).Name
    foreach ($vNIC in @("LiveMigration","Storage")) {
        if ($vNIC -notin $vNICNames) {
            Add-VMNetworkAdapter -ManagementOS -SwitchName "SET-Switch" -Name $vNIC
            Write-Pass "Created vNIC: $vNIC"
        } else {
            Write-Pass "vNIC $vNIC already exists."
        }
    }

    # Assign IPs
    $IPAssignments = @(
        @{ Alias = "vEthernet (Management)";     IP = $Config.MgmtIP;       PL = 24; GW = $Config.Gateway },
        @{ Alias = "vEthernet (LiveMigration)";  IP = $Config.MigrationIP;  PL = 24; GW = $null },
        @{ Alias = "vEthernet (Storage)";        IP = $Config.StorageIP;    PL = 24; GW = $null }
    )

    foreach ($Assignment in $IPAssignments) {
        $Existing = Get-NetIPAddress -InterfaceAlias $Assignment.Alias -ErrorAction SilentlyContinue |
            Where-Object { $_.AddressFamily -eq "IPv4" -and $_.IPAddress -eq $Assignment.IP }
        if (-not $Existing) {
            if ($Assignment.GW) {
                New-NetIPAddress -InterfaceAlias $Assignment.Alias `
                    -IPAddress $Assignment.IP -PrefixLength $Assignment.PL `
                    -DefaultGateway $Assignment.GW | Out-Null
            } else {
                New-NetIPAddress -InterfaceAlias $Assignment.Alias `
                    -IPAddress $Assignment.IP -PrefixLength $Assignment.PL | Out-Null
            }
            Write-Pass "$($Assignment.Alias): $($Assignment.IP)"
        } else {
            Write-Pass "$($Assignment.Alias): $($Assignment.IP) already set."
        }
    }

    Set-DnsClientServerAddress -InterfaceAlias "vEthernet (Management)" `
        -ServerAddresses $Config.DNS

    # ============================================================
    # PHASE 3 — STORAGE (iSCSI + MPIO)
    # ============================================================

    Write-Phase "Phase 3: Storage — MPIO and iSCSI"

    Enable-MSDSMAutomaticClaim -BusType iSCSI

    Set-Service -Name MSiSCSI -StartupType Automatic
    Start-Service -Name MSiSCSI
    Write-Pass "iSCSI Initiator service running."

    $IQN = (Get-InitiatorPort).NodeAddress
    Write-Info "iSCSI Initiator IQN: $IQN"

    # Add target portals
    foreach ($Portal in @($Config.iSCSITargetIP, $Config.iSCSITargetIP2)) {
        $Existing = Get-IscsiTargetPortal -TargetPortalAddress $Portal -ErrorAction SilentlyContinue
        if (-not $Existing) {
            New-IscsiTargetPortal -TargetPortalAddress $Portal `
                -InitiatorPortalAddress $Config.StorageIP | Out-Null
            Write-Pass "Added iSCSI portal: $Portal"
        } else {
            Write-Pass "iSCSI portal $Portal already configured."
        }
    }

    # Connect to available targets
    $Targets = Get-IscsiTarget | Where-Object { -not $_.IsConnected }
    foreach ($Target in $Targets) {
        foreach ($Portal in @($Config.iSCSITargetIP, $Config.iSCSITargetIP2)) {
            Connect-IscsiTarget -NodeAddress $Target.NodeAddress `
                -TargetPortalAddress $Portal `
                -InitiatorPortalAddress $Config.StorageIP `
                -IsPersistent $true `
                -IsMultipathEnabled $true | Out-Null
        }
        Write-Pass "Connected to iSCSI target: $($Target.NodeAddress)"
    }

    # Set SAN policy
    Set-StorageSetting -NewDiskPolicy OnlineAll

    # ============================================================
    # PHASE 4 — HYPER-V HOST SETTINGS
    # ============================================================

    Write-Phase "Phase 4: Hyper-V Host Configuration"

    Enable-VMMigration
    $MigSubnet = ($Config.MigrationIP -replace "\.\d+$", ".0") + "/24"
    Set-VMMigrationNetwork $MigSubnet
    Set-VMHost -VirtualMachineMigrationAuthenticationType CredSSP
    Set-VMHost -MaximumVirtualMachineMigrations 2
    Set-VMHost -MaximumStorageMigrations 2
    Set-VMHost -NumaSpanningEnabled $true

    Write-Pass "Hyper-V host configured for live migration (CredSSP, POC mode)."
    Write-Info "Note: Switch to Kerberos + constrained delegation for production (see Post 5)."

} # end -not $SkipNodeConfig

# ============================================================
# PHASE 5 — CLUSTER CREATION (Node 01 only, after both nodes ready)
# ============================================================

if ($NodeNumber -eq "01") {

    Write-Phase "Phase 5: Cluster Creation"

    $ExistingCluster = Get-Cluster -Name $Config.ClusterName -ErrorAction SilentlyContinue
    if ($ExistingCluster) {
        Write-Pass "Cluster $($Config.ClusterName) already exists."
    } else {
        # Validate nodes
        Write-Info "Running Test-Cluster on $($Config.ClusterNodes -join ', ') — this takes 10–20 minutes..."
        Test-Cluster -Node $Config.ClusterNodes | Out-Null
        $Report = Get-ChildItem "$env:SystemRoot\Cluster\Reports" -Filter "Validation*" |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Info "Validation report: $($Report.FullName)"

        # Create cluster
        Write-Info "Creating cluster $($Config.ClusterName)..."
        New-Cluster -Name $Config.ClusterName `
            -Node $Config.ClusterNodes `
            -StaticAddress $Config.ClusterIP `
            -NoStorage | Out-Null
        Write-Pass "Cluster $($Config.ClusterName) created."
    }

    # Verify nodes
    $Nodes = Get-ClusterNode
    foreach ($Node in $Nodes) {
        if ($Node.State -eq "Up") { Write-Pass "Node $($Node.Name): Up" }
        else { Write-Fail "Node $($Node.Name): $($Node.State)" }
    }

    # ============================================================
    # PHASE 6 — CLUSTER STORAGE AND CSVs
    # ============================================================

    Write-Phase "Phase 6: Cluster Storage and CSVs"

    # Initialize any RAW shared disks
    $RawDisks = Get-Disk | Where-Object { $_.PartitionStyle -eq "RAW" }
    foreach ($Disk in $RawDisks) {
        Initialize-Disk -Number $Disk.Number -PartitionStyle GPT
        $Partition = New-Partition -DiskNumber $Disk.Number -UseMaximumSize
        $Label = if ($Disk.Size -le 5GB) { "Quorum" } else { "CSV-$($Disk.Number)" }
        Format-Volume -Partition $Partition -FileSystem NTFS `
            -AllocationUnitSize 65536 `
            -NewFileSystemLabel $Label -Confirm:$false | Out-Null
        Write-Pass "Initialized Disk $($Disk.Number) as $Label"
    }

    # Add available disks to cluster
    Get-ClusterAvailableDisk | Add-ClusterDisk | Out-Null

    # Convert non-quorum cluster disks to CSVs
    $ClusterDisks = Get-ClusterResource |
        Where-Object { $_.ResourceType -eq "Physical Disk" -and $_.Name -notlike "*Quorum*" }
    foreach ($Disk in $ClusterDisks) {
        Add-ClusterSharedVolume -Name $Disk.Name | Out-Null
        Write-Pass "Converted to CSV: $($Disk.Name)"
    }

    # Configure quorum
    $QuorumResource = Get-ClusterResource |
        Where-Object { $_.ResourceType -eq "Physical Disk" -and $_.Name -like "*Quorum*" }
    if ($QuorumResource) {
        Set-ClusterQuorum -DiskWitness $QuorumResource.Name
        Write-Pass "Quorum: Disk witness configured."
    } else {
        Write-Warn "No quorum disk found. Configure quorum manually:"
        Write-Warn "  File share:  Set-ClusterQuorum -FileShareWitness '\\server\share'"
        Write-Warn "  Cloud:       Set-ClusterQuorum -CloudWitness -AccountName '<sa>' -AccessKey '<key>'"
    }

    # ============================================================
    # PHASE 7 — TEST HA VM
    # ============================================================

    Write-Phase "Phase 7: Deploy Test HA VM"

    $CSVPath = (Get-ClusterSharedVolume | Select-Object -First 1).SharedVolumeInfo.FriendlyVolumeName
    $VMPath  = Join-Path $CSVPath "VMs\$($Config.TestVMName)"
    New-Item -Path $VMPath -ItemType Directory -Force | Out-Null

    $ExistingVM = Get-VM -Name $Config.TestVMName -ErrorAction SilentlyContinue
    if (-not $ExistingVM) {
        New-VM -Name $Config.TestVMName `
            -MemoryStartupBytes ($Config.TestVMMemGB * 1GB) `
            -NewVHDPath "$VMPath\$($Config.TestVMName).vhdx" `
            -NewVHDSizeBytes 40GB `
            -SwitchName "SET-Switch" `
            -Generation 2 `
            -Path $VMPath | Out-Null

        Set-VM -Name $Config.TestVMName `
            -ProcessorCount 2 `
            -DynamicMemory `
            -MemoryMinimumBytes 512MB `
            -MemoryMaximumBytes ($Config.TestVMMemGB * 2GB) `
            -AutomaticStartAction Start `
            -AutomaticStopAction ShutDown

        Add-ClusterVirtualMachineRole -VMName $Config.TestVMName | Out-Null
        Write-Pass "VM $($Config.TestVMName) created and added to cluster."
    } else {
        Write-Pass "VM $($Config.TestVMName) already exists."
    }

    # ============================================================
    # PHASE 8 — FINAL VALIDATION REPORT
    # ============================================================

    Write-Phase "Phase 8: POC Validation Report"

    $Cluster = Get-Cluster
    Write-Info "Cluster : $($Cluster.Name)"
    Write-Info "Domain  : $($Cluster.Domain)"

    foreach ($Node in (Get-ClusterNode)) {
        if ($Node.State -eq "Up") { Write-Pass "Node $($Node.Name): Up" }
        else { Write-Fail "Node $($Node.Name): $($Node.State)" }
    }

    foreach ($CSV in (Get-ClusterSharedVolume)) {
        $Info = $CSV.SharedVolumeInfo
        $FreeGB  = [math]::Round($Info.Partition.FreeSpace / 1GB, 1)
        $TotalGB = [math]::Round($Info.Partition.Size / 1GB, 1)
        if ($CSV.State -eq "Online") {
            Write-Pass "CSV $($CSV.Name): Online on $($CSV.OwnerNode) — $FreeGB GB free of $TotalGB GB"
        } else {
            Write-Fail "CSV $($CSV.Name): $($CSV.State)"
        }
    }

    $Quorum = Get-ClusterQuorum
    Write-Info "Quorum  : $($Quorum.QuorumType) — $($Quorum.QuorumResource)"

    $HAVM = Get-ClusterGroup $Config.TestVMName -ErrorAction SilentlyContinue
    if ($HAVM) {
        if ($HAVM.State -eq "Online") { Write-Pass "HA VM $($Config.TestVMName): Online on $($HAVM.OwnerNode)" }
        else { Write-Fail "HA VM $($Config.TestVMName): $($HAVM.State)" }
    } else {
        Write-Warn "HA VM $($Config.TestVMName) not found as a cluster group."
    }

    Write-Host "`n  POC deployment complete. Run Test-HyperVPOCFailover.ps1 to validate HA." -ForegroundColor Cyan

} else {
    Write-Info "Node $NodeNumber configuration complete."
    Write-Info "Switch to HV-NODE-01 and run: .\Deploy-HyperVPOCCluster.ps1 -NodeNumber 01 -SkipNodeConfig"
}
