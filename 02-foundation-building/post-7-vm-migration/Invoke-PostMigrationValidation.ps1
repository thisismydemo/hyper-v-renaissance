#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Validates a migrated VM on the Hyper-V host post-conversion.

.DESCRIPTION
    Runs a comprehensive post-migration check on a converted VM including:
    state, integration services, network adapters, disk configuration,
    checkpoints, firmware generation, and VMware tools presence.

    Series:     The Hyper-V Renaissance
    Post:       7 - Migrating VMs from VMware to Hyper-V
    Repository: https://github.com/thisismydemo/hyper-v-renaissance

.PARAMETER VMName
    Name of the VM to validate. Accepts pipeline input.

.PARAMETER All
    Validate all VMs on this Hyper-V host.

.EXAMPLE
    .\Invoke-PostMigrationValidation.ps1 -VMName "Migrated-VM-01"
    .\Invoke-PostMigrationValidation.ps1 -All
    Get-VM | .\Invoke-PostMigrationValidation.ps1
#>

[CmdletBinding(DefaultParameterSetName="Named")]
param(
    [Parameter(ParameterSetName="Named", Mandatory, ValueFromPipelineByPropertyName)]
    [string]$VMName,

    [Parameter(ParameterSetName="All")]
    [switch]$All
)

begin {
    $AllResults = [System.Collections.Generic.List[PSObject]]::new()

    function Test-VM {
        param([string]$Name)

        $results = [System.Collections.Generic.List[PSObject]]::new()
        function Add-Check {
            param([string]$Check,[ValidateSet("PASS","WARN","FAIL","INFO")][string]$Status,[string]$Value,[string]$Rec="")
            $results.Add([PSCustomObject]@{ VM=$Name; Check=$Check; Status=$Status; Value=$Value; Recommendation=$Rec })
        }

        Write-Host "`n  --- $Name ---" -ForegroundColor White

        $VM = Get-VM -Name $Name -ErrorAction SilentlyContinue
        if (-not $VM) {
            Add-Check "VM Exists" FAIL "Not found on this host"
            return $results
        }

        # 1. Running state
        $stateOk = $VM.State -eq "Running"
        Add-Check "VM State" $(if ($stateOk) {"PASS"} else {"WARN"}) $VM.State `
            $(if (-not $stateOk) {"VM is not running. Start after validation if expected."})

        # 2. Integration Services
        $IS = Get-VMIntegrationService -VMName $Name
        $isFail = $IS | Where-Object { $_.Enabled -and $_.PrimaryStatusDescription -ne "OK" }
        foreach ($svc in $IS) {
            if (-not $svc.Enabled) { continue }
            $st = if ($svc.PrimaryStatusDescription -eq "OK") { "PASS" } else { "WARN" }
            Add-Check "IntSvc: $($svc.Name)" $st $svc.PrimaryStatusDescription
        }

        # 3. Check for VMware Tools (should be gone)
        if ($VM.State -eq "Running") {
            $vmwareToolsRunning = $IS | Where-Object { $_.Name -like "*VMware*" }
            if ($vmwareToolsRunning) {
                Add-Check "VMware Tools" FAIL "VMware integration component detected" `
                    "Uninstall VMware Tools from inside the guest OS."
            } else {
                Add-Check "VMware Tools" PASS "Not detected"
            }
        }

        # 4. Network adapters
        $NICs = Get-VMNetworkAdapter -VMName $Name
        if ($NICs.Count -eq 0) {
            Add-Check "Network Adapters" FAIL "No network adapters found" "Add a network adapter and connect to a virtual switch."
        }
        foreach ($NIC in $NICs) {
            $nicOk = $NIC.Status -eq "Ok"
            Add-Check "NIC: $($NIC.Name)" $(if ($nicOk) {"PASS"} else {"WARN"}) `
                "Switch=$($NIC.SwitchName) Status=$($NIC.Status)"
        }

        # 5. Disk configuration
        $Disks = Get-VMHardDiskDrive -VMName $Name
        if ($Disks.Count -eq 0) {
            Add-Check "Disks" FAIL "No virtual disks found" "Attach the converted VHDX."
        }
        foreach ($Disk in $Disks) {
            if (-not (Test-Path $Disk.Path)) {
                Add-Check "Disk File" FAIL $Disk.Path "VHD/VHDX file is missing at this path."
                continue
            }
            $VHD = Get-VHD -Path $Disk.Path -ErrorAction SilentlyContinue
            if ($VHD) {
                Add-Check "Disk: $(Split-Path $Disk.Path -Leaf)" PASS `
                    "$([math]::Round($VHD.Size/1GB,2))GB | Used: $([math]::Round($VHD.FileSize/1GB,2))GB | $($VHD.VhdFormat)"
            }
        }

        # 6. Checkpoints (should be none post-migration)
        $Checkpoints = Get-VMSnapshot -VMName $Name -ErrorAction SilentlyContinue
        if ($Checkpoints.Count -gt 0) {
            Add-Check "Checkpoints" WARN "$($Checkpoints.Count) checkpoint(s) found" `
                "Remove all checkpoints after validating the migrated VM is working correctly."
        } else {
            Add-Check "Checkpoints" PASS "None (clean)"
        }

        # 7. Generation and firmware
        Add-Check "VM Generation" INFO "Gen $($VM.Generation)"
        if ($VM.Generation -eq 2) {
            $fw = Get-VMFirmware -VMName $Name -ErrorAction SilentlyContinue
            if ($fw) {
                Add-Check "Secure Boot" INFO "$($fw.SecureBoot)"
            }
        }

        # 8. Dynamic Memory
        $mem = Get-VMMemory -VMName $Name
        Add-Check "Dynamic Memory" INFO "Enabled=$($mem.DynamicMemoryEnabled) Min=$([math]::Round($mem.Minimum/1MB))MB Startup=$([math]::Round($mem.Startup/1MB))MB Max=$([math]::Round($mem.Maximum/1MB))MB"

        # Print results
        foreach ($r in $results) {
            $color = switch ($r.Status) { "PASS"{"Green"} "WARN"{"Yellow"} "FAIL"{"Red"} "INFO"{"Cyan"} }
            Write-Host ("    [{0}] {1,-40} {2}" -f $r.Status, $r.Check, $r.Value) -ForegroundColor $color
            if ($r.Recommendation) { Write-Host ("           >> {0}" -f $r.Recommendation) -ForegroundColor DarkYellow }
        }

        return $results
    }

    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "  Hyper-V Renaissance - Post-Migration VM Validation" -ForegroundColor Cyan
    Write-Host "  Post 7: Migrating VMs from VMware to Hyper-V" -ForegroundColor Cyan
    Write-Host "============================================================`n" -ForegroundColor Cyan
}

