[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]]$ComputerName = @($env:COMPUTERNAME),
    [switch]$EnableCredSSP
)

$scriptBlock = {
    Enable-PSRemoting -Force
    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false
    Enable-NetFirewallRule -DisplayGroup 'Windows Remote Management'
    if ($using:EnableCredSSP) {
        Enable-WSManCredSSP -Role Server -Force
    }
}

foreach ($computer in $ComputerName) {
    if ($computer -in @('.', 'localhost', $env:COMPUTERNAME)) {
        if ($PSCmdlet.ShouldProcess($computer, 'Configure remoting')) {
            & $scriptBlock
        }
    } else {
        if ($PSCmdlet.ShouldProcess($computer, 'Configure remoting')) {
            Invoke-Command -ComputerName $computer -ScriptBlock $scriptBlock
        }
    }
}
