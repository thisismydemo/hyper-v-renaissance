#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Comprehensive pre-cluster validation for a Hyper-V node.

.DESCRIPTION
    Validates networking, storage, roles/features, Hyper-V configuration, and runs
    Test-Cluster when two or more nodes are available. Produces a pass/warn/fail
    report that mirrors the build checklist from Post 5.

    Series:     The Hyper-V Renaissance
    Post:       5 - Build and Validate a Cluster-Ready Host
    Repository: https://github.com/thisismydemo/hyper-v-renaissance

.PARAMETER ClusterNodes
    Array of node hostnames to include in Test-Cluster. If only one node name is
    provided (this host), Test-Cluster is skipped and single-node checks are run.

.EXAMPLE
    .\Validate-HyperVNode.ps1
    .\Validate-HyperVNode.ps1 -ClusterNodes "HV-NODE-01","HV-NODE-02"
#>

[CmdletBinding()]
param(
    [string[]]$ClusterNodes = @($env:COMPUTERNAME)
)

$Results = [System.Collections.Generic.List[PSObject]]::new()

function Add-Result {
    param([string]$Category,[string]$Check,[ValidateSet("PASS","WARN","FAIL","INFO")][string]$Status,[string]$Value,[string]$Recommendation="")
    $Results.Add([PSCustomObject]@{ Category=$Category; Check=$Check; Status=$Status; Value=$Value; Recommendation=$Recommendation })
}

