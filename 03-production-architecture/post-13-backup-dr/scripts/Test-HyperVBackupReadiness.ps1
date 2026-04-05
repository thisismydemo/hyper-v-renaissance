[CmdletBinding()]
param(
    [string]$OutputPath = ".\backup-readiness.json"
)

$vssWriters = vssadmin list writers 2>$null
$vmIntegration = @()

try {
    Import-Module Hyper-V -ErrorAction Stop
    $vmIntegration = Get-VM | ForEach-Object {
        Get-VMIntegrationService -VMName $_.Name |
            Where-Object Name -in 'Backup (volume checkpoint)', 'Heartbeat', 'Time Synchronization' |
            Select-Object VMName, Name, Enabled, PrimaryStatusDescription
    }
} catch {
}

$services = Get-Service -Name vmms, vss -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType

$result = [pscustomobject]@{
    CollectedAt = Get-Date
    Services = $services
    IntegrationServices = $vmIntegration
    VssWriterOutput = $vssWriters
}

$result | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
$result
