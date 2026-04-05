[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Enforce,
    [string]$OutputPath = ".\security-baseline.json"
)

$deviceGuard = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
$secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
$tpm = Get-Tpm -ErrorAction SilentlyContinue
$bitlocker = Get-BitLockerVolume -ErrorAction SilentlyContinue | Select-Object MountPoint, VolumeStatus, ProtectionStatus
$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue | Select-Object AMRunningMode, AntivirusEnabled, RealTimeProtectionEnabled
$smb = Get-SmbServerConfiguration | Select-Object EncryptData, RejectUnencryptedAccess, EnableSMB1Protocol

$result = [pscustomobject]@{
    CollectedAt = Get-Date
    SecureBoot = $secureBoot
    TpmPresent = $tpm.TpmPresent
    TpmReady = $tpm.TpmReady
    VbsStatus = $deviceGuard.VirtualizationBasedSecurityStatus
    SecurityServicesRunning = $deviceGuard.SecurityServicesRunning
    BitLocker = $bitlocker
    Defender = $defender
    SmbServer = $smb
}

if ($Enforce) {
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Enable safe baseline settings')) {
        Set-SmbServerConfiguration -EncryptData $true -RejectUnencryptedAccess $true -Force | Out-Null
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    }
}

$result | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
$result