function Write-Result { param($R)
    $color = switch ($R.Status) { "PASS"{"Green"} "WARN"{"Yellow"} "FAIL"{"Red"} "INFO"{"Cyan"} }
    Write-Host ("  [{0}] {1,-42} {2}" -f $R.Status, $R.Check, $R.Value) -ForegroundColor $color
    if ($R.Recommendation) { Write-Host ("         >> {0}" -f $R.Recommendation) -ForegroundColor DarkYellow }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Hyper-V Renaissance - Node Validation" -ForegroundColor Cyan
Write-Host "  Post 5: Build and Validate a Cluster-Ready Host" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# ============================================================
# Network Validation
# ============================================================
Write-Host "--- Network Validation ---" -ForegroundColor White

$vNICs = Get-NetAdapter -Name "vEthernet*"
foreach ($vNIC in $vNICs) {
    $status = if ($vNIC.Status -eq "Up") { "PASS" } else { "FAIL" }
    Add-Result "Network" "vNIC: $($vNIC.Name)" $status "$($vNIC.Status) @ $($vNIC.LinkSpeed)"
}

# VLAN tagging
$vlans = Get-VMNetworkAdapterVlan -ManagementOS
foreach ($vlan in $vlans) {
    Add-Result "Network" "VLAN: $($vlan.ParentAdapter.Name)" INFO "VLAN ID $($vlan.AccessVlanId)"
}

# SET team health
$team = Get-VMSwitchTeam -ErrorAction SilentlyContinue
if ($team) {
    foreach ($member in $team.NetAdapterInterfaceDescription) {
        $adapter = Get-NetAdapter -InterfaceDescription $member -ErrorAction SilentlyContinue
        if ($adapter) {
            $status = if ($adapter.Status -eq "Up") { "PASS" } else { "FAIL" }
            Add-Result "Network" "SET Member: $($adapter.Name)" $status "$($adapter.Status) @ $($adapter.LinkSpeed)"
        }
    }
} else {
    Add-Result "Network" "SET Switch Team" WARN "No SET team found" "Run Deploy-HyperVNode.ps1 Phase 3 to configure SET switch."
}

# Connectivity tests
$pingTargets = @(
    @{Name="Management Gateway"; IP="10.10.10.1"},
    @{Name="DNS Server";         IP="10.10.10.5"}
)
foreach ($t in $pingTargets) {
    $ping = Test-Connection -ComputerName $t.IP -Count 1 -Quiet -ErrorAction SilentlyContinue
    $status = if ($ping) { "PASS" } else { "WARN" }
    Add-Result "Network" "Ping $($t.Name)" $status $t.IP
}

# DNS
$dns = Resolve-DnsName -Name $env:USERDNSDOMAIN -ErrorAction SilentlyContinue
$status = if ($dns) { "PASS" } else { "FAIL" }
Add-Result "Network" "DNS Resolution" $status $(if ($dns) { "Resolved $env:USERDNSDOMAIN" } else { "FAILED: $env:USERDNSDOMAIN" })

$Results | Where-Object Category -eq "Network" | ForEach-Object { Write-Result $_ }

# ============================================================
# Storage Validation
# ============================================================
Write-Host "`n--- Storage Validation ---" -ForegroundColor White

$sessions = Get-IscsiSession -ErrorAction SilentlyContinue
$status = if ($sessions) { "PASS" } else { "WARN" }
Add-Result "Storage" "iSCSI Sessions" $status "$(($sessions | Where-Object IsConnected).Count) connected / $($sessions.Count) total"

foreach ($s in $sessions) {
    $color = if ($s.IsConnected) { "PASS" } else { "FAIL" }
    Add-Result "Storage" "  Session: $($s.TargetNodeAddress.Substring(0,[Math]::Min(40,$s.TargetNodeAddress.Length)))" $color "Connected=$($s.IsConnected) Persistent=$($s.IsPersistent)"
}

$mpioPolicy = Get-MSDSMGlobalDefaultLoadBalancePolicy -ErrorAction SilentlyContinue
Add-Result "Storage" "MPIO Default LB Policy" INFO $(if ($mpioPolicy) { $mpioPolicy } else { "Not set" })

$sanDisks = Get-Disk | Where-Object { $_.BusType -eq "iSCSI" -or ($_.Path -like "*iSCSI*") }
$status = if ($sanDisks.Count -gt 0) { "PASS" } else { "WARN" }
Add-Result "Storage" "SAN Disks Visible" $status "$($sanDisks.Count) iSCSI disk(s) visible"
foreach ($d in $sanDisks) {
    Add-Result "Storage" "  Disk $($d.Number)" INFO "$([math]::Round($d.Size/1GB,2)) GB - $($d.PartitionStyle) - $($d.OperationalStatus)"
}

$Results | Where-Object Category -eq "Storage" | ForEach-Object { Write-Result $_ }

# ============================================================
# Roles and Features Validation
# ============================================================
Write-Host "`n--- Roles and Features ---" -ForegroundColor White

$requiredFeatures = @("Hyper-V","Failover-Clustering","Multipath-IO","RSAT-Clustering-PowerShell","Hyper-V-PowerShell")
foreach ($f in $requiredFeatures) {
    $feat = Get-WindowsFeature -Name $f -ErrorAction SilentlyContinue
    $status = if ($feat -and $feat.InstallState -eq "Installed") { "PASS" } else { "FAIL" }
    Add-Result "Features" "Feature: $f" $status $($feat.InstallState)
}

$hvPresent = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
Add-Result "Features" "Hypervisor Running" $(if ($hvPresent) {"PASS"} else {"FAIL"}) $hvPresent

$Results | Where-Object Category -eq "Features" | ForEach-Object { Write-Result $_ }

# ============================================================
# Hyper-V Host Configuration Validation
# ============================================================
Write-Host "`n--- Hyper-V Host Configuration ---" -ForegroundColor White

$vmHost = Get-VMHost
Add-Result "HyperV" "VM Path"             INFO $vmHost.VirtualMachinePath
Add-Result "HyperV" "VHD Path"            INFO $vmHost.VirtualHardDiskPath
Add-Result "HyperV" "Live Migration"      $(if ($vmHost.VirtualMachineMigrationEnabled) {"PASS"} else {"WARN"}) $vmHost.VirtualMachineMigrationEnabled
Add-Result "HyperV" "Migration Auth"      INFO $vmHost.VirtualMachineMigrationAuthenticationType
Add-Result "HyperV" "Max Migrations"      INFO $vmHost.MaximumVirtualMachineMigrations
Add-Result "HyperV" "NUMA Spanning"       INFO $vmHost.NumaSpanningEnabled

$Results | Where-Object Category -eq "HyperV" | ForEach-Object { Write-Result $_ }

# ============================================================
# Test-Cluster (multi-node only)
# ============================================================
if ($ClusterNodes.Count -ge 2) {
    Write-Host "`n--- Cluster Validation (Test-Cluster) ---" -ForegroundColor White
    Write-Host "  Nodes: $($ClusterNodes -join ', ')" -ForegroundColor Yellow
    Write-Host "  This takes 10-30 minutes..." -ForegroundColor Yellow

    Test-Cluster -Node $ClusterNodes -Verbose

    $report = Get-ChildItem "$env:SystemRoot\Cluster\Reports" -Filter "Validation*" |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($report) {
        Add-Result "Cluster" "Test-Cluster Report" PASS $report.FullName
        Write-Host "`n  Report saved to: $($report.FullName)" -ForegroundColor Green
    }
} else {
    Add-Result "Cluster" "Test-Cluster" INFO "Skipped — provide 2+ node names via -ClusterNodes parameter"
}

$Results | Where-Object Category -eq "Cluster" | ForEach-Object { Write-Result $_ }

# ============================================================
# Summary
# ============================================================
$passCount = ($Results | Where-Object Status -eq "PASS").Count
$warnCount = ($Results | Where-Object Status -eq "WARN").Count
$failCount = ($Results | Where-Object Status -eq "FAIL").Count

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "  PASS: $passCount  WARN: $warnCount  FAIL: $failCount" -ForegroundColor White

if ($failCount -eq 0) {
    Write-Host "  RESULT: Node is READY for cluster membership." -ForegroundColor Green
} else {
    Write-Host "  RESULT: $failCount failure(s) must be resolved before joining cluster." -ForegroundColor Red
    $Results | Where-Object Status -eq "FAIL" | ForEach-Object {
        Write-Host "    [FAIL] $($_.Check): $($_.Value)" -ForegroundColor Red
        if ($_.Recommendation) { Write-Host "           >> $($_.Recommendation)" -ForegroundColor DarkYellow }
    }
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Results | Export-Csv -Path "$PSScriptRoot\NodeValidation-$env:COMPUTERNAME-$timestamp.csv" -NoTypeInformation
Write-Host "`n  CSV saved to: $PSScriptRoot\NodeValidation-$env:COMPUTERNAME-$timestamp.csv" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan
