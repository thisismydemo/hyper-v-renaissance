# Post 19 Execution Walkthrough

This walkthrough turns the Post 19 toolkit into a practical run order.

## Goal

Use the PowerShell 7 automation framework to define environment-specific values, test current state, and then apply repeatable Hyper-V host configuration without hardcoding each site into the scripts.

## Step 1: Prepare The Workstation

- Install PowerShell 7.4 or later.
- Install Pester 5.
- Confirm PSRemoting connectivity to the Hyper-V hosts.
- Clone the repository to a management workstation or jump box.

```powershell
winget install --id Microsoft.PowerShell --source winget
Install-Module Pester -Scope CurrentUser -Force
Test-WSMan hv-host-prod-sea01-001
```

## Step 2: Create The Environment File

Copy the template in `variables/` and replace the sample values with your site values.

```powershell
Copy-Item .\variables\environment.template.json .\variables\environment.prod.json
```

Populate at least:

- environment name and site
- hostnames and cluster name
- management, migration, and storage VLAN data
- any storage, switch, and path defaults your module functions expect

## Step 3: Import The Module

```powershell
Import-Module .\modules\HVAutomation\HVAutomation.psd1 -Force
$config = Import-HVConfig -Path .\variables\environment.prod.json
```

## Step 4: Test Before You Set

Run the `Test-*` functions first. The point of this pattern is to see drift before you enforce anything.

```powershell
Test-HVNetworkState -Config $config
Test-HVClusterNodeState -Config $config
```

## Step 5: Apply Desired State

Apply only the functions that map to the part of the host you are standardizing.

```powershell
Set-HVNetworkState -Config $config
Set-HVClusterNodeState -Config $config
```

## Step 6: Use DSC Where Drift Matters Most

The DSC configuration in `dsc-config/` is for settings you want to represent declaratively and check repeatedly.

```powershell
dsc config test --file .\dsc-config\hyperv-host.dsc.yaml
dsc config set --file .\dsc-config\hyperv-host.dsc.yaml
```

## Step 7: Put It In A Pipeline

Use the examples in `pipelines/` only after the module and variables file work cleanly by hand. CI should automate a known-good workflow, not discover one for you.

## Practical Rule

If a change is large, destructive, or touches networking or storage, run the test and set functions interactively first. Promote to pipeline execution only after you have a clean manual run and a rollback plan.
