# Post 14: Multi-Site Resilience

This folder contains the planning and runbook artifacts for Post 14.

## Contents

- `scripts/Configure-HyperVReplica.ps1` enables the replica server role and can enable replication for a target VM.
- `templates/rpo-rto-decision-matrix.csv` helps match technology to business requirements.
- `guides/storage-replica-deployment-guide.md` summarizes the Storage Replica planning path.
- `checklists/dr-testing-checklist.md` organizes validation work.
- `runbooks/dr-runbook-template.md` provides the operator runbook structure.

## Practical Rule

Backups and replication solve different problems. Use this folder to plan the replication side and pair it with Post 13 for backup.
