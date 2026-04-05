# Post 11: Management Tools for Production

This folder contains the operator-facing artifacts for Post 11.

## Contents

- `scripts/Enable-HyperVManagementRemoting.ps1` standardizes remoting prerequisites.
- `templates/management-tool-selection-matrix.csv` helps map environment size and needs to the right tool stack.
- `guides/wac-deployment-guide.md` explains the practical WAC deployment path.
- `guides/scvmm-readiness-assessment.md` helps decide whether SCVMM is warranted.

## Practical Rule

For most environments, start with WAC plus PowerShell. Add SCVMM only when your scale and orchestration requirements justify it.
