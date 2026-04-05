[CmdletBinding()]
param(
    [string[]]$ComputerName = @($env:COMPUTERNAME),
    [string]$OutputPath = ".\output"
)

$counterPaths = @(
    '\Hyper-V Hypervisor Logical Processor(_Total)\% Total Run Time',
    '\Hyper-V Hypervisor Logical Processor(_Total)\% Guest Run Time',
    '\Hyper-V Dynamic Memory Balancer\Average Pressure',
    '\LogicalDisk(_Total)\Avg. Disk sec/Read',
    '\LogicalDisk(_Total)\Avg. Disk sec/Write',
    '\Network Interface(*)\Bytes Total/sec'
)

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$scriptBlock = {
    param($CounterPaths)

    $clusterNodes = @()
    $csvs = @()
    $events = @()
    $vms = @()
    $counters = @()

    try {
        Import-Module FailoverClusters -ErrorAction Stop
        $clusterNodes = Get-ClusterNode | Select-Object Name, State, NodeWeight, DynamicWeight
        $csvs = Get-ClusterSharedVolumeState | Select-Object Name, Node, StateInfo, FileSystemRedirectedIOReason
    } catch {
    }

    try {
        Import-Module Hyper-V -ErrorAction Stop
        $vms = Get-VM | Select-Object Name, State, Status, CPUUsage, MemoryAssigned, Uptime
    } catch {
    }

    try {
        $counters = Get-Counter -Counter $CounterPaths -SampleInterval 1 -MaxSamples 1 |
            Select-Object -ExpandProperty CounterSamples |
            Select-Object Path, InstanceName, CookedValue, Timestamp
    } catch {
    }

    foreach ($logName in 'Microsoft-Windows-Hyper-V-VMMS/Admin', 'Microsoft-Windows-FailoverClustering/Operational') {
        try {
            $events += Get-WinEvent -LogName $logName -MaxEvents 25 |
                Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
        } catch {
        }
    }

    [pscustomobject]@{
        ComputerName = $env:COMPUTERNAME
        CollectedAt  = Get-Date
        ClusterNodes = $clusterNodes
        CSVs         = $csvs
        VMs          = $vms
        Counters     = $counters
        Events       = $events
    }
}

$results = foreach ($computer in $ComputerName) {
    if ($computer -in @('.', 'localhost', $env:COMPUTERNAME)) {
        & $scriptBlock $counterPaths
    } else {
        Invoke-Command -ComputerName $computer -ScriptBlock $scriptBlock -ArgumentList (, $counterPaths)
    }
}

foreach ($result in $results) {
    $safeName = $result.ComputerName -replace '[^A-Za-z0-9._-]', '_'
    $jsonPath = Join-Path $OutputPath "$safeName-baseline.json"
    $result | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
}

$summary = foreach ($result in $results) {
    $avgPressure = ($result.Counters | Where-Object Path -like '*Average Pressure*' | Select-Object -First 1).CookedValue
    [pscustomobject]@{
        ComputerName = $result.ComputerName
        CollectedAt  = $result.CollectedAt
        VMCount      = @($result.VMs).Count
        ClusterNodeCount = @($result.ClusterNodes).Count
        CSVCount     = @($result.CSVs).Count
        AveragePressure = $avgPressure
    }
}

$summary | Export-Csv -Path (Join-Path $OutputPath 'monitoring-summary.csv') -NoTypeInformation -Encoding UTF8
$summary
