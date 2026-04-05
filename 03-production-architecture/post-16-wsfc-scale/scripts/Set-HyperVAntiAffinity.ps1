[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string[]]$RoleName,
    [Parameter(Mandatory)]
    [string]$ClassName
)

Import-Module FailoverClusters -ErrorAction Stop

foreach ($role in $RoleName) {
    if ($PSCmdlet.ShouldProcess($role, "Set anti-affinity class $ClassName")) {
        (Get-ClusterGroup -Name $role).AntiAffinityClassNames = $ClassName
    }
}
