#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Deploys a production-ready Hyper-V node through all 7 configuration phases.

.DESCRIPTION
    Executes all phases from Post 5: Build and Validate a Cluster-Ready Hyper-V Host.
    Covers OS configuration, roles/features, SET networking, storage (iSCSI/MPIO),
    Hyper-V host settings, and pre-cluster validation. Designed to be run on each
    cluster node with per-node variable customization at the top of the script.

    Series:     The Hyper-V Renaissance
    Post:       5 - Build and Validate a Cluster-Ready Host
    Repository: https://github.com/thisismydemo/hyper-v-renaissance

.PARAMETER Phase
    Which phase to run. Default is "All". Options: All, 1, 1b, 2, 3, 4, 4b, 5, 6, 7
    Phases 1, 2, and 4 can trigger or require reboots. Run them interactively or via a staged deployment.

.EXAMPLE
    .\Deploy-HyperVNode.ps1
    .\Deploy-HyperVNode.ps1 -Phase 3
#>

[CmdletBinding()]
param(
    [ValidateSet("All","1","1b","2","3","4","4b","5","6","7")]
    [string]$Phase = "All"
)

# ============================================================
# !! EDIT THESE VARIABLES FOR EACH NODE !!
# ============================================================
$HostName           = "HV-NODE-01"
$DomainName         = "yourdomain.local"
$DomainOUPath       = "OU=Hyper-V Hosts,OU=Servers,DC=yourdomain,DC=local"
$TimeZoneId         = "Eastern Standard Time"

# Networking
$TeamMembers        = @("NIC1","NIC2","NIC3","NIC4")  # Replace with Get-NetAdapter output
$MgmtIP             = "10.10.10.11"
$MgmtPrefix         = 24
$MgmtGateway        = "10.10.10.1"
$MgmtDNS            = @("10.10.10.5","10.10.10.6")
$MgmtVLAN           = 10
$LiveMigrationIP    = "10.10.20.11"
$LiveMigrationVLAN  = 20
$StorageIP          = "10.10.30.11"
$StorageVLAN        = 30

# Storage (iSCSI)
$iSCSITargetPortals  = @("10.10.30.100","10.10.30.101")
$iSCSITargetIQN      = "iqn.2010-06.com.storagevendor:targetname"  # Replace with your array's IQN

# Hyper-V
$VMDefaultPath      = "D:\VMs"
$VHDDefaultPath     = "D:\VHDs"
$LiveMigSubnet      = "10.10.20.0/24"

# ============================================================
# Helper
# ============================================================
function Write-Phase {
    param([string]$Title)
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

# ============================================================
# Phase 1: Base OS Configuration
# ============================================================
if ($Phase -in "All","1") {
    Write-Phase "Phase 1: Base OS Configuration"

    Write-Host "Setting hostname to $HostName..." -ForegroundColor Yellow
    Rename-Computer -NewName $HostName -Force

    Write-Host "Setting time zone: $TimeZoneId..." -ForegroundColor Yellow
    Set-TimeZone -Id $TimeZoneId

    Write-Host "Configuring Windows Update (download, no auto-install)..." -ForegroundColor Yellow
    $AUPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $AUPath)) { New-Item -Path $AUPath -Force | Out-Null }
    Set-ItemProperty -Path $AUPath -Name "AUOptions" -Value 3 -Type DWord -Force

    Write-Host "Enabling Remote Desktop..." -ForegroundColor Yellow
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
        -Name "fDenyTSConnections" -Value 0 -Force
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

    Write-Host "Enabling PS Remoting and WinRM..." -ForegroundColor Yellow
    Enable-PSRemoting -Force
    winrm quickconfig -quiet

    Write-Host "Rebooting to apply hostname change..." -ForegroundColor Yellow
    Write-Host "Re-run this script with -Phase 1b to join the domain after reboot." -ForegroundColor Gray
    # Uncomment to auto-reboot:
    # Restart-Computer -Force
}

