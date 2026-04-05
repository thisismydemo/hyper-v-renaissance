# Post 19: PowerShell Automation Patterns (2026 Edition)

PowerShell 7 automation framework for Hyper-V infrastructure management.

## Directory Structure

```
post-19-powershell-automation/
├── modules/
│   └── HVAutomation/          # Idempotent PowerShell module (Get/Test/Set pattern)
│       ├── HVAutomation.psd1  # Module manifest (PS 7.0+)
│       ├── HVAutomation.psm1  # Module loader
│       ├── Public/            # Exported functions
│       ├── Private/           # Internal helpers
│       └── Tests/             # Pester 5.x tests
├── dsc-config/
│   └── hyperv-host.dsc.yaml  # DSC v3 configuration for host desired state
├── variables/
│   ├── environment.template.json  # Template — copy and customize
│   ├── environment.prod.json      # Production config (create from template)
│   └── environment.dev.json       # Dev/test config (create from template)
├── pipelines/
│   ├── github-actions/        # GitHub Actions workflow
│   ├── gitlab-ci/             # GitLab CI pipeline
│   └── azure-devops/          # Azure DevOps pipeline
├── scripts/                   # Orchestration scripts
└── README.md
```

## Quick Start

1. Copy `variables/environment.template.json` to `variables/environment.prod.json`
2. Edit with your environment values (IPs, hostnames, VLANs, etc.)
3. Import the module: `Import-Module ./modules/HVAutomation/HVAutomation.psd1`
4. Test current state: `Test-HVNetworkState -Config (Import-HVConfig -Path ./variables/environment.prod.json)`
5. Apply desired state: `Set-HVNetworkState -Config (Import-HVConfig -Path ./variables/environment.prod.json)`

## Requirements

- PowerShell 7.4+ LTS
- Windows Server 2025 with Hyper-V role
- PSRemoting enabled on target hosts
- Pester 5.x for running tests

## Naming Standards

Based on Microsoft Cloud Adoption Framework (CAF):
- Pattern: `<type>-<workload>-<environment>-<site>-<instance>`
- Hosts: `hv-host-prod-sea01-001`
- Clusters: `cl-hvhost-prod-sea01`
- VMs: `vm-sql-prod-sea01-001`

## CI/CD

Self-hosted runner required on a management server with PSRemoting access to Hyper-V hosts.
Pipeline examples provided for GitHub Actions, GitLab CI, and Azure DevOps.

## Series

Part of [The Hyper-V Renaissance](https://thisismydemo.cloud) blog series.
