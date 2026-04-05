# Post 13: Backup Strategies for Hyper-V

This folder contains the planning and validation artifacts for Post 13.

## Contents

- `scripts/Test-HyperVBackupReadiness.ps1` audits the Hyper-V and VSS conditions that commonly break backups.
- `worksheets/rpo-rto-planning.csv` captures the business recovery requirements for each workload tier.
- `templates/backup-solution-comparison.csv` compares backup platforms in a format you can adapt.
- `guides/azure-backup-configuration-guide.md` outlines the Azure Backup path for readers who want that option.

## Recommended Use

Use the worksheet first, the comparison template second, and the readiness script before any production backup rollout.
