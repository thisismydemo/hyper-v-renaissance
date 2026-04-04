#Requires -Module VMware.PowerCLI
<#
.SYNOPSIS
    Generates a pre-migration VM inventory from VMware vCenter.

.DESCRIPTION
    Connects to vCenter and exports a comprehensive inventory of all VMs including
    compatibility flags for Hyper-V migration. Identifies consolidation requirements,
    firmware type, disk count, and potential blockers before starting any conversion.

    Series:     The Hyper-V Renaissance
    Post:       7 - Migrating VMs from VMware to Hyper-V
    Repository: https://github.com/thisismydemo/hyper-v-renaissance

.PARAMETER vCenter
    FQDN or IP of your vCenter Server.

.PARAMETER OutputPath
    Folder where the CSV inventory will be saved. Defaults to script directory.

.EXAMPLE
    .\Get-VMwareInventory.ps1 -vCenter "vcenter.yourdomain.local"
    .\Get-VMwareInventory.ps1 -vCenter "vcenter.yourdomain.local" -OutputPath "C:\MigrationData"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$vCenter,

    [string]$OutputPath = $PSScriptRoot
)

# Install VMware PowerCLI if not present
if (-not (Get-Module VMware.PowerCLI -ListAvailable)) {
    Write-Host "Installing VMware PowerCLI..." -ForegroundColor Yellow
    Install-Module VMware.PowerCLI -Scope AllUsers -Force
}

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Hyper-V Renaissance - VMware Pre-Migration Inventory" -ForegroundColor Cyan
Write-Host "  Post 7: Migrating VMs from VMware to Hyper-V" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

Write-Host "Connecting to vCenter: $vCenter..." -ForegroundColor Yellow
Connect-VIServer -Server $vCenter -ErrorAction Stop

Write-Host "Gathering VM inventory (this may take a few minutes)..." -ForegroundColor Yellow

$VMs = Get-VM

$Inventory = foreach ($VM in $VMs) {
    $Guest      = $VM.Guest
    $Disks      = $VM | Get-HardDisk
    $NICs       = $VM | Get-NetworkAdapter
    $Snapshots  = $VM | Get-Snapshot
    $Firmware   = $VM.ExtensionData.Config.Firmware  # bios or efi

    # Consolidation required?
    $NeedsConsolidation = ($VM.ExtensionData.Runtime.ConsolidationNeeded -eq $true)

    # VMware Tools status
    $ToolsStatus = $Guest.ToolsStatus

    # Paravirtual SCSI?
    $HasPVSCSI = $Disks | Where-Object { $_.ExtensionData.ControllerKey -match "1000" } | Select-Object -First 1

    # VMXNET3 NIC?
    $HasVMXNET3 = $NICs | Where-Object { $_.Type -eq "Vmxnet3" } | Select-Object -First 1

    # RDM?
    $HasRDM = $Disks | Where-Object { $_.DiskType -like "Raw*" } | Select-Object -First 1

    # Shared VMDK?
    $HasSharedDisk = $Disks | Where-Object { $_.Persistence -eq "Persistent" -and $VM.ExtensionData.Config.MultiVCPluginCompatibility } | Select-Object -First 1

    # Migration complexity
    $Blockers = @()
    $Warnings = @()
    if ($Snapshots.Count -gt 0)          { $Blockers  += "Snapshots must be consolidated ($($Snapshots.Count) found)" }
    if ($HasRDM)                          { $Blockers  += "RDM disk(s) require re-architecture" }
    if ($HasSharedDisk)                   { $Warnings  += "Shared VMDK detected — re-architecture may be needed" }
    if ($ToolsStatus -eq "toolsNotInstalled") { $Warnings += "VMware Tools not installed" }
    if ($VM.Guest.OSFullName -match "Linux" -and $ToolsStatus -ne "toolsNotInstalled") {
        $Warnings += "Linux VM: install Hyper-V drivers before migration"
    }
    $Complexity = if ($Blockers.Count -gt 0) { "HIGH - Blockers present" }
                  elseif ($Warnings.Count -gt 0) { "MEDIUM - Review warnings" }
                  else { "LOW - Ready to migrate" }

    [PSCustomObject]@{
        Name                = $VM.Name
        PowerState          = $VM.PowerState
        GuestOS             = $Guest.OSFullName
        Firmware            = $Firmware
        HyperVGeneration    = if ($Firmware -eq "efi") { "Gen 2" } else { "Gen 1" }
        vCPUs               = $VM.NumCpu
        MemoryGB            = $VM.MemoryGB
        ProvisionedGB       = [math]::Round($VM.ProvisionedSpaceGB, 2)
        UsedGB              = [math]::Round($VM.UsedSpaceGB, 2)
        DiskCount           = $Disks.Count
        NICCount            = $NICs.Count
        SnapshotCount       = $Snapshots.Count
        VMToolsStatus       = $ToolsStatus
        HasPVSCSI           = [bool]$HasPVSCSI
        HasVMXNET3          = [bool]$HasVMXNET3
        HasRDM              = [bool]$HasRDM
        NeedsConsolidation  = $NeedsConsolidation
        MigrationComplexity = $Complexity
        Blockers            = $Blockers -join "; "
        Warnings            = $Warnings -join "; "
        RecommendedTool     = if ($Blockers.Count -gt 0) { "Resolve blockers first" }
                              elseif ($VM.PowerState -eq "PoweredOn") { "WAC VM Conversion Extension (online)" }
                              else { "StarWind V2V or WAC (offline)" }
    }
}

# Output summary
$Total  = $Inventory.Count
$Low    = ($Inventory | Where-Object MigrationComplexity -like "LOW*").Count
$Medium = ($Inventory | Where-Object MigrationComplexity -like "MED*").Count
$High   = ($Inventory | Where-Object MigrationComplexity -like "HIGH*").Count

Write-Host "`n--- Migration Complexity Summary ---" -ForegroundColor White
Write-Host "  Total VMs :     $Total" -ForegroundColor White
Write-Host "  LOW  (ready) :  $Low"  -ForegroundColor Green
Write-Host "  MEDIUM (warn) : $Medium" -ForegroundColor Yellow
Write-Host "  HIGH (blocked): $High" -ForegroundColor Red

# Show HIGH complexity VMs immediately
if ($High -gt 0) {
    Write-Host "`n--- VMs Requiring Attention (HIGH complexity) ---" -ForegroundColor Red
    $Inventory | Where-Object MigrationComplexity -like "HIGH*" |
        Select-Object Name, Blockers | Format-Table -AutoSize -Wrap
}

# Export
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csvPath = Join-Path $OutputPath "VMware-Migration-Inventory-$timestamp.csv"
$Inventory | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "`nInventory exported to: $csvPath" -ForegroundColor Cyan

# Show full inventory table
Write-Host "`n--- Full VM Inventory ---" -ForegroundColor White
$Inventory | Select-Object Name, PowerState, HyperVGeneration, vCPUs, MemoryGB,
    UsedGB, SnapshotCount, VMToolsStatus, MigrationComplexity |
    Format-Table -AutoSize

Disconnect-VIServer -Server $vCenter -Confirm:$false
Write-Host "`nDisconnected from vCenter. Inventory complete." -ForegroundColor Green
