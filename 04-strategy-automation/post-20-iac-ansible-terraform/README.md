# Post 20: Infrastructure as Code with Ansible and Terraform

IaC patterns for Hyper-V using Ansible, Terraform + PowerShell, and Terraform + Ansible.

## Directory Structure

```
post-20-iac-ansible-terraform/
├── ansible/
│   ├── inventory/          # Ansible inventory files (hosts.ini, dynamic)
│   ├── playbooks/          # Ansible playbooks for Hyper-V management
│   ├── roles/              # Ansible roles (hyperv-host, hyperv-cluster, etc.)
│   └── group_vars/         # Group variables (connection settings, desired state)
├── terraform/
│   ├── modules/            # Terraform modules (vm, network, cluster)
│   └── environments/       # Per-environment .tfvars files (prod, dev)
├── pipelines/
│   ├── github-actions/     # GitHub Actions workflows for Ansible and Terraform
│   ├── gitlab-ci/          # GitLab CI pipelines
│   └── azure-devops/       # Azure DevOps pipelines
└── README.md
```

## Status

Directory structure is ready. Automation files will be developed iteratively.
Contributions welcome — follow the patterns established in Post 19 (PowerShell 7, 
idempotent patterns, variables-driven, CI/CD-ready).

## Requirements

### Ansible
- Ansible 2.18+ on a Linux/macOS/WSL control node
- Collections: `ansible.windows`, `microsoft.hyperv`, `community.windows`
- Python `pywinrm` for WinRM connectivity
- Kerberos client libraries for domain authentication

### Terraform  
- Terraform 1.6+
- Provider: `taliesins/hyperv` (community) or `hashicorp/azurerm` (for Azure Local)
- WinRM connectivity to Hyper-V hosts
- Remote state backend (Azure Storage, MinIO, Consul)

## Series

Part of [The Hyper-V Renaissance](https://thisismydemo.cloud) blog series.
