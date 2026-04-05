# Azure Backup Configuration Guide

## Use It When

- You already have Azure governance and vault workflows.
- Off-site retention in Azure is part of the requirement.
- You accept that Azure Backup is not the same operational model as Veeam-style instant recovery.

## Planning Notes

- Validate the current MABS support matrix before deployment.
- Map vault retention to the workload RPO and RTO you documented in the worksheet.
- Test restore workflows before you rely on them for production commitments.
