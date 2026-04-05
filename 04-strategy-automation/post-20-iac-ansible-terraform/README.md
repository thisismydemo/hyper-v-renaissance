# Post 20: Infrastructure as Code with Ansible and Terraform

IaC patterns for Hyper-V using Ansible, Terraform + PowerShell, and Terraform + Ansible.

This folder contains the companion deliverables for Post 20 of The Hyper-V Renaissance. The approach is intentionally honest:

- Ansible is used with validated Windows modules from `ansible.windows`.
- PowerShell remains the control plane for Hyper-V-specific operations that do not have first-class Ansible coverage in this repo.
- Terraform examples use the community `taliesins/hyperv` provider with explicit caveats about maturity and scope.
- CI/CD examples assume self-hosted runners with network access to on-prem Hyper-V hosts.

## Directory Structure

```
post-20-iac-ansible-terraform/
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventory/
│   │   └── hosts.ini.example
│   ├── group_vars/
│   │   └── hyperv_hosts.yml
│   ├── playbooks/
│   │   ├── configure-hyperv-host.yml
│   │   └── provision-vm.yml
│   └── roles/
│       └── hyperv_host/
│           ├── defaults/
│           │   └── main.yml
│           └── tasks/
│               └── main.yml
├── terraform/
│   ├── modules/
│   │   └── hyperv-vm/
│   └── environments/
│       └── lab/
├── pipelines/
│   ├── github-actions/
│   ├── gitlab-ci/
│   └── azure-devops/
├── scripts/
│   ├── Initialize-HyperVIacHost.ps1
│   └── Invoke-HyperVGuestBootstrap.ps1
├── IAC-PATTERNS.md
├── TOOLING-DECISION-GUIDE.md
└── README.md
```

## What Is Included

- Ansible host-configuration content using `ansible.windows.win_feature`, `ansible.windows.win_service`, `ansible.windows.win_reboot`, `ansible.windows.win_copy`, and `ansible.windows.win_powershell`
- Variables-driven Ansible inventory and group variables
- Terraform module examples for Generation 2 VM provisioning on Hyper-V
- Terraform environment example showing a lab switch, VM provisioning, and optional PowerShell bootstrap via WinRM provisioners
- PowerShell helper scripts shared across both Ansible and Terraform patterns
- Pipeline examples for GitHub Actions, GitLab CI, and Azure DevOps
- Decision and pattern documentation that mirrors the blog's guidance
- An execution-order walkthrough that shows readers what to run first and how the Ansible and Terraform flows differ

## Validated Tooling Basis

The examples in this folder are based on the following documented behaviors:

- Ansible Windows management over WinRM/PSRP with Kerberos or HTTPS
- `ansible.windows` Windows modules for feature installation, service management, reboots, and PowerShell execution
- Terraform provisioner guidance that treats provisioners as a last resort rather than the primary configuration mechanism
- Terraform S3 backend support for remote state and lock files
- Terraform community provider `taliesins/hyperv` version `1.2.1`

## Known Caveats

- The Hyper-V Terraform provider is community maintained. Treat these modules as examples that must be validated in your own lab before production use.
- Terraform examples in this folder focus on VM lifecycle and switch creation, not WSFC or advanced Hyper-V capabilities.
- Ansible examples in this folder lean on PowerShell for Hyper-V-specific steps because that remains the most complete interface.
- Remote state examples use S3-compatible storage because that maps well to on-prem patterns such as MinIO, but HashiCorp only offers best-effort support for S3-compatible backends.

## Quick Start

If you want the exact run order before touching any files, start with `EXECUTION-WALKTHROUGH.md`.

### Ansible

1. Install Ansible and Python WinRM dependencies on a Linux, macOS, or WSL control node.
2. Run `ansible-galaxy collection install -r ansible/requirements.yml`.
3. Copy `ansible/inventory/hosts.ini.example` to `ansible/inventory/hosts.ini` and update hostnames and connection settings.
4. Review `ansible/group_vars/hyperv_hosts.yml` and adjust features, switch names, and VM definitions.
5. Run `ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/configure-hyperv-host.yml --check`.

### Terraform

1. Review `terraform/environments/lab/backend.hcl.example` and adapt it to your remote state backend.
2. Copy `terraform/environments/lab/terraform.tfvars.example` to `terraform/environments/lab/terraform.tfvars`.
3. Set `HYPERV_USER` and `HYPERV_PASSWORD` in your shell or pipeline secret store.
4. Run `terraform init -backend-config=backend.hcl.example` in `terraform/environments/lab`.
5. Run `terraform plan` and review the output before any apply.

## Related Posts

- Post 19 provides the PowerShell-native baseline that these examples build on.
- Post 17 covers Azure Arc and hybrid operations if you decide Terraform should target Azure-managed control planes instead of direct Hyper-V.
- Post 18 explains when Azure Local may be a better Terraform target than standalone Hyper-V.

## Series

Part of [The Hyper-V Renaissance](https://thisismydemo.cloud) blog series.
