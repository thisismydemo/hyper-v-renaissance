[CmdletBinding()]
param(
    [string[]]$ClusterNodes
)

Import-Module Hyper-V -ErrorAction SilentlyContinue

$localHost = Get-VMHost -ErrorAction SilentlyContinue
$results = @()

if ($localHost) {
    $results += [pscustomobject]@{
        ComputerName = $env:COMPUTERNAME
        MigrationEnabled = $localHost.VirtualMachineMigrationEnabled
        AuthenticationType = $localHost.VirtualMachineMigrationAuthenticationType
        MaxMigrations = $localHost.MaximumVirtualMachineMigrations
    }
}

if ($ClusterNodes) {
    foreach ($node in $ClusterNodes) {
        $results += Invoke-Command -ComputerName $node -ScriptBlock {
            $vmHost = Get-VMHost
            [pscustomobject]@{
                ComputerName = $env:COMPUTERNAME
                MigrationEnabled = $vmHost.VirtualMachineMigrationEnabled
                AuthenticationType = $vmHost.VirtualMachineMigrationAuthenticationType
                MaxMigrations = $vmHost.MaximumVirtualMachineMigrations
            }
        }
    }
}

$results
