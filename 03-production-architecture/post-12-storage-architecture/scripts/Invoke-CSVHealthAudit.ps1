[CmdletBinding()]
param(
    [string]$OutputPath = ".\csv-audit.json"
)

Import-Module FailoverClusters -ErrorAction Stop

$csvState = Get-ClusterSharedVolumeState | Select-Object Name, Node, StateInfo, FileSystemRedirectedIOReason
$csvInfo = Get-ClusterSharedVolume | ForEach-Object {
    [pscustomobject]@{
        Name = $_.Name
        OwnerNode = $_.OwnerNode.Name
        FriendlyVolumeName = $_.SharedVolumeInfo.FriendlyVolumeName
        FaultState = $_.SharedVolumeInfo.FaultState
    }
}

$clusterDisks = Get-ClusterResource | Where-Object ResourceType -eq 'Physical Disk' |
    Select-Object Name, OwnerGroup, OwnerNode, State

$result = [pscustomobject]@{
    CollectedAt = Get-Date
    CSVState = $csvState
    CSVInfo = $csvInfo
    ClusterDisks = $clusterDisks
}

$result | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
$result
