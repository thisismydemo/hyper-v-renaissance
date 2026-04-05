# Post 16: WSFC at Scale

This folder contains the planning and automation artifacts for Post 16.

## Contents

- `scripts/Configure-ClusterAwareUpdating.ps1` creates or updates a CAU clustered role.
- `scripts/Set-HyperVAntiAffinity.ps1` applies anti-affinity class names to clustered roles.
- `templates/capacity-planning.csv` provides a simple planning sheet for node and VM growth.
- `runbooks/scale-operations-runbook.md` is the starting point for large-cluster operations.

## Recommended Use

Use the planning sheet and runbook before you expand the cluster. Use the scripts only after your patching and placement strategy are approved.
