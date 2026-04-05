# Hyper-V Hardening Checklist

## Baseline

- UEFI Secure Boot verified.
- TPM 2.0 present and ready.
- VBS and Credential Guard state verified.
- SMB encryption enabled for cluster traffic where appropriate.
- Defender real-time protection enabled.
- Unused services and legacy protocols reviewed.

## Enhanced

- vTPM and Secure Boot enabled for sensitive VMs.
- BitLocker strategy defined for host volumes and CSVs.
- Admin access segmented with dedicated management workflows.
- Logging forwarded to your monitoring platform.

## Advanced

- HGS requirements reviewed.
- Shielded VM candidate workloads identified.
- Compliance evidence collection mapped to audit needs.
