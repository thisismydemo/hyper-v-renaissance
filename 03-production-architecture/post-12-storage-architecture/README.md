# Post 12: Storage Architecture Deep Dive

This folder contains the decision tools and operational artifacts for Post 12.

## Contents

- `scripts/Invoke-CSVHealthAudit.ps1` captures CSV state, ownership, and redirected I/O indicators.
- `templates/storage-design-decision-matrix.csv` compares protocol and architecture choices.
- `templates/perfmon-storage-baseline.txt` is a counter list you can import into a Data Collector Set.
- `guides/csv-troubleshooting-guide.md` organizes common CSV symptoms and what to check next.

## Recommended Use

Start with the decision matrix during design. Use the audit script and perfmon template once the cluster is live.
