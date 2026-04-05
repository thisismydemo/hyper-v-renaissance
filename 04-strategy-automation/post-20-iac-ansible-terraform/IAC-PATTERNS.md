# IaC Patterns for Hyper-V

This document maps the three practical patterns from Post 20 to the artifacts in this folder.

## Pattern 1: Ansible for Host Configuration

Use this when you already operate Ansible and need repeatable configuration across Hyper-V hosts.

Flow:

1. Control node connects to Hyper-V hosts over WinRM.
2. `ansible.windows` modules install features, manage services, and handle required reboots.
3. `Initialize-HyperVIacHost.ps1` handles Hyper-V-specific setup such as creating a virtual switch.
4. Re-running the playbook checks current state and only applies drift corrections.

Use this pattern for:

- Host baseline configuration
- WinRM setup verification
- Feature installation and service configuration
- Repeatable virtual switch creation

Artifacts:

- `ansible/playbooks/configure-hyperv-host.yml`
- `ansible/roles/hyperv_host/`
- `scripts/Initialize-HyperVIacHost.ps1`

## Pattern 2: Terraform for Provisioning, PowerShell for Guest Bootstrap

Use this when your team already thinks in Terraform state and wants VM lifecycle in code.

Flow:

1. Terraform creates the switch, VHDX, and Generation 2 VM.
2. Terraform optionally uses WinRM provisioners to copy and invoke a PowerShell guest bootstrap script.
3. Ongoing guest configuration should move to Ansible, DSC, or another configuration management layer rather than staying inside Terraform provisioners.

Use this pattern for:

- Lab or platform VM provisioning
- Declarative VM inventory
- Integration with existing Terraform review and approval workflows

Artifacts:

- `terraform/modules/hyperv-vm/`
- `terraform/environments/lab/`
- `scripts/Invoke-HyperVGuestBootstrap.ps1`

## Pattern 3: Terraform + Ansible

Use this when infrastructure creation and guest configuration belong to different stages or different teams.

Flow:

1. Terraform creates the infrastructure primitives.
2. Pipeline or orchestration layer publishes connection details.
3. Ansible consumes those details and applies configuration state.
4. Verification runs in both Terraform (`plan`) and Ansible (`--check`).

Use this pattern for:

- Multi-platform teams
- Mature GitOps or CI/CD operating models
- Environments where VM lifecycle and guest state are managed separately

Artifacts:

- `terraform/environments/lab/`
- `ansible/playbooks/`
- `pipelines/`

## What Not To Do

- Do not try to model WSFC, CSVs, live migration tuning, and full guest configuration exclusively in Terraform.
- Do not use Terraform provisioners as the long-term drift-remediation layer.
- Do not add Ansible or Terraform if Post 19 PowerShell already solves the problem cleanly for your team.

## Recommended Default

For most standalone Hyper-V environments in this series:

1. Use PowerShell and DSC as the primary automation layer.
2. Add Ansible when cross-platform configuration management is a real requirement.
3. Add Terraform when declarative VM provisioning and state tracking are worth the added operational overhead.