process {
    $name = if ($PSCmdlet.ParameterSetName -eq "Named") { $VMName } else { $null }
    if ($name) {
        $vmResults = Test-VM -Name $name
        $AllResults.AddRange($vmResults)
    }
}

end {
    if ($All) {
        $allVMs = Get-VM
        Write-Host "Validating all $($allVMs.Count) VMs on this host..." -ForegroundColor Yellow
        foreach ($vm in $allVMs) {
            $vmResults = Test-VM -Name $vm.Name
            $AllResults.AddRange($vmResults)
        }
    }

    # Summary
    $passCount = ($AllResults | Where-Object Status -eq "PASS").Count
    $warnCount = ($AllResults | Where-Object Status -eq "WARN").Count
    $failCount = ($AllResults | Where-Object Status -eq "FAIL").Count
    $vmCount   = ($AllResults | Select-Object VM -Unique).Count

    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "  POST-MIGRATION VALIDATION SUMMARY" -ForegroundColor Cyan
    Write-Host "  VMs validated: $vmCount | PASS: $passCount | WARN: $warnCount | FAIL: $failCount" -ForegroundColor White

    if ($failCount -gt 0) {
        Write-Host "`n  VMs with failures:" -ForegroundColor Red
        $AllResults | Where-Object Status -eq "FAIL" |
            Select-Object VM, Check, Value | Format-Table -AutoSize
    }

    # Export
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $AllResults | Export-Csv -Path "$PSScriptRoot\PostMigrationValidation-$timestamp.csv" -NoTypeInformation
    Write-Host "  Report: $PSScriptRoot\PostMigrationValidation-$timestamp.csv" -ForegroundColor Cyan
    Write-Host "============================================================`n" -ForegroundColor Cyan
}