# Phase 1b: Domain Join (run after Phase 1 reboot)
if ($Phase -in "All","1b") {
    Write-Phase "Phase 1b: Domain Join"
    $Credential = Get-Credential -Message "Enter domain admin credentials for $DomainName"
    Add-Computer -DomainName $DomainName -Credential $Credential `
        -OUPath $DomainOUPath -Force
    Write-Host "Domain joined. Rebooting..." -ForegroundColor Yellow
    # Restart-Computer -Force
}

# ============================================================
# Phase 2: Roles and Features
# ============================================================
if ($Phase -in "All","2") {
    Write-Phase "Phase 2: Roles and Features Installation"

    $Features = @(
        "Hyper-V",
        "Failover-Clustering",
        "Multipath-IO",
        "RSAT-Clustering-PowerShell",
        "RSAT-Hyper-V-Tools",
        "Hyper-V-PowerShell",
        "Data-Center-Bridging"
    )

    Write-Host "Installing features: $($Features -join ', ')..." -ForegroundColor Yellow
    Write-Host "This phase uses Install-WindowsFeature -Restart and can reboot the host automatically." -ForegroundColor Gray
    Install-WindowsFeature -Name $Features -IncludeManagementTools -Restart

    # After reboot, verify
    Write-Host "Verifying installed features..." -ForegroundColor Yellow
    Get-WindowsFeature | Where-Object { $_.Installed -and $_.Name -in $Features } |
        Format-Table Name, InstallState -AutoSize
}

# ============================================================
# Phase 3: SET Virtual Switch and Host vNIC Configuration
# ============================================================
if ($Phase -in "All","3") {
    Write-Phase "Phase 3: SET Virtual Switch Configuration"

    Write-Host "Creating SET virtual switch with members: $($TeamMembers -join ', ')..." -ForegroundColor Yellow
    New-VMSwitch -Name "SET-Switch" `
        -NetAdapterName $TeamMembers `
        -EnableEmbeddedTeaming $true `
        -AllowManagementOS $true `
        -MinimumBandwidthMode Weight

    Write-Host "Renaming default management vNIC..." -ForegroundColor Yellow
    Rename-VMNetworkAdapter -ManagementOS -Name "SET-Switch" -NewName "Management"

    Write-Host "Creating LiveMigration and Storage vNICs..." -ForegroundColor Yellow
    Add-VMNetworkAdapter -ManagementOS -SwitchName "SET-Switch" -Name "LiveMigration"
    Add-VMNetworkAdapter -ManagementOS -SwitchName "SET-Switch" -Name "Storage"

    Write-Host "Assigning VLANs..." -ForegroundColor Yellow
    Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "Management"      -Access -VlanId $MgmtVLAN
    Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "LiveMigration"   -Access -VlanId $LiveMigrationVLAN
    Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "Storage"         -Access -VlanId $StorageVLAN

    Write-Host "Assigning IP addresses..." -ForegroundColor Yellow
    New-NetIPAddress -InterfaceAlias "vEthernet (Management)" `
        -IPAddress $MgmtIP -PrefixLength $MgmtPrefix -DefaultGateway $MgmtGateway
    Set-DnsClientServerAddress -InterfaceAlias "vEthernet (Management)" `
        -ServerAddresses $MgmtDNS

    New-NetIPAddress -InterfaceAlias "vEthernet (LiveMigration)" `
        -IPAddress $LiveMigrationIP -PrefixLength 24

    New-NetIPAddress -InterfaceAlias "vEthernet (Storage)" `
        -IPAddress $StorageIP -PrefixLength 24

    Write-Host "Setting bandwidth weights..." -ForegroundColor Yellow
    Set-VMNetworkAdapter -ManagementOS -Name "Management"     -MinimumBandwidthWeight 10
    Set-VMNetworkAdapter -ManagementOS -Name "LiveMigration"  -MinimumBandwidthWeight 30
    Set-VMNetworkAdapter -ManagementOS -Name "Storage"        -MinimumBandwidthWeight 40

    Write-Host "`nVerifying SET switch..." -ForegroundColor Cyan
    Get-VMSwitch | Format-Table Name, SwitchType, EmbeddedTeamingEnabled -AutoSize
    Get-VMNetworkAdapterVlan -ManagementOS | Format-Table -AutoSize
    Get-NetIPAddress -InterfaceAlias "vEthernet*" |
        Select-Object InterfaceAlias, IPAddress, PrefixLength | Format-Table -AutoSize

    Write-Host "SET Switch configuration complete." -ForegroundColor Green
}

