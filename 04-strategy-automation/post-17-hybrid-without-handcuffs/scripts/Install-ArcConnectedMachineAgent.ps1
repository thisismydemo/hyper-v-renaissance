[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,
    [Parameter(Mandatory)]
    [string]$ResourceGroup,
    [Parameter(Mandatory)]
    [string]$TenantId,
    [Parameter(Mandatory)]
    [string]$Location,
    [string]$DownloadUri = 'https://aka.ms/AzureConnectedMachineAgent',
    [string]$MsiPath = "$env:TEMP\AzureConnectedMachineAgent.msi"
)

if (-not (Get-Command azcmagent -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Download and install Azure Connected Machine agent')) {
        Invoke-WebRequest -Uri $DownloadUri -OutFile $MsiPath
        Start-Process msiexec.exe -ArgumentList "/i `"$MsiPath`" /qn" -Wait
    }
}

$connectCommand = @(
    'azcmagent connect',
    "--subscription-id `"$SubscriptionId`"",
    "--resource-group `"$ResourceGroup`"",
    "--tenant-id `"$TenantId`"",
    "--location `"$Location`""
) -join ' '

Write-Host 'Run the following command after you authenticate with Azure and confirm policy/governance expectations:' -ForegroundColor Cyan
Write-Host $connectCommand -ForegroundColor Yellow
