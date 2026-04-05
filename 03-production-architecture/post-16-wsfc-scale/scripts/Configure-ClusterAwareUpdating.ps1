[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ClusterName,
    [string]$CauRoleName = 'Cluster-Aware Updating',
    [string]$UpdatingRunProfileName = 'Default Self-Updating Options'
)

Import-Module ClusterAwareUpdating -ErrorAction Stop

if ($PSCmdlet.ShouldProcess($ClusterName, 'Add or update CAU role')) {
    Add-CauClusterRole -ClusterName $ClusterName -CauPluginName Microsoft.WindowsUpdatePlugin -MaxFailedNodes 0 -RequireAllNodesOnline -Force -ErrorAction SilentlyContinue
    Get-CauRunProfile -ClusterName $ClusterName -Name $UpdatingRunProfileName -ErrorAction SilentlyContinue
}
