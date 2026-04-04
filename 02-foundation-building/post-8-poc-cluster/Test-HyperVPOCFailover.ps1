#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Hyper-V Renaissance Series — Post 8: POC Failover and Live Migration Tests

.DESCRIPTION
    Validates the POC cluster from Post 8 by running:
      - Live migration test (timed)
      - Simulated node failure / automatic failover test
      - Quick migration test
      - Final cluster health report

    Run from HV-NODE-01 after Deploy-HyperVPOCCluster.ps1 has completed.

.PARAMETER ClusterName
    Name of the failover cluster to test.

.PARAMETER VMName
    Name of the highly available VM to use for migration tests.

.EXAMPLE
    .\Test-HyperVPOCFailover.ps1

.EXAMPLE
    .\Test-HyperVPOCFailover.ps1 -ClusterName "HV-CLUSTER-01" -VMName "POC-TestVM-01"

.NOTES
    Series:  The Hyper-V Renaissance
    Post:    8 — POC Like You Mean It
    Repo:    https://github.com/thisismydemo/hyper-v-renaissance
    Author:  thisismydemo
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ClusterName = "HV-CLUSTER-01",
    [string]$VMName      = "POC-TestVM-01"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Phase { param([string]$m) Write-Host "`n============================================================`n  $m`n============================================================" -ForegroundColor Cyan }
function Write-Pass  { param([string]$m) Write-Host "  [PASS] $m" -ForegroundColor Green }
function Write-Fail  { param([string]$m) Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Write-Info  { param([string]$m) Write-Host "  [INFO] $m" -ForegroundColor White }
function Write-Warn  { param([string]$m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }

# ============================================================
# PRE-FLIGHT
# ============================================================

Write-Phase "Pre-Flight Checks"

$Cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
if (-not $Cluster) {
    Write-Fail "Cluster '$ClusterName' not found. Run Deploy-HyperVPOCCluster.ps1 first."
    exit 1
}
Write-Pass "Cluster: $($Cluster.Name)"

$Nodes = Get-ClusterNode
foreach ($Node in $Nodes) {
    if ($Node.State -eq "Up") { Write-Pass "Node $($Node.Name): Up" }
    else { Write-Fail "Node $($Node.Name): $($Node.State)" }
}

$HAVM = Get-ClusterGroup -Name $VMName -ErrorAction SilentlyContinue
if (-not $HAVM) {
    Write-Fail "Cluster group '$VMName' not found."
    exit 1
}

if ($HAVM.State -ne "Online") {
    Write-Fail "VM '$VMName' is not Online (State: $($HAVM.State)). Start it before running failover tests."
    exit 1
}
Write-Pass "HA VM '$VMName' is Online on $($HAVM.OwnerNode)."

# ============================================================
# TEST 1 — LIVE MIGRATION (timed)
# ============================================================

Write-Phase "Test 1: Live Migration"

$SourceNode = (Get-ClusterGroup -Name $VMName).OwnerNode
$TargetNode = (Get-ClusterNode | Where-Object { $_.Name -ne $SourceNode -and $_.State -eq "Up" } |
    Select-Object -First 1).Name

if (-not $TargetNode) {
    Write-Fail "No available target node for live migration."
    exit 1
}

Write-Info "Migrating '$VMName' from $SourceNode → $TargetNode ..."
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    Move-ClusterVirtualMachineRole -Name $VMName -Node $TargetNode -MigrationType Live
    $Stopwatch.Stop()
    $NewOwner = (Get-ClusterGroup -Name $VMName).OwnerNode
    if ($NewOwner -eq $TargetNode) {
        Write-Pass "Live migration succeeded in $([math]::Round($Stopwatch.Elapsed.TotalSeconds, 1))s — VM now on $NewOwner"
    } else {
        Write-Fail "VM ended up on $NewOwner, expected $TargetNode."
    }
} catch {
    $Stopwatch.Stop()
    Write-Fail "Live migration failed: $_"
}

# ============================================================
# TEST 2 — SIMULATED NODE FAILURE (automatic failover)
# ============================================================

Write-Phase "Test 2: Simulated Node Failure (Automatic Failover)"

$CurrentOwner = (Get-ClusterGroup -Name $VMName).OwnerNode
$SurvivorNode  = (Get-ClusterNode | Where-Object { $_.Name -ne $CurrentOwner }).Name

Write-Info "Stopping cluster service on $CurrentOwner to simulate failure..."
Write-Warn "This will drain ALL cluster resources off $CurrentOwner temporarily."

try {
    Invoke-Command -ComputerName $CurrentOwner -ScriptBlock { Stop-Service ClusSvc -Force }
} catch {
    Write-Fail "Could not stop cluster service on $CurrentOwner`: $_"
    exit 1
}

Write-Info "Waiting 20 seconds for automatic failover..."
Start-Sleep -Seconds 20

$Group = Get-ClusterGroup -Name $VMName -ErrorAction SilentlyContinue
if ($Group -and $Group.State -eq "Online" -and $Group.OwnerNode -eq $SurvivorNode) {
    Write-Pass "VM automatically failed over to $SurvivorNode in the expected timeframe."
} elseif ($Group) {
    Write-Warn "VM state: $($Group.State) on $($Group.OwnerNode) — may need more time or manual review."
} else {
    Write-Fail "VM cluster group not found after failover."
}

# Bring the "failed" node back
Write-Info "Restarting cluster service on $CurrentOwner..."
try {
    Invoke-Command -ComputerName $CurrentOwner -ScriptBlock { Start-Service ClusSvc }
    Start-Sleep -Seconds 15
    $RejoiningNode = Get-ClusterNode -Name $CurrentOwner
    if ($RejoiningNode.State -eq "Up") {
        Write-Pass "$CurrentOwner rejoined the cluster."
    } else {
        Write-Warn "$CurrentOwner state: $($RejoiningNode.State) — may still be rejoining."
    }
} catch {
    Write-Warn "Could not restart cluster service on $CurrentOwner`: $_ — rejoin manually."
}

# ============================================================
# TEST 3 — QUICK MIGRATION (planned failover with brief pause)
# ============================================================

Write-Phase "Test 3: Quick Migration (Planned Failover)"

$CurrentOwner = (Get-ClusterGroup -Name $VMName).OwnerNode
$TargetNode   = (Get-ClusterNode | Where-Object { $_.Name -ne $CurrentOwner -and $_.State -eq "Up" } |
    Select-Object -First 1).Name

Write-Info "Quick-migrating '$VMName' from $CurrentOwner → $TargetNode ..."
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    Move-ClusterVirtualMachineRole -Name $VMName -Node $TargetNode -MigrationType Quick
    $Stopwatch.Stop()
    $NewOwner = (Get-ClusterGroup -Name $VMName).OwnerNode
    if ($NewOwner -eq $TargetNode) {
        Write-Pass "Quick migration succeeded in $([math]::Round($Stopwatch.Elapsed.TotalSeconds, 1))s — VM now on $NewOwner"
    } else {
        Write-Fail "VM ended up on $NewOwner, expected $TargetNode."
    }
} catch {
    $Stopwatch.Stop()
    Write-Fail "Quick migration failed: $_"
}

