# Tooling Decision Guide

Use this guide to choose the right automation pattern for your Hyper-V environment.

| Your Situation | Recommended Pattern | Why |
|---|---|---|
| Windows-only infrastructure team | PowerShell + DSC from Post 19 | Native coverage, lowest complexity, complete Hyper-V access |
| Existing Ansible investment | Ansible + PowerShell helpers | Reuse your control plane while keeping PowerShell for Hyper-V gaps |
| Existing Terraform investment | Terraform + PowerShell bootstrap | Keeps provisioning declarative while acknowledging provider limits |
| Large multi-platform environment | Terraform + Ansible | Best separation of concerns for platform and guest state |
| Small lab or POC | PowerShell only or Terraform lab module | Fastest path without unnecessary platform overhead |
| Strict change review around provisioning | Terraform | `plan` output gives deterministic create/modify/destroy review |
| Strict drift remediation across hosts | Ansible | Re-checks current host state on every run |

## Decision Rules

### Choose PowerShell First When

- You need full Hyper-V coverage.
- Your team already works in PowerShell.
- You do not need a separate control node or state file.

### Add Ansible When

- You already manage Linux and Windows from the same automation platform.
- You want inventory-driven host configuration.
- WinRM and Kerberos are already accepted patterns in your environment.

### Add Terraform When

- VM lifecycle itself needs to be declarative.
- You want reviewable `plan` output and state tracking.
- The provider's current scope is enough for your use case.

### Avoid Terraform as the Only Layer When

- You need cluster operations.
- You need ongoing guest drift remediation.
- You are automating advanced Hyper-V features outside the provider's current scope.

## Practical Recommendation for This Series

The default guidance for The Hyper-V Renaissance remains:

1. Start with Post 19 PowerShell patterns.
2. Layer in Ansible when your operating model already justifies it.
3. Use Terraform carefully and explicitly, with the community provider caveat understood before production adoption.