# ============================================================
# Phase 4: Storage Preparation (iSCSI + MPIO)
# ============================================================
if ($Phase -in "All","4") {
    Write-Phase "Phase 4: Storage Preparation"

    Write-Host "Enabling MPIO for iSCSI..." -ForegroundColor Yellow
    Enable-MSDSMAutomaticClaim -BusType iSCSI
    Write-Host "Reboot required after enabling iSCSI MPIO claims. Rebooting..." -ForegroundColor Yellow
    # Restart-Computer -Force
    # After reboot, run Phase 4b:
}

# Phase 4b: iSCSI Initiator configuration (run after Phase 4 reboot)
if ($Phase -in "All","4b") {
    Write-Phase "Phase 4b: iSCSI Initiator Configuration"

    Write-Host "Starting iSCSI Initiator service..." -ForegroundColor Yellow
    Set-Service -Name MSiSCSI -StartupType Automatic
    Start-Service -Name MSiSCSI

    $IQN = (Get-InitiatorPort).NodeAddress
    Write-Host "iSCSI Initiator IQN: $IQN" -ForegroundColor Cyan

    foreach ($Portal in $iSCSITargetPortals) {
        Write-Host "Adding target portal: $Portal..." -ForegroundColor Yellow
        New-IscsiTargetPortal -TargetPortalAddress $Portal -InitiatorPortalAddress $StorageIP
    }

    Write-Host "Discovering targets..." -ForegroundColor Yellow
    Get-IscsiTarget

    foreach ($Portal in $iSCSITargetPortals) {
        Write-Host "Connecting to $iSCSITargetIQN via $Portal..." -ForegroundColor Yellow
        Connect-IscsiTarget -NodeAddress $iSCSITargetIQN `
            -TargetPortalAddress $Portal `
            -InitiatorPortalAddress $StorageIP `
            -IsPersistent $true `
            -IsMultipathEnabled $true
    }

    Write-Host "Setting SAN policy to OnlineAll..." -ForegroundColor Yellow
    Set-StorageSetting -NewDiskPolicy OnlineAll

    Write-Host "Verifying iSCSI sessions..." -ForegroundColor Cyan
    Get-IscsiSession | Format-Table InitiatorNodeAddress, TargetNodeAddress, IsConnected, IsPersistent -AutoSize
    mpclaim -s -d
}

# ============================================================
# Phase 5: Hyper-V Host Configuration
# ============================================================
if ($Phase -in "All","5") {
    Write-Phase "Phase 5: Hyper-V Host Configuration"

    Write-Host "Creating VM storage directories..." -ForegroundColor Yellow
    New-Item -Path $VMDefaultPath  -ItemType Directory -Force | Out-Null
    New-Item -Path $VHDDefaultPath -ItemType Directory -Force | Out-Null

    Write-Host "Setting Hyper-V default paths..." -ForegroundColor Yellow
    Set-VMHost -VirtualMachinePath $VMDefaultPath -VirtualHardDiskPath $VHDDefaultPath

    Write-Host "Configuring Live Migration..." -ForegroundColor Yellow
    Enable-VMMigration
    Set-VMMigrationNetwork $LiveMigSubnet
    Set-VMHost -VirtualMachineMigrationAuthenticationType Kerberos
    Set-VMHost -MaximumVirtualMachineMigrations 4
    Set-VMHost -MaximumStorageMigrations 2

    Write-Host "Configuring NUMA and enhanced session mode..." -ForegroundColor Yellow
    Set-VMHost -NumaSpanningEnabled $true
    Set-VMHost -EnableEnhancedSessionMode $true

    Write-Host "Verifying host configuration..." -ForegroundColor Cyan
    Get-VMHost | Format-List VirtualMachinePath, VirtualHardDiskPath,
        VirtualMachineMigrationEnabled, VirtualMachineMigrationAuthenticationType,
        MaximumVirtualMachineMigrations, MaximumStorageMigrations, NumaSpanningEnabled

    Write-Host "Hyper-V host configuration complete." -ForegroundColor Green
}