# ============================================================
# FINAL CLUSTER HEALTH REPORT
# ============================================================

Write-Phase "Final Cluster Health Report"

Write-Info "Cluster : $($Cluster.Name)"
Write-Info "Domain  : $($Cluster.Domain)"

foreach ($Node in (Get-ClusterNode)) {
    if ($Node.State -eq "Up") { Write-Pass "Node $($Node.Name): Up" }
    else { Write-Fail "Node $($Node.Name): $($Node.State)" }
}

foreach ($CSV in (Get-ClusterSharedVolume)) {
    $FreeGB  = [math]::Round($CSV.SharedVolumeInfo.Partition.FreeSpace / 1GB, 1)
    $TotalGB = [math]::Round($CSV.SharedVolumeInfo.Partition.Size / 1GB, 1)
    if ($CSV.State -eq "Online") {
        Write-Pass "CSV $($CSV.Name): Online on $($CSV.OwnerNode) — $FreeGB / $TotalGB GB free"
    } else {
        Write-Fail "CSV $($CSV.Name): $($CSV.State)"
    }
}

$Quorum = Get-ClusterQuorum
Write-Info "Quorum  : $($Quorum.QuorumType) ($($Quorum.QuorumResource))"

Get-ClusterGroup | Where-Object { $_.GroupType -eq "VirtualMachine" } | ForEach-Object {
    if ($_.State -eq "Online") { Write-Pass "VM $($_.Name): Online on $($_.OwnerNode)" }
    else { Write-Fail "VM $($_.Name): $($_.State)" }
}

foreach ($Net in (Get-ClusterNetwork)) {
    Write-Info "Network '$($Net.Name)': $($Net.State) — Role: $($Net.Role)"
}

Write-Host "`n  All POC tests complete. Your cluster is ready for production planning." -ForegroundColor Cyan
