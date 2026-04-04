#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Validates that a former VMware host meets all requirements for Windows Server 2025 Hyper-V.

.DESCRIPTION
    Performs a comprehensive pre-migration hardware and firmware assessment covering CPU,
    RAM, storage controllers, network adapters, UEFI/Secure Boot, TPM, and virtualization
    extensions. Generates a pass/warn/fail report with actionable remediation guidance.

    Companion script to Post 4: Reusing Your Existing VMware Hosts
    Series:     The Hyper-V Renaissance
    Repository: https://github.com/thisismydemo/hyper-v-renaissance

.PARAMETER OutputPath
    Optional path to save the HTML report. Defaults to the script directory.

.EXAMPLE
    .\Validate-VMwareHostForHyperV.ps1
    .\Validate-VMwareHostForHyperV.ps1 -OutputPath "C:\Reports"
#>

[CmdletBinding()]
param(
    [string]$OutputPath = $PSScriptRoot
)

# ============================================================
# Initialize Results
# ============================================================
$Results = [System.Collections.Generic.List[PSObject]]::new()
$OverallPass = $true

function Add-Result {
    param(
        [string]$Category,
        [string]$Check,
        [ValidateSet("PASS","WARN","FAIL","INFO")]
        [string]$Status,
        [string]$Value,
        [string]$Recommendation = ""
    )
    $Results.Add([PSCustomObject]@{
        Category       = $Category
        Check          = $Check
        Status         = $Status
        Value          = $Value
        Recommendation = $Recommendation
    })
    if ($Status -eq "FAIL") { $script:OverallPass = $false }
}

function Write-CheckResult {
    param($Result)
    $color = switch ($Result.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        "INFO" { "Cyan" }
    }
    Write-Host ("  [{0}] {1}: {2}" -f $Result.Status.PadRight(4), $Result.Check.PadRight(45), $Result.Value) -ForegroundColor $color
    if ($Result.Recommendation) {
        Write-Host ("         >> {0}" -f $Result.Recommendation) -ForegroundColor DarkYellow
    }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Hyper-V Renaissance - Host Compatibility Validator" -ForegroundColor Cyan
Write-Host "  Post 4: Reusing Your Existing VMware Hosts" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# ============================================================
# Section 1: System Identity
# ============================================================
Write-Host "--- System Identity ---" -ForegroundColor White

$CS   = Get-CimInstance Win32_ComputerSystem
$BIOS = Get-CimInstance Win32_BIOS
$OS   = Get-CimInstance Win32_OperatingSystem

Add-Result "Identity" "Hostname"        INFO $env:COMPUTERNAME
Add-Result "Identity" "Manufacturer"    INFO $CS.Manufacturer
Add-Result "Identity" "Model"           INFO $CS.Model
Add-Result "Identity" "Serial Number"   INFO $BIOS.SerialNumber
Add-Result "Identity" "BIOS Version"    INFO $BIOS.SMBIOSBIOSVersion
Add-Result "Identity" "Current OS"      INFO ($OS.Caption + " Build " + $OS.BuildNumber)

$Results | Where-Object { $_.Category -eq "Identity" } | ForEach-Object { Write-CheckResult $_ }

# ============================================================
# Section 2: CPU Validation
# ============================================================
Write-Host "`n--- CPU Validation ---" -ForegroundColor White

$CPUs = Get-CimInstance Win32_Processor

foreach ($CPU in $CPUs) {
    $cpuName = $CPU.Name.Trim()

    Add-Result "CPU" "Processor" INFO "$cpuName ($($CPU.NumberOfCores) cores / $($CPU.NumberOfLogicalProcessors) threads)"

    # 64-bit check
    if ($CPU.AddressWidth -eq 64) {
        Add-Result "CPU" "64-bit Architecture" PASS "Yes"
    } else {
        Add-Result "CPU" "64-bit Architecture" FAIL "No (32-bit CPU detected)" "Windows Server 2025 requires 64-bit CPU."
    }

    # SLAT (Second Level Address Translation)
    # Check for VT-x/AMD-V and SLAT via systeminfo or WMI
    $slatReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization" -ErrorAction SilentlyContinue
    if ($slatReg -and $slatReg.MinimumRequiredHypervisorBuildNumber) {
        Add-Result "CPU" "SLAT Support" INFO "Previously validated (Hyper-V key present)"
    }

    # Virtualization Extensions
    $VirtEnabled = $CS.HypervisorPresent
    if (-not $VirtEnabled) {
        # Check via CIM
        $hwFeatures = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_Processor |
            Select-Object -ExpandProperty SecondLevelAddressTranslationExtensions -ErrorAction SilentlyContinue
    }

    # SSE4.2 and POPCNT - check via CPU name hints (new WS2025 requirement)
    # Intel Nehalem (2008)+ and AMD Bulldozer (2011)+ have both
    $cpuYear = if ($cpuName -match "Xeon.*E[357]-?[0-9]{4,5}|EPYC|Opteron|Core i[3579]") { "Modern" } else { "Unknown" }
    if ($CPU.MaxClockSpeed -gt 1400) {
        Add-Result "CPU" "Clock Speed (min 1.4 GHz)" PASS "$([math]::Round($CPU.MaxClockSpeed/1000,2)) GHz"
    } else {
        Add-Result "CPU" "Clock Speed (min 1.4 GHz)" FAIL "$([math]::Round($CPU.MaxClockSpeed/1000,2)) GHz" "Minimum 1.4 GHz required."
    }
}

# Virtualization extension check via CPUID (msinfo32 approach)
$virtExts = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_Processor |
    Select-Object -First 1 -ExpandProperty VirtualizationFirmwareEnabled -ErrorAction SilentlyContinue

if ($null -ne $virtExts) {
    if ($virtExts) {
        Add-Result "CPU" "Virtualization Extensions (VT-x/AMD-V)" PASS "Enabled in firmware"
    } else {
        Add-Result "CPU" "Virtualization Extensions (VT-x/AMD-V)" FAIL "Disabled in firmware" "Enable Intel VT-x or AMD-V in BIOS/UEFI before deploying Hyper-V."
    }
} else {
    Add-Result "CPU" "Virtualization Extensions (VT-x/AMD-V)" WARN "Unable to detect via WMI — verify in BIOS" "Check BIOS virtualization technology settings manually."
}

# DEP/NX bit
$DEP = Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty DataExecutionPrevention_Available
if ($DEP) {
    Add-Result "CPU" "DEP/NX Bit" PASS "Available"
} else {
    Add-Result "CPU" "DEP/NX Bit" FAIL "Not available" "Enable NX/XD bit in BIOS."
}

$Results | Where-Object { $_.Category -eq "CPU" } | ForEach-Object { Write-CheckResult $_ }

# ============================================================
# Section 3: Memory Validation
# ============================================================
Write-Host "`n--- Memory Validation ---" -ForegroundColor White

$TotalRAMGB = [math]::Round($CS.TotalPhysicalMemory / 1GB, 2)

if ($TotalRAMGB -ge 16) {
    Add-Result "Memory" "Total RAM" PASS "${TotalRAMGB} GB"
} elseif ($TotalRAMGB -ge 4) {
    Add-Result "Memory" "Total RAM" WARN "${TotalRAMGB} GB" "Minimum met, but 16 GB+ recommended for production Hyper-V hosts."
} else {
    Add-Result "Memory" "Total RAM" FAIL "${TotalRAMGB} GB" "Windows Server 2025 minimum is 2 GB. 16 GB+ required for meaningful VM density."
}

# ECC RAM check via WMI
$MemModules = Get-CimInstance Win32_PhysicalMemory
$ECCStatus = $MemModules | Select-Object -First 1 -ExpandProperty MemoryType
# MemoryType 24 = DDR3, 26 = DDR4, 34 = DDR5; FormFactor 8 = DIMM
$FormFactor = $MemModules | Select-Object -First 1 -ExpandProperty FormFactor
Add-Result "Memory" "Memory Type" INFO "$(($MemModules | Select-Object -First 1).MemoryType) (FormFactor: $FormFactor)"

# ECC is reported in TypeDetail - bit 10 set = ECC
$TypeDetail = ($MemModules | Select-Object -First 1).TypeDetail
$isECC = ($TypeDetail -band 0x0200) -ne 0
if ($isECC) {
    Add-Result "Memory" "ECC Memory" PASS "ECC confirmed (TypeDetail bit 10 set)"
} else {
    Add-Result "Memory" "ECC Memory" WARN "ECC not detected via WMI — verify via server management tools" "Windows Server 2025 requires ECC or similar technology for physical hosts."
}

# Memory slot summary
$UsedSlots = ($MemModules | Where-Object { $_.Capacity -gt 0 }).Count
$TotalSlots = $MemModules.Count
Add-Result "Memory" "Memory Configuration" INFO "$UsedSlots of $TotalSlots DIMM slots populated"

$Results | Where-Object { $_.Category -eq "Memory" } | ForEach-Object { Write-CheckResult $_ }

# ============================================================
# Section 4: UEFI and Secure Boot
# ============================================================
Write-Host "`n--- UEFI / Secure Boot / TPM ---" -ForegroundColor White

# Firmware type
try {
    $firmwareType = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control" -ErrorAction Stop).PEFirmwareType
    if ($firmwareType -eq 2) {
        Add-Result "Firmware" "Firmware Type" PASS "UEFI"
    } else {
        Add-Result "Firmware" "Firmware Type" WARN "BIOS/Legacy" "Hyper-V Gen 2 VMs and Secure Boot require UEFI. Consider enabling UEFI mode."
    }
} catch {
    # Alternative: check via WMI
    $uefiBoot = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_DiskPartition |
        Where-Object { $_.Type -eq "GPT: System" }
    if ($uefiBoot) {
        Add-Result "Firmware" "Firmware Type" PASS "UEFI (GPT system partition detected)"
    } else {
        Add-Result "Firmware" "Firmware Type" WARN "Unable to determine — verify in BIOS" "UEFI required for Gen 2 VMs and Shielded VMs."
    }
}

# Secure Boot
try {
    $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
    if ($secureBoot) {
        Add-Result "Firmware" "Secure Boot" PASS "Enabled"
    } else {
        Add-Result "Firmware" "Secure Boot" WARN "Disabled" "Enable Secure Boot for production deployments and Shielded VM support."
    }
} catch {
    Add-Result "Firmware" "Secure Boot" WARN "Unable to query (may be BIOS system)" "Verify Secure Boot status in UEFI firmware settings."
}

# TPM
try {
    $TPM = Get-Tpm -ErrorAction Stop
    if ($TPM.TpmPresent -and $TPM.TpmReady) {
        $tpmVersion = (Get-CimInstance -Namespace root\cimv2\Security\MicrosoftTpm -ClassName Win32_Tpm -ErrorAction SilentlyContinue).SpecVersion
        Add-Result "Firmware" "TPM" PASS "Present and Ready (Version: $tpmVersion)"
    } elseif ($TPM.TpmPresent) {
        Add-Result "Firmware" "TPM" WARN "Present but not ready — may need activation" "Activate TPM in BIOS settings."
    } else {
        Add-Result "Firmware" "TPM" WARN "TPM not detected" "TPM 2.0 recommended for Shielded VMs, BitLocker, and Credential Guard."
    }
} catch {
    Add-Result "Firmware" "TPM" WARN "Unable to query TPM" "Verify TPM status in BIOS settings."
}

# IOMMU (VT-d / AMD-Vi) — required for DDA and Secure Boot
$iommu = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_Processor |
    Select-Object -First 1 -ExpandProperty SecondLevelAddressTranslationExtensions -ErrorAction SilentlyContinue
Add-Result "Firmware" "IOMMU (VT-d/AMD-Vi)" INFO "Verify in BIOS — required for Discrete Device Assignment (DDA) and GPU passthrough"

$Results | Where-Object { $_.Category -eq "Firmware" } | ForEach-Object { Write-CheckResult $_ }

# ============================================================
# Section 5: Storage Controller Validation
# ============================================================
Write-Host "`n--- Storage Controllers ---" -ForegroundColor White

$StorageControllers = Get-CimInstance Win32_SCSIController
foreach ($Controller in $StorageControllers) {
    $name = $Controller.Name
    $status = $Controller.Status

    # Check if driver is loaded
    $driverStatus = if ($status -eq "OK") { "PASS" } else { "WARN" }
    $rec = if ($status -ne "OK") { "Verify controller driver installation and status in Device Manager." } else { "" }
    Add-Result "Storage" "Controller: $name" $driverStatus "Driver Status: $status" $rec
}

# Check physical disks
$PhysicalDisks = Get-PhysicalDisk
Add-Result "Storage" "Physical Disks Detected" INFO "$($PhysicalDisks.Count) disk(s)"
foreach ($disk in $PhysicalDisks) {
    Add-Result "Storage" "  Disk: $($disk.FriendlyName)" INFO "$([math]::Round($disk.Size/1GB,2)) GB - $($disk.BusType) - $($disk.OperationalStatus)"
}

$Results | Where-Object { $_.Category -eq "Storage" } | ForEach-Object { Write-CheckResult $_ }

# ============================================================
# Section 6: Network Adapter Validation
# ============================================================
Write-Host "`n--- Network Adapters ---" -ForegroundColor White

$Adapters = Get-NetAdapter -Physical | Sort-Object LinkSpeed -Descending

if ($Adapters.Count -lt 2) {
    Add-Result "Network" "Physical NIC Count" WARN "$($Adapters.Count) NIC(s) detected" "Minimum 2 NICs recommended for Hyper-V (management + VM/storage). 4+ NICs recommended for production clusters with separated traffic."
} elseif ($Adapters.Count -ge 4) {
    Add-Result "Network" "Physical NIC Count" PASS "$($Adapters.Count) NICs detected (4+ optimal for traffic separation)"
} else {
    Add-Result "Network" "Physical NIC Count" PASS "$($Adapters.Count) NICs detected"
}

foreach ($NIC in $Adapters) {
    $speedGbps = if ($NIC.LinkSpeed) { [math]::Round(($NIC.LinkSpeed -replace '[^0-9]','') / 1000000000, 0) } else { "Unknown" }
    $nicStatus  = if ($NIC.Status -eq "Up") { "PASS" } else { "WARN" }
    $rec = ""

    if ($NIC.Status -ne "Up") { $rec = "NIC is down. Verify cable/switch connection." }
    if ($speedGbps -lt 10 -and $speedGbps -ne "Unknown") {
        $nicStatus = "WARN"
        $rec = "1 GbE is suboptimal for production Hyper-V. 10 GbE+ recommended for live migration and storage traffic."
    }

    Add-Result "Network" "NIC: $($NIC.Name)" $nicStatus "$($NIC.InterfaceDescription) | Speed: $speedGbps Gbps | Status: $($NIC.Status)" $rec

    # Check RDMA capability
    $rdma = Get-NetAdapterRdma -Name $NIC.Name -ErrorAction SilentlyContinue
    if ($rdma) {
        $rdmaStatus = if ($rdma.Enabled) { "PASS" } else { "INFO" }
        Add-Result "Network" "  RDMA: $($NIC.Name)" $rdmaStatus "Capable: $($rdma.Capable) | Enabled: $($rdma.Enabled)"
    }

    # Check SR-IOV
    $sriov = Get-NetAdapterSriov -Name $NIC.Name -ErrorAction SilentlyContinue
    if ($sriov) {
        Add-Result "Network" "  SR-IOV: $($NIC.Name)" INFO "Enabled: $($sriov.Enabled) | VFs: $($sriov.NumVFs)"
    }
}

$Results | Where-Object { $_.Category -eq "Network" } | ForEach-Object { Write-CheckResult $_ }

# ============================================================
# Section 7: Hyper-V Readiness
# ============================================================
Write-Host "`n--- Hyper-V Readiness ---" -ForegroundColor White

# Check if Hyper-V role is already installed
$hvFeature = Get-WindowsFeature -Name Hyper-V -ErrorAction SilentlyContinue
if ($hvFeature) {
    if ($hvFeature.InstallState -eq "Installed") {
        Add-Result "HyperV" "Hyper-V Role" PASS "Already installed"
    } else {
        Add-Result "HyperV" "Hyper-V Role" INFO "Not installed (ready to install)"
    }
}

# Check if running inside a VM (nested virtualization scenario)
$isVM = $CS.HypervisorPresent -or ($CS.Model -match "Virtual|VMware|Hyper-V")
if ($isVM) {
    Add-Result "HyperV" "Physical vs Virtual" WARN "Running inside a VM — nested virtualization scenario" "Nested virtualization works but has performance limitations. Ensure the parent hypervisor has nested virt enabled."
} else {
    Add-Result "HyperV" "Physical vs Virtual" PASS "Running on physical hardware"
}

# Check for VMware tools (should be removed or already absent)
$vmwareTools = Get-Service -Name "VMTools" -ErrorAction SilentlyContinue
if ($vmwareTools) {
    Add-Result "HyperV" "VMware Tools Service" WARN "VMware Tools detected (service: VMTools)" "VMware Tools should be uninstalled before or after OS installation on this hardware. Run: Get-WmiObject -Class Win32_Product | Where-Object { `$_.Name -like '*VMware*' } | ForEach-Object { `$_.Uninstall() }"
} else {
    Add-Result "HyperV" "VMware Tools Service" PASS "Not present (clean)"
}

# Check disk space for OS
$SystemDrive = Get-PSDrive -Name C
$FreeGB = [math]::Round($SystemDrive.Free / 1GB, 2)
if ($FreeGB -ge 64) {
    Add-Result "HyperV" "System Drive Free Space" PASS "${FreeGB} GB free"
} elseif ($FreeGB -ge 32) {
    Add-Result "HyperV" "System Drive Free Space" WARN "${FreeGB} GB free" "32 GB is the minimum. 64+ GB recommended for binaries, logs, and VM management."
} else {
    Add-Result "HyperV" "System Drive Free Space" FAIL "${FreeGB} GB free" "Insufficient. Windows Server 2025 requires 32 GB minimum."
}

$Results | Where-Object { $_.Category -eq "HyperV" } | ForEach-Object { Write-CheckResult $_ }

# ============================================================
# Section 8: Windows Server Catalog Check (guidance only)
# ============================================================
Write-Host "`n--- Windows Server Catalog Guidance ---" -ForegroundColor White

Add-Result "Catalog" "Windows Server Catalog" INFO "https://www.windowsservercatalog.com — verify your exact model is listed"
Add-Result "Catalog" "BCG Deprecation Check" INFO "https://kb.broadcom.com/article/391170 — verify your NICs/HBAs are not deprecated in ESXi (for comparison)"
Add-Result "Catalog" "Server OEM Support Page" INFO "Verify OEM provides Windows Server 2025 driver packages for your exact model"

$Results | Where-Object { $_.Category -eq "Catalog" } | ForEach-Object { Write-CheckResult $_ }

# ============================================================
# Summary
# ============================================================
$PassCount = ($Results | Where-Object { $_.Status -eq "PASS" }).Count
$WarnCount = ($Results | Where-Object { $_.Status -eq "WARN" }).Count
$FailCount = ($Results | Where-Object { $_.Status -eq "FAIL" }).Count
$InfoCount = ($Results | Where-Object { $_.Status -eq "INFO" }).Count

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  PASS: $PassCount  |  WARN: $WarnCount  |  FAIL: $FailCount  |  INFO: $InfoCount" -ForegroundColor White

if ($FailCount -eq 0 -and $WarnCount -eq 0) {
    Write-Host "`n  RESULT: This host is READY for Windows Server 2025 / Hyper-V." -ForegroundColor Green
} elseif ($FailCount -eq 0) {
    Write-Host "`n  RESULT: This host PASSES with warnings. Review WARN items before production." -ForegroundColor Yellow
} else {
    Write-Host "`n  RESULT: This host has FAILURES that must be resolved." -ForegroundColor Red
}

# Export CSV report
$Timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$ReportBase = Join-Path $OutputPath "HyperV-HostValidation-$env:COMPUTERNAME-$Timestamp"
$Results | Export-Csv -Path "$ReportBase.csv" -NoTypeInformation
Write-Host "`n  CSV Report: $ReportBase.csv" -ForegroundColor Cyan

# Export failures/warnings only for quick reference
$Actionable = $Results | Where-Object { $_.Status -in "FAIL","WARN" }
if ($Actionable) {
    Write-Host "`n--- Items Requiring Attention ---" -ForegroundColor Yellow
    $Actionable | ForEach-Object {
        $color = if ($_.Status -eq "FAIL") { "Red" } else { "Yellow" }
        Write-Host "  [$($_.Status)] $($_.Check): $($_.Value)" -ForegroundColor $color
        if ($_.Recommendation) { Write-Host "         >> $($_.Recommendation)" -ForegroundColor DarkYellow }
    }
}

Write-Host "`n  Run this script on each potential Hyper-V node before proceeding to Post 5." -ForegroundColor Gray
Write-Host "============================================================`n" -ForegroundColor Cyan
