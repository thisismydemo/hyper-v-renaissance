#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures Pure Storage FlashArray for a Hyper-V cluster: host group, volumes, and connections.

.DESCRIPTION
    Implements the Pure Storage reference implementation from Post 6: Three-Tier Storage Integration.
    Creates host objects on the array from the cluster node IQNs, creates a host group,
    and provisions Cluster Shared Volume LUNs with best-practice settings.

    Requires the PureStoragePowerShellSDK2 module. Install via:
        Install-Module -Name PureStoragePowerShellSDK2 -Force

    Series:     The Hyper-V Renaissance
    Post:       6 - Three-Tier Storage Integration
    Repository: https://github.com/thisismydemo/hyper-v-renaissance

.PARAMETER ArrayEndpoint
    FQDN or IP of the Pure Storage FlashArray management interface.

.PARAMETER ClusterNodes
    Hostnames of the Hyper-V cluster nodes to add to the array host group.

.EXAMPLE
    .\Configure-PureStorage.ps1 -ArrayEndpoint "pure-array-01.yourdomain.local" -ClusterNodes "HV-NODE-01","HV-NODE-02"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ArrayEndpoint,

    [Parameter(Mandatory)]
    [string[]]$ClusterNodes
)

# ============================================================
# !! EDIT THESE VARIABLES !!
# ============================================================
$HostGroupName = "HyperV-Cluster-01"

# Volumes to create and present to the cluster
# Add/remove entries as needed
$Volumes = @(
    @{ Name = "CSV-Prod-01"; SizeBytes = 2TB },
    @{ Name = "CSV-Prod-02"; SizeBytes = 2TB },
    @{ Name = "CSV-Quorum";  SizeBytes = 5GB  }
)

# ============================================================
# Prerequisites
# ============================================================
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Hyper-V Renaissance - Pure Storage Configuration" -ForegroundColor Cyan
Write-Host "  Post 6: Three-Tier Storage Integration" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

if (-not (Get-Module PureStoragePowerShellSDK2 -ListAvailable)) {
    Write-Host "Installing PureStoragePowerShellSDK2..." -ForegroundColor Yellow
    Install-Module -Name PureStoragePowerShellSDK2 -Force -Scope AllUsers
}
Import-Module PureStoragePowerShellSDK2

# ============================================================
# Connect to FlashArray
# ============================================================
Write-Host "Connecting to FlashArray: $ArrayEndpoint" -ForegroundColor Yellow
$Credential = Get-Credential -Message "Enter FlashArray admin credentials"
$FlashArray = Connect-Pfa2Array -EndPoint $ArrayEndpoint -Credential $Credential

Write-Host "Connected to $ArrayEndpoint" -ForegroundColor Green

# ============================================================
# Create Host Group
# ============================================================
Write-Host "`n>> Creating host group: $HostGroupName..." -ForegroundColor Cyan

$existingHG = Get-Pfa2HostGroup -Array $FlashArray -Name $HostGroupName -ErrorAction SilentlyContinue
if (-not $existingHG) {
    New-Pfa2HostGroup -Array $FlashArray -Name $HostGroupName
    Write-Host "   Host group created." -ForegroundColor Green
} else {
    Write-Host "   Host group already exists." -ForegroundColor Yellow
}

# ============================================================
# Create Host Objects from Cluster Node IQNs
# ============================================================
Write-Host "`n>> Discovering IQNs from cluster nodes and creating array host objects..." -ForegroundColor Cyan

