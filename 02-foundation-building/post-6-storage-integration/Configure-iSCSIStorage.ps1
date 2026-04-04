#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures iSCSI storage connectivity with MPIO on a Hyper-V host.

.DESCRIPTION
    Implements all iSCSI best practices from Post 6: Three-Tier Storage Integration.
    Covers MPIO policies, timeout tuning, multi-portal target connections, LUN
    initialization, and CSV preparation. Run on each cluster node.

    Series:     The Hyper-V Renaissance
    Post:       6 - Three-Tier Storage Integration
    Repository: https://github.com/thisismydemo/hyper-v-renaissance

.EXAMPLE
    .\Configure-iSCSIStorage.ps1
#>

[CmdletBinding()]
param()

# ============================================================
# !! EDIT THESE VARIABLES !!
# ============================================================
$InitiatorIP    = "10.10.30.11"                         # Host storage vNIC IP
$TargetPortals  = @("10.10.30.100","10.10.30.101")      # Storage array iSCSI interface IPs
$JumboMTU       = 9014                                  # Jumbo frame registry value (9014 bytes = 9000 MTU)
$StorageNICName = "vEthernet (Storage)"                 # Host storage vNIC name

# ============================================================
# Helper
# ============================================================
function Write-Step { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
function Write-Done { Write-Host "   Done." -ForegroundColor Green }

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Hyper-V Renaissance - iSCSI Storage Configuration" -ForegroundColor Cyan
Write-Host "  Post 6: Three-Tier Storage Integration" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# ============================================================
# Section 1: Jumbo Frames
# ============================================================
Write-Step "Configuring jumbo frames on storage vNIC ($StorageNICName)..."
Set-NetAdapterAdvancedProperty -Name $StorageNICName `
    -RegistryKeyword "*JumboPacket" -RegistryValue $JumboMTU -ErrorAction SilentlyContinue

# Verify
$jumbo = Get-NetAdapterAdvancedProperty -Name $StorageNICName `
    -RegistryKeyword "*JumboPacket" -ErrorAction SilentlyContinue
Write-Host "   Jumbo frame setting: $($jumbo.RegistryValue)"

Write-Host "   Testing jumbo frame connectivity (requires storage network to be up)..." -ForegroundColor Yellow
foreach ($portal in $TargetPortals) {
    $result = ping -f -l 8972 $portal -n 1 2>&1
    if ($result -match "Reply from") {
        Write-Host "   Jumbo ping to ${portal}: OK" -ForegroundColor Green
    } else {
        Write-Host "   Jumbo ping to ${portal}: FAILED - verify MTU on switch and storage array" -ForegroundColor Yellow
    }
}

# ============================================================
# Section 2: Flow Control on Physical NICs
# ============================================================
Write-Step "Enabling flow control on physical team member NICs..."
$physicalNICs = Get-VMSwitchTeam -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty NetAdapterInterfaceDescription |
    ForEach-Object { Get-NetAdapter -InterfaceDescription $_ -ErrorAction SilentlyContinue }

foreach ($nic in $physicalNICs) {
    Set-NetAdapterAdvancedProperty -Name $nic.Name `
        -RegistryKeyword "*FlowControl" -RegistryValue 3 -ErrorAction SilentlyContinue
    Write-Host "   Flow control (Rx+Tx) set on $($nic.Name)"
}
Write-Done

# ============================================================
# Section 3: MPIO Configuration
# ============================================================
Write-Step "Configuring MPIO for iSCSI..."

# Verify MPIO is installed and claiming iSCSI
Enable-MSDSMAutomaticClaim -BusType iSCSI -ErrorAction SilentlyContinue
Write-Host "   MPIO auto-claim settings:"
Get-MSDSMAutomaticClaimSettings | Format-Table -AutoSize

# Set Round Robin as the default LB policy
Set-MSDSMGlobalDefaultLoadBalancePolicy -Policy RR
Write-Host "   Load balance policy set to Round Robin"

# ============================================================
# Section 4: iSCSI Timeout Tuning
# ============================================================
Write-Step "Tuning iSCSI timeout values for production reliability..."

$iSCSIParamsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\iScsiPrt\Parameters"
if (-not (Test-Path $iSCSIParamsPath)) { New-Item -Path $iSCSIParamsPath -Force | Out-Null }

# MaxRequestHoldTime: seconds to hold I/O requests during path failover (default 60)
Set-ItemProperty -Path $iSCSIParamsPath -Name "MaxRequestHoldTime" -Value 90 -Type DWord
# LinkDownTime: seconds before marking a link as down (default 15)
Set-ItemProperty -Path $iSCSIParamsPath -Name "LinkDownTime" -Value 35 -Type DWord
# Disk timeout
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\disk" `
    -Name "TimeOutValue" -Value 60 -Type DWord

Write-Host "   MaxRequestHoldTime: 90s | LinkDownTime: 35s | DiskTimeout: 60s"
Write-Done

# ============================================================
# Section 5: iSCSI Initiator Service
# ============================================================
Write-Step "Starting iSCSI Initiator service..."
Set-Service -Name MSiSCSI -StartupType Automatic
Start-Service -Name MSiSCSI

$IQN = (Get-InitiatorPort -ErrorAction SilentlyContinue).NodeAddress
Write-Host "   Host IQN: $IQN" -ForegroundColor Cyan

# ============================================================
# Section 6: Add Target Portals and Connect
# ============================================================
Write-Step "Adding iSCSI target portals..."
foreach ($portal in $TargetPortals) {
    New-IscsiTargetPortal -TargetPortalAddress $portal `
        -InitiatorPortalAddress $InitiatorIP `
        -ErrorAction SilentlyContinue
    Write-Host "   Added portal: $portal"
}

Write-Step "Discovering iSCSI targets..."
$Targets = Get-IscsiTarget
Write-Host "   Discovered $($Targets.Count) target(s):" -ForegroundColor White
$Targets | ForEach-Object { Write-Host "     $($_.NodeAddress)" }

Write-Step "Connecting to all targets via all portals with MPIO..."
foreach ($Target in $Targets) {
    foreach ($Portal in $TargetPortals) {
        Connect-IscsiTarget -NodeAddress $Target.NodeAddress `
            -TargetPortalAddress $Portal `
            -InitiatorPortalAddress $InitiatorIP `
            -IsPersistent $true `
            -IsMultipathEnabled $true `
            -ErrorAction SilentlyContinue
        Write-Host "   Connected $($Target.NodeAddress.Substring(0,[Math]::Min(50,$Target.NodeAddress.Length))) via $Portal"
    }
}

# ============================================================
# Section 7: Verification
# ============================================================
Write-Step "Verifying iSCSI sessions and MPIO paths..."

Write-Host "`n   Active iSCSI Sessions:" -ForegroundColor White
Get-IscsiSession | Format-Table TargetNodeAddress, IsConnected, IsPersistent, NumberOfConnections -AutoSize

Write-Host "   MPIO Disk Paths:" -ForegroundColor White
mpclaim -s -d

Write-Host "   Visible SAN Disks:" -ForegroundColor White
Get-Disk | Where-Object { $_.BusType -eq "iSCSI" -or $_.Path -like "*MPIO*" } |
    Select-Object Number, @{N='Size GB';E={[math]::Round($_.Size/1GB,2)}}, BusType, OperationalStatus, PartitionStyle |
    Format-Table -AutoSize

# ============================================================
# Section 8: Initialize and Format New LUNs (optional)
# ============================================================
Write-Step "Checking for uninitialized SAN disks..."
$NewDisks = Get-Disk | Where-Object { $_.PartitionStyle -eq "RAW" -and $_.BusType -eq "iSCSI" }

if ($NewDisks.Count -gt 0) {
    Write-Host "   Found $($NewDisks.Count) uninitialized iSCSI disk(s)." -ForegroundColor Yellow
    Write-Host "   To initialize for CSV use, uncomment the block below or run manually." -ForegroundColor Gray
    <#
    foreach ($Disk in $NewDisks) {
        Write-Host "   Initializing Disk $($Disk.Number) ($([math]::Round($Disk.Size/1GB))GB)..." -ForegroundColor Yellow
        Initialize-Disk -Number $Disk.Number -PartitionStyle GPT
        $Partition = New-Partition -DiskNumber $Disk.Number -UseMaximumSize -AssignDriveLetter
        Format-Volume -Partition $Partition -FileSystem NTFS `
            -AllocationUnitSize 65536 -NewFileSystemLabel "CSV-Vol-$($Disk.Number)" -Confirm:$false
        Write-Host "   Formatted as CSV-Vol-$($Disk.Number) with 64KB allocation units" -ForegroundColor Green
    }
    #>
} else {
    Write-Host "   No uninitialized iSCSI disks found." -ForegroundColor Green
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  iSCSI storage configuration complete." -ForegroundColor Cyan
Write-Host "  Run this script on each cluster node." -ForegroundColor Cyan
Write-Host "  Next: Configure-PureStorage.ps1 (if using Pure Storage)" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan
