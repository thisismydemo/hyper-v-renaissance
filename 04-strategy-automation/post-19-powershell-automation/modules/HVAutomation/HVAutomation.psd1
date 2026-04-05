@{
    RootModule        = 'HVAutomation.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Country Cloud Boy'
    CompanyName       = 'The Hyper-V Renaissance'
    Copyright         = '(c) 2026. MIT License.'
    Description       = 'Idempotent automation module for Hyper-V host configuration, networking, storage, and VM management. Part of The Hyper-V Renaissance series.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-HVHostState',
        'Test-HVHostState',
        'Set-HVHostState',
        'Get-HVNetworkState',
        'Test-HVNetworkState',
        'Set-HVNetworkState',
        'Get-HVStorageState',
        'Test-HVStorageState',
        'Set-HVStorageState',
        'New-HVClusterVM',
        'Import-HVConfig'
    )
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    PrivateData        = @{
        PSData = @{
            Tags       = @('Hyper-V', 'Automation', 'Infrastructure', 'IaC', 'DSC')
            ProjectUri = 'https://github.com/thisismydemo/hyper-v-renaissance'
            LicenseUri = 'https://github.com/thisismydemo/hyper-v-renaissance/blob/main/LICENSE'
        }
    }
}