foreach ($Node in $ClusterNodes) {
    Write-Host "   Node: $Node" -ForegroundColor White

    # Get IQN from the remote node
    $IQN = Invoke-Command -ComputerName $Node -ScriptBlock {
        (Get-InitiatorPort -ErrorAction SilentlyContinue).NodeAddress | Select-Object -First 1
    } -ErrorAction SilentlyContinue

    if (-not $IQN) {
        Write-Host "   WARNING: Could not retrieve IQN from $Node. Skipping." -ForegroundColor Yellow
        continue
    }

    Write-Host "     IQN: $IQN" -ForegroundColor Cyan

    # Create host on the array
    $existingHost = Get-Pfa2Host -Array $FlashArray -Name $Node -ErrorAction SilentlyContinue
    if (-not $existingHost) {
        New-Pfa2Host -Array $FlashArray -Name $Node -IqnList @($IQN)
        Write-Host "     Host object created." -ForegroundColor Green
    } else {
        Write-Host "     Host object already exists." -ForegroundColor Yellow
    }

    # Add to host group
    $memberCheck = Get-Pfa2HostGroupHost -Array $FlashArray -GroupName $HostGroupName -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $Node }
    if (-not $memberCheck) {
        New-Pfa2HostGroupHost -Array $FlashArray -GroupName $HostGroupName -MemberName $Node
        Write-Host "     Added to host group $HostGroupName." -ForegroundColor Green
    } else {
        Write-Host "     Already in host group." -ForegroundColor Yellow
    }
}

# ============================================================
# Create and Present Volumes
# ============================================================
Write-Host "`n>> Creating and presenting volumes..." -ForegroundColor Cyan

foreach ($Vol in $Volumes) {
    Write-Host "   Volume: $($Vol.Name) ($([math]::Round($Vol.SizeBytes/1TB,2)) TB)" -ForegroundColor White

    $existingVol = Get-Pfa2Volume -Array $FlashArray -Name $Vol.Name -ErrorAction SilentlyContinue
    if (-not $existingVol) {
        New-Pfa2Volume -Array $FlashArray -Name $Vol.Name -Provisioned $Vol.SizeBytes
        Write-Host "     Volume created." -ForegroundColor Green
    } else {
        Write-Host "     Volume already exists." -ForegroundColor Yellow
    }

    # Connect volume to host group
    $existingConn = Get-Pfa2Connection -Array $FlashArray -VolumeName $Vol.Name -ErrorAction SilentlyContinue |
        Where-Object { $_.Host.Name -eq $HostGroupName -or $_.HostGroup.Name -eq $HostGroupName }
    if (-not $existingConn) {
        New-Pfa2Connection -Array $FlashArray -VolumeName $Vol.Name -HostGroupName $HostGroupName
        Write-Host "     Connected to host group." -ForegroundColor Green
    } else {
        Write-Host "     Already connected." -ForegroundColor Yellow
    }
}

# ============================================================
# Rescan on all cluster nodes
# ============================================================
Write-Host "`n>> Rescanning storage on all cluster nodes..." -ForegroundColor Cyan

foreach ($Node in $ClusterNodes) {
    Write-Host "   Rescanning $Node..." -ForegroundColor White
    Invoke-Command -ComputerName $Node -ScriptBlock {
        Update-HostStorageCache
        Get-IscsiSession -ErrorAction SilentlyContinue | Update-IscsiTarget -ErrorAction SilentlyContinue
    } -ErrorAction SilentlyContinue
    Write-Host "   Rescan complete." -ForegroundColor Green
}

# ============================================================
# Verify on local node
# ============================================================
Write-Host "`n>> Verifying new disks are visible on this node..." -ForegroundColor Cyan
Update-HostStorageCache
Get-Disk | Where-Object { $_.PartitionStyle -eq "RAW" -and $_.BusType -eq "iSCSI" } |
    Select-Object Number, @{N='Size GB';E={[math]::Round($_.Size/1GB,2)}}, BusType, FriendlyName |
    Format-Table -AutoSize

# ============================================================
# Summary
# ============================================================
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Pure Storage configuration complete." -ForegroundColor Cyan
Write-Host "  Host group:  $HostGroupName" -ForegroundColor Green
Write-Host "  Volumes created and connected: $($Volumes.Count)" -ForegroundColor Green
Write-Host "  Next: Initialize disks on one node, then add to cluster (Post 8)" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan
