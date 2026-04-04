#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Converts a VMware VMDK disk to a Hyper-V VHDX and optionally creates a VM.

.DESCRIPTION
    Wraps qemu-img to convert a VMDK (or OVA-extracted flat VMDK) to VHDX,
    then optionally creates a Generation 2 (UEFI) or Generation 1 (BIOS) VM
    in Hyper-V from the converted disk.

    Requirements:
      - qemu-img.exe on PATH or at $QemuImgPath
      - Hyper-V role enabled (for VM creation)
      - Sufficient disk space at the destination path

    Series:     The Hyper-V Renaissance
    Post:       7 - Migrating VMs from VMware to Hyper-V
    Repository: https://github.com/thisismydemo/hyper-v-renaissance

.PARAMETER SourceVMDK
    Full path to the source .vmdk file (flat or split).

.PARAMETER DestinationVHDX
    Full path for the output .vhdx file.

.PARAMETER VMName
    Name of the new Hyper-V VM. If omitted, VM creation is skipped.

.PARAMETER Generation
    1 = BIOS (Gen 1), 2 = UEFI (Gen 2, default). Use Gen 1 only for legacy OS.

.PARAMETER MemoryGB
    Startup and minimum dynamic memory in GB (default: 4).

.PARAMETER CPUCount
    Number of virtual processors (default: 4).

.PARAMETER SwitchName
    Virtual switch to connect the VM NIC to (default: first available external switch).

.PARAMETER QemuImgPath
    Full path to qemu-img.exe if not on PATH (default: qemu-img.exe).

.EXAMPLE
    # Convert only
    .\Convert-VMDKtoVHDX.ps1 -SourceVMDK "D:\exports\webserver.vmdk" `
                              -DestinationVHDX "D:\hyper-v\webserver.vhdx"

    # Convert and create Gen 2 VM
    .\Convert-VMDKtoVHDX.ps1 -SourceVMDK "D:\exports\webserver.vmdk" `
                              -DestinationVHDX "D:\hyper-v\webserver.vhdx" `
                              -VMName "WebServer-01" -MemoryGB 8 -CPUCount 4
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$SourceVMDK,

    [Parameter(Mandatory)]
    [string]$DestinationVHDX,

    [string]$VMName,
    [ValidateSet(1,2)]
    [int]$Generation = 2,
    [int]$MemoryGB = 4,
    [int]$CPUCount = 4,
    [string]$SwitchName,
    [string]$QemuImgPath = "qemu-img.exe"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Hyper-V Renaissance - VMDK to VHDX Conversion" -ForegroundColor Cyan
Write-Host "  Post 7: Migrating VMs from VMware to Hyper-V" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

#region --- Validate qemu-img ---
Write-Host "[1/4] Checking qemu-img..." -ForegroundColor Yellow
$qemu = Get-Command $QemuImgPath -ErrorAction SilentlyContinue
if (-not $qemu) {
    Write-Error "qemu-img not found at '$QemuImgPath'. Install from https://www.qemu.org/download/ or https://cloudbase.it/qemu-img-windows/"
}
$qemuVersion = & $QemuImgPath --version 2>&1 | Select-Object -First 1
Write-Host "  Found: $qemuVersion" -ForegroundColor Green
#endregion

#region --- Pre-flight disk space check ---
Write-Host "[2/4] Pre-flight checks..." -ForegroundColor Yellow

$sourceSizeGB = [math]::Round((Get-Item $SourceVMDK).Length / 1GB, 2)
Write-Host "  Source VMDK : $SourceVMDK ($sourceSizeGB GB)"

$destDir = Split-Path $DestinationVHDX -Parent
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Write-Host "  Created destination directory: $destDir" -ForegroundColor Yellow
}

$freeDisk = (Get-PSDrive -Name (Split-Path $destDir -Qualifier).TrimEnd(":")-ErrorAction SilentlyContinue)
if ($freeDisk) {
    $freeGB = [math]::Round($freeDisk.Free / 1GB, 2)
    if ($freeGB -lt ($sourceSizeGB * 1.2)) {
        Write-Warning "Only $freeGB GB free on destination drive. Need ~$([math]::Round($sourceSizeGB*1.2,1)) GB."
    }
}
Write-Host "  Destination : $DestinationVHDX" -ForegroundColor Cyan
#endregion

#region --- Convert VMDK -> VHDX ---
Write-Host "[3/4] Converting VMDK to VHDX (this may take several minutes)..." -ForegroundColor Yellow

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& $QemuImgPath convert -f vmdk -O vhdx -o subformat=dynamic $SourceVMDK $DestinationVHDX
if ($LASTEXITCODE -ne 0) {
    Write-Error "qemu-img conversion failed with exit code $LASTEXITCODE."
}
$stopwatch.Stop()

if (-not (Test-Path $DestinationVHDX)) {
    Write-Error "Conversion reported success but VHDX not found at $DestinationVHDX"
}
$vhdxSizeGB = [math]::Round((Get-Item $DestinationVHDX).Length / 1GB, 2)
Write-Host "  Conversion complete in $($stopwatch.Elapsed.ToString('mm\:ss'))" -ForegroundColor Green
Write-Host "  Output size : $vhdxSizeGB GB" -ForegroundColor Green
#endregion

#region --- Create Hyper-V VM (optional) ---
Write-Host "[4/4] Creating Hyper-V VM..." -ForegroundColor Yellow

if (-not $VMName) {
    Write-Host "  -VMName not specified. Skipping VM creation." -ForegroundColor Gray
    Write-Host "  To create manually, run:" -ForegroundColor Gray
    Write-Host "    New-VM -Name '<VMName>' -Generation $Generation -MemoryStartupBytes $($MemoryGB)GB -NoVHD" -ForegroundColor Gray
    Write-Host "    Add-VMHardDiskDrive -VMName '<VMName>' -Path '$DestinationVHDX'" -ForegroundColor Gray
} else {
    # Resolve virtual switch
    if (-not $SwitchName) {
        $SwitchName = (Get-VMSwitch | Where-Object SwitchType -eq External | Select-Object -First 1).Name
        if (-not $SwitchName) {
            Write-Warning "No external virtual switch found. VM will be created without a NIC."
        } else {
            Write-Host "  Auto-selected switch: $SwitchName" -ForegroundColor Yellow
        }
    }

    # Create VM
    $vmParams = @{
        Name               = $VMName
        Generation         = $Generation
        MemoryStartupBytes = [long]($MemoryGB * 1GB)
        NoVHD              = $true
    }
    $newVM = New-VM @vmParams
    Set-VM -Name $VMName -ProcessorCount $CPUCount -DynamicMemory `
           -MemoryMinimumBytes ([long]($MemoryGB * 1GB)) `
           -MemoryMaximumBytes ([long]($MemoryGB * 4GB))

    Add-VMHardDiskDrive -VMName $VMName -Path $DestinationVHDX

    if ($SwitchName) {
        Add-VMNetworkAdapter -VMName $VMName
        Connect-VMNetworkAdapter -VMName $VMName -SwitchName $SwitchName
    }

    # Gen 2 firmware: set DVD/SCSI boot order with OS disk first, disable Secure Boot
    # (Secure Boot can be re-enabled once guest boots successfully)
    if ($Generation -eq 2) {
        $firmware = Get-VMFirmware -VMName $VMName
        Set-VMFirmware -VMName $VMName `
            -SecureBoot Off `
            -BootOrder (Get-VMHardDiskDrive -VMName $VMName)
        Write-Host "  Gen 2: Secure Boot disabled — re-enable after first successful boot" -ForegroundColor Yellow
    }

    Write-Host "  VM '$VMName' created successfully." -ForegroundColor Green
    Get-VM -Name $VMName | Format-List Name, Generation, State, MemoryStartup, ProcessorCount
}
#endregion

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  NEXT STEPS" -ForegroundColor Cyan
Write-Host "`n  1. Start the VM and boot into Windows PE or the OS" -ForegroundColor White
Write-Host "  2. Uninstall VMware Tools from within the guest" -ForegroundColor White
Write-Host "  3. Run Invoke-PostMigrationValidation.ps1 -VMName '$VMName'" -ForegroundColor White
Write-Host "  4. Install Hyper-V Integration Services if not auto-installed" -ForegroundColor White
Write-Host "  5. Re-enable Secure Boot (Gen 2 only) after OS boots cleanly" -ForegroundColor White
Write-Host "  6. Update network adapter configuration (new MAC address)" -ForegroundColor White
Write-Host "`n  Linux Guest Cleanup (run from within Linux VM):" -ForegroundColor Yellow
Write-Host "    # Remove VMware tools"
Write-Host "    sudo apt remove open-vm-tools -y   # Debian/Ubuntu"
Write-Host "    sudo yum remove open-vm-tools -y   # RHEL/CentOS"
Write-Host "    # Install Hyper-V guest services"
Write-Host "    sudo apt install linux-virtual hyperv-daemons -y  # Debian/Ubuntu"
Write-Host "    sudo yum install hyperv-daemons -y                # RHEL/CentOS 7"
Write-Host "    # Enable and start LIS services"
Write-Host "    sudo systemctl enable hv-fcopy-daemon hv-kvp-daemon hv-vss-daemon"
Write-Host "    sudo systemctl start  hv-fcopy-daemon hv-kvp-daemon hv-vss-daemon"
Write-Host "============================================================`n" -ForegroundColor Cyan
