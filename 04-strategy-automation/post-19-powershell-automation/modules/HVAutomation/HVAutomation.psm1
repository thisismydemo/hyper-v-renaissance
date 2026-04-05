#Requires -Version 7.0
<#
.SYNOPSIS
    HVAutomation module loader.
.DESCRIPTION
    Dot-sources all public and private functions from the module directory.
    Series: The Hyper-V Renaissance
    Post: 19 - PowerShell Automation Patterns
    Repository: https://github.com/thisismydemo/hyper-v-renaissance
#>

$PublicFunctions = Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue
$PrivateFunctions = Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue

foreach ($function in @($PublicFunctions) + @($PrivateFunctions)) {
    try {
        . $function.FullName
    }
    catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

Export-ModuleMember -Function $PublicFunctions.BaseName
