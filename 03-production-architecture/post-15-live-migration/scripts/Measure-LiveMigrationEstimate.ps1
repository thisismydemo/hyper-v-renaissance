[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [double]$MemoryGB,
    [Parameter(Mandatory)]
    [double]$EffectiveBandwidthGbps,
    [double]$CompressionFactor = 1.0
)

$effectiveGb = ($MemoryGB * 8) * $CompressionFactor
$seconds = [math]::Round($effectiveGb / $EffectiveBandwidthGbps, 2)

[pscustomobject]@{
    MemoryGB = $MemoryGB
    EffectiveBandwidthGbps = $EffectiveBandwidthGbps
    CompressionFactor = $CompressionFactor
    EstimatedTransferSeconds = $seconds
    EstimatedTransferMinutes = [math]::Round($seconds / 60, 2)
}
