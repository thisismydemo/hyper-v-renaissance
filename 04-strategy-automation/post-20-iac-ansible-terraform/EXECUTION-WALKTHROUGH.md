# Post 20 Execution Walkthrough

This walkthrough gives readers the exact order to use the Post 20 artifacts.

The rule for this series stays the same:

1. Use PowerShell first when it already solves the problem cleanly.
2. Add Ansible when you need inventory-driven configuration management.
3. Add Terraform when VM lifecycle and state tracking are worth the added overhead.

## Option 1: Ansible for Host Configuration

Use this when you want to baseline or remediate Hyper-V hosts.

### Recommended Order

1. Prepare a Linux, macOS, or WSL control node with Ansible and WinRM dependencies.
2. Install the required collections.
3. Copy and update the sample inventory.
4. Review the shared variables for feature selection, switch names, and host settings.
5. Run the host configuration playbook in check mode.
6. Run the playbook for real.
7. Re-run in check mode to verify drift is gone.

### Commands

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
cp inventory/hosts.ini.example inventory/hosts.ini
ansible-playbook -i inventory/hosts.ini playbooks/configure-hyperv-host.yml --check --diff
ansible-playbook -i inventory/hosts.ini playbooks/configure-hyperv-host.yml
ansible-playbook -i inventory/hosts.ini playbooks/configure-hyperv-host.yml --check --diff
```

### Files Used

- `ansible/requirements.yml`
- `ansible/inventory/hosts.ini.example`
- `ansible/group_vars/hyperv_hosts.yml`
- `ansible/playbooks/configure-hyperv-host.yml`
- `scripts/Initialize-HyperVIacHost.ps1`

## Option 2: Terraform for Provisioning, PowerShell for Guest Bootstrap

Use this when you want declarative VM creation and accept the provider caveats documented in the blog and README.

### Recommended Order

1. Review the lab environment and provider settings.
2. Copy the example variable and backend files.
3. Set WinRM credentials as environment variables.
4. Run `terraform init`.
5. Run `terraform plan` and review the result.
6. Run `terraform apply`.
7. Validate the guest bootstrap outcome from the VM itself or with a follow-up configuration tool.

### Commands

```powershell
Set-Location terraform/environments/lab
Copy-Item terraform.tfvars.example terraform.tfvars
Copy-Item backend.hcl.example backend.hcl
$env:HYPERV_USER = "DOMAIN\svc_terraform"
$env:HYPERV_PASSWORD = "<set-from-secret-store>"
terraform init -backend-config=backend.hcl
terraform validate
terraform plan
terraform apply
```

### Files Used

- `terraform/environments/lab/`
- `terraform/modules/hyperv-vm/`
- `scripts/Invoke-HyperVGuestBootstrap.ps1`

## Option 3: Terraform Then Ansible

Use this when provisioning and guest configuration are separate stages.

### Recommended Order

1. Run the Terraform workflow first to create the VM and network primitives.
2. Capture the resulting IP address or hostname from Terraform output.
3. Add the new VM to Ansible inventory or your dynamic inventory source.
4. Run the Ansible playbook in check mode.
5. Run the Ansible playbook for real.
6. Re-run both `terraform plan` and `ansible-playbook --check` as verification steps.

### Commands

```powershell
Set-Location terraform/environments/lab
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
terraform output
```

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/provision-vm.yml --check --diff
ansible-playbook -i inventory/hosts.ini playbooks/provision-vm.yml
ansible-playbook -i inventory/hosts.ini playbooks/provision-vm.yml --check --diff
```

### Files Used

- `terraform/environments/lab/`
- `ansible/playbooks/provision-vm.yml`
- `pipelines/`

## CI/CD Run Order

For teams moving this into a pipeline, the practical order is:

1. Lint or validate the code.
2. Run a dry-run or plan stage.
3. Require manual approval for apply.
4. Run verification after apply.

Examples in this folder:

- `pipelines/github-actions/ansible-validate.yml`
- `pipelines/github-actions/terraform-plan-apply.yml`
- `pipelines/azure-devops/azure-pipelines.yml`
- `pipelines/gitlab-ci/.gitlab-ci.yml`

## What Readers Should Actually Start With

For most readers of this series:

1. Start with Post 19 PowerShell patterns.
2. Use the Ansible path here if you already run Ansible.
3. Use the Terraform path here only when you genuinely need declarative VM lifecycle and state tracking.
