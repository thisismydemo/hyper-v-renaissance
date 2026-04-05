# Arc-Enabled SCVMM Enrollment Guide

## Best Fit

Use this path when:

- you already run SCVMM
- you want Azure Portal visibility and RBAC for SCVMM-managed VMs
- you want to extend, not replace, your existing management plane

## Core Components

- SCVMM 2019, 2022, or 2025
- Azure Arc resource bridge
- Azure subscription, resource group, and governance model

## Practical Notes

- Validate the current support matrix before rollout.
- Treat Azure Arc-enabled SCVMM as an extension of your control plane, not a substitute for local operational discipline.
- Start with one management server and one non-critical workload group before broad rollout.
