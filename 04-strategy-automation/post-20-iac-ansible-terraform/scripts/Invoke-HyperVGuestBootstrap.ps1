[CmdletBinding()]
param(
    [string]$ComputerName,
    [string]$TimeZoneId = "UTC",
    [string]$FeatureNamesCsv,
    [string]$DirectoryPathsCsv,
    [switch]$RestartIfNeeded
)

$ErrorActionPreference = "Stop"

$featureNames = @()
if ($FeatureNamesCsv) {
    $featureNames = $FeatureNamesCsv.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries).Trim()
}

$directoryPaths = @()
if ($DirectoryPathsCsv) {
    $directoryPaths = $DirectoryPathsCsv.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries).Trim()
}

$changed = $false
$rebootRequired = $false

if ($ComputerName -and $env:COMPUTERNAME -ne $ComputerName) {
    Rename-Computer -NewName $ComputerName -Force
    $changed = $true
    $rebootRequired = $true
}

if ($TimeZoneId) {
    $currentTimeZone = (Get-TimeZone).Id
    if ($currentTimeZone -ne $TimeZoneId) {
        Set-TimeZone -Id $TimeZoneId
        $changed = $true
    }
}

foreach ($path in $directoryPaths) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        $changed = $true
    }
}

if ($featureNames.Count -gt 0) {
    $featureInstall = Install-WindowsFeature -Name $featureNames -IncludeManagementTools -Restart:$false
    if ($featureInstall.Success -and $featureInstall.FeatureResult.Count -gt 0) {
        if ($featureInstall.FeatureResult.Where({ $_.Success }).Count -gt 0) {
            $changed = $true
        }
        if ([string]$featureInstall.RestartNeeded -eq "Yes") {
            $rebootRequired = $true
        }
    }
}

$result = [pscustomobject]@{
    Changed = $changed
    RebootRequired = $rebootRequired
    ComputerName = if ($ComputerName) { $ComputerName } else { $env:COMPUTERNAME }
    Features = $featureNames
    Directories = $directoryPaths
}

$result

if ($RestartIfNeeded -and $rebootRequired) {
    Restart-Computer -Force
}
