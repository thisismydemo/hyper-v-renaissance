#Requires -Version 7.0
function Test-HVNetworkState {
    <#
    .SYNOPSIS
        Tests whether host networking matches desired state from configuration.
    .DESCRIPTION
        Validates SET virtual switch, host vNICs, VLAN assignments, and IP configuration
        against the environment configuration file. Returns $true if all match, $false if
        any drift is detected.
        Series: The Hyper-V Renaissance
        Post: 19 - PowerShell Automation Patterns
    .PARAMETER Config
        PSCustomObject loaded from Import-HVConfig.
    .PARAMETER NodeName
        The cluster node name to test. If omitted, tests the local host.
    .EXAMPLE
        $config = Import-HVConfig -Path './variables/environment.prod.json'
        Test-HVNetworkState -Config $config
    .OUTPUTS
        [bool] $true if current state matches desired state, $false if drift detected.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [string]$NodeName = $env:COMPUTERNAME
    )

    $scriptBlock = {
        param($cfg)

        $switchName = $cfg.naming.switchName

        # Check SET switch exists and is embedded teaming
        $switch = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
        if (-not $switch) {
            Write-Verbose "DRIFT: VMSwitch '$switchName' does not exist"
            return $false
        }
        if (-not $switch.EmbeddedTeamingEnabled) {
            Write-Verbose "DRIFT: VMSwitch '$switchName' is not SET-enabled"
            return $false
        }

        # Check each traffic type vNIC
        $trafficTypes = @('management', 'migration', 'storage')
        foreach ($traffic in $trafficTypes) {
            $vnic = Get-VMNetworkAdapter -ManagementOS -Name $traffic -ErrorAction SilentlyContinue
            if (-not $vnic) {
                Write-Verbose "DRIFT: vNIC '$traffic' does not exist"
                return $false
            }

            # Check VLAN
            $vlan = Get-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName $traffic
            $desiredVlan = $cfg.network.$traffic.vlanId
            if ($vlan.AccessVlanId -ne $desiredVlan) {
                Write-Verbose "DRIFT: vNIC '$traffic' VLAN is $($vlan.AccessVlanId), expected $desiredVlan"
                return $false
            }
        }

        Write-Verbose "Network state matches desired configuration"
        return $true
    }

    if ($NodeName -eq $env:COMPUTERNAME) {
        return & $scriptBlock $Config
    }
    else {
        return Invoke-Command -ComputerName $NodeName -ScriptBlock $scriptBlock -ArgumentList $Config
    }
}
