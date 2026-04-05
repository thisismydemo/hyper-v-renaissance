# Post 17: Hybrid Without the Handcuffs

This folder contains the selective Azure adoption artifacts for Post 17.

## Contents

- `scripts/Install-ArcConnectedMachineAgent.ps1` stages and connects the Azure Arc agent when you supply your tenant and subscription details.
- `templates/hybrid-service-cost-model.csv` helps compare optional Azure services against the workloads that actually need them.
- `guides/selective-azure-adoption-guide.md` explains how to choose Azure services one by one instead of adopting Azure Local wholesale.
- `guides/arc-scvmm-enrollment-guide.md` outlines the Arc-enabled SCVMM path for readers already using SCVMM.

## Guiding Principle

Use Azure services where they solve a specific problem. Do not assume Azure Local is the only route to Azure management outcomes.
