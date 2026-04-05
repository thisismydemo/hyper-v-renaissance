[CmdletBinding()]
param()

$computerSystem = Get-CimInstance Win32_ComputerSystem
$tpm = Get-Tpm -ErrorAction SilentlyContinue
$deviceGuard = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue

[pscustomobject]@{
    ComputerName = $env:COMPUTERNAME
    DomainJoined = [bool]$computerSystem.PartOfDomain
    Manufacturer = $computerSystem.Manufacturer
    Model = $computerSystem.Model
    SecureBoot = (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue)
    TpmPresent = $tpm.TpmPresent
    TpmReady = $tpm.TpmReady
    VbsStatus = $deviceGuard.VirtualizationBasedSecurityStatus
    CredentialGuardRunning = ($deviceGuard.SecurityServicesRunning -contains 1)
    HvciRunning = ($deviceGuard.SecurityServicesRunning -contains 2)
}
