#Requires -Version 7.0
function Import-HVConfig {
    <#
    .SYNOPSIS
        Loads and validates an environment configuration file.
    .DESCRIPTION
        Reads a JSON environment configuration file and returns a validated
        PSCustomObject. Supports parameter overrides for CI/CD scenarios.
        Series: The Hyper-V Renaissance
        Post: 19 - PowerShell Automation Patterns
    .PARAMETER Path
        Path to the environment JSON file.
    .PARAMETER Overrides
        Hashtable of property overrides (dot-notation keys).
        Example: @{ 'cluster.name' = 'cl-test-001' }
    .EXAMPLE
        $config = Import-HVConfig -Path './variables/environment.prod.json'
    .EXAMPLE
        $config = Import-HVConfig -Path './variables/environment.prod.json' -Overrides @{
            'environment.name' = 'staging'
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [hashtable]$Overrides = @{}
    )

    $config = Get-Content -Path $Path -Raw | ConvertFrom-Json -Depth 10

    # Apply overrides
    foreach ($key in $Overrides.Keys) {
        $parts = $key -split '\.'
        $current = $config
        for ($i = 0; $i -lt $parts.Count - 1; $i++) {
            $current = $current.($parts[$i])
        }
        $current.($parts[-1]) = $Overrides[$key]
    }

    # Validate required fields
    $requiredFields = @(
        'environment.name', 'environment.site', 'environment.domain',
        'naming.switchName', 'cluster.name'
    )
    foreach ($field in $requiredFields) {
        $parts = $field -split '\.'
        $value = $config
        foreach ($part in $parts) { $value = $value.$part }
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "Required configuration field '$field' is empty or missing in $Path"
        }
    }

    return $config
}
