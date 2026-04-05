[CmdletBinding()]
param(
    [string]$HostName,
    [string]$TimeZoneId = "UTC",
    [string]$SwitchName,
    [string]$NetAdapterNamesJson = "[]",
    [ValidateSet("Absolute", "Default", "None", "Weight")]
    [string]$MinimumBandwidthMode = "Weight",
    [switch]$ConfigureWinRmHttps,
    [string]$WinRmCertificateThumbprint
)

$ErrorActionPreference = "Stop"

$changed = $false
$rebootRequired = $false

$adapterNames = @()
if ($NetAdapterNamesJson) {
    $parsedAdapters = ConvertFrom-Json -InputObject $NetAdapterNamesJson
    if ($parsedAdapters) {
        $adapterNames = @($parsedAdapters)
    }
}

if ($HostName -and $env:COMPUTERNAME -ne $HostName) {
    Rename-Computer -NewName $HostName -Force
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

Enable-PSRemoting -Force | Out-Null

if ($ConfigureWinRmHttps) {
    $httpsListener = Get-ChildItem -Path WSMan:\localhost\Listener -ErrorAction SilentlyContinue |
        Where-Object { $_.Keys -contains "Transport=HTTPS" }

    if (-not $httpsListener) {
        $thumbprint = $WinRmCertificateThumbprint
        if (-not $thumbprint) {
            $cert = New-SelfSignedCertificate \
                -CertStoreLocation "Cert:\LocalMachine\My" \
                -DnsName $env:COMPUTERNAME \
                -NotAfter (Get-Date).AddYears(2) \
                -Provider "Microsoft Software Key Storage Provider" \
                -Subject "CN=$($env:COMPUTERNAME)"
            $thumbprint = $cert.Thumbprint
        }

        New-Item \
            -Path WSMan:\localhost\Listener \
            -Address * \
            -CertificateThumbprint $thumbprint \
            -Enabled $true \
            -Port 5986 \
            -Transport HTTPS \
            -Force | Out-Null

        if (-not (Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule \
                -Action Allow \
                -Description "Inbound rule for Windows Remote Management over HTTPS" \
                -Direction Inbound \
                -DisplayName "Windows Remote Management (HTTPS-In)" \
                -LocalPort 5986 \
                -Profile Any \
                -Protocol TCP | Out-Null
        }

        $changed = $true
    }
}

if ($SwitchName) {
    $existingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if (-not $existingSwitch) {
        if ($adapterNames.Count -gt 0) {
            New-VMSwitch \
                -Name $SwitchName \
                -NetAdapterName $adapterNames \
                -AllowManagementOS $true \
                -EnableEmbeddedTeaming ($adapterNames.Count -gt 1) \
                -MinimumBandwidthMode $MinimumBandwidthMode | Out-Null
        }
        else {
            New-VMSwitch \
                -Name $SwitchName \
                -SwitchType Internal \
                -MinimumBandwidthMode $MinimumBandwidthMode | Out-Null
        }

        $changed = $true
    }
}

[pscustomobject]@{
    Changed = $changed
    RebootRequired = $rebootRequired
    HostName = if ($HostName) { $HostName } else { $env:COMPUTERNAME }
    SwitchName = $SwitchName
    ConfigureWinRmHttps = [bool]$ConfigureWinRmHttps
}
