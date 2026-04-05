[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ReplicaServerName,
    [ValidateSet('Kerberos','Certificate')]
    [string]$Authentication = 'Kerberos',
    [string]$ReplicaStorageLocation = 'D:\Hyper-V\Replica',
    [string]$VMName,
    [string]$PrimaryServer,
    [uint32]$ReplicationFrequencySec = 300
)

if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Configure Hyper-V Replica Server')) {
    Set-VMReplicationServer -ReplicationEnabled $true -AllowedAuthenticationType $Authentication -ReplicationAllowedFromAnyServer $true -DefaultStorageLocation $ReplicaStorageLocation
}

if ($VMName -and $PrimaryServer -and $ReplicaServerName) {
    if ($PSCmdlet.ShouldProcess($VMName, 'Enable VM replication')) {
        Enable-VMReplication -VMName $VMName -ReplicaServerName $ReplicaServerName -ReplicaServerPort 80 -AuthenticationType $Authentication -CompressionEnabled $true -RecoveryHistory 24 -ReplicationFrequencySec $ReplicationFrequencySec
        Start-VMInitialReplication -VMName $VMName
    }
}