# ============================================================
# Phase 6: Pre-Cluster Validation (see also Validate-HyperVNode.ps1)
# ============================================================
if ($Phase -in "All","6") {
    Write-Phase "Phase 6: Pre-Cluster Validation"
    Write-Host "For full validation, run Validate-HyperVNode.ps1 from the same folder." -ForegroundColor Yellow
    Write-Host "Quick checks below:" -ForegroundColor Yellow

    # Quick NIC check
    Write-Host "`n[Network]" -ForegroundColor White
    Get-NetAdapter -Name "vEthernet*" | ForEach-Object {
        $color = if ($_.Status -eq "Up") { "Green" } else { "Red" }
        Write-Host "  $($_.Name): $($_.Status)" -ForegroundColor $color
    }

    # Quick feature check
    Write-Host "`n[Features]" -ForegroundColor White
    @("Hyper-V","Failover-Clustering","Multipath-IO") | ForEach-Object {
        $f = Get-WindowsFeature -Name $_
        $color = if ($f.InstallState -eq "Installed") { "Green" } else { "Red" }
        Write-Host "  $($_): $($f.InstallState)" -ForegroundColor $color
    }

    # Hypervisor present
    Write-Host "`n[Hypervisor]" -ForegroundColor White
    $hvPresent = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
    $color = if ($hvPresent) { "Green" } else { "Red" }
    Write-Host "  Hypervisor running: $hvPresent" -ForegroundColor $color
}

# ============================================================
# Phase 7: Basic Host Hardening
# ============================================================
if ($Phase -in "All","7") {
    Write-Phase "Phase 7: Basic Host Hardening"

    Write-Host "Enabling Windows Defender real-time monitoring..." -ForegroundColor Yellow
    Set-MpPreference -DisableRealtimeMonitoring $false

    Write-Host "Adding Hyper-V exclusions to Defender..." -ForegroundColor Yellow
    $Exclusions = @(
        $VMDefaultPath, $VHDDefaultPath,
        "%ProgramData%\Microsoft\Windows\Hyper-V",
        "%SystemRoot%\System32\vmms.exe",
        "%SystemRoot%\System32\vmwp.exe",
        "%SystemRoot%\System32\vmcompute.exe"
    )
    foreach ($Excl in $Exclusions) { Add-MpPreference -ExclusionPath $Excl }
    Add-MpPreference -ExclusionExtension "vhd","vhdx","avhd","avhdx","vhds","iso"

    Write-Host "Enabling Credential Guard (requires UEFI Secure Boot + TPM 2.0)..." -ForegroundColor Yellow
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" `
        -Name "EnableVirtualizationBasedSecurity" -Value 1 -Type DWord
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
        -Name "LsaCfgFlags" -Value 1 -Type DWord

    Write-Host "Disabling unnecessary services..." -ForegroundColor Yellow
    foreach ($Svc in @("Browser","lltdsvc","rspndr","SharedAccess","WlanSvc")) {
        $service = Get-Service -Name $Svc -ErrorAction SilentlyContinue
        if ($service) {
            Set-Service -Name $Svc -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service -Name $Svc -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "Enabling SMB encryption..." -ForegroundColor Yellow
    Set-SmbServerConfiguration -EncryptData $true -Force

    Write-Host "Host hardening complete." -ForegroundColor Green
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Deploy-HyperVNode.ps1 complete (Phase: $Phase)" -ForegroundColor Cyan
Write-Host "  Next: Run Validate-HyperVNode.ps1 for full pre-cluster validation." -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan
