# Post 7: Migrating VMs from VMware to Hyper-V

This folder contains the assessment, conversion, and validation scripts used in Post 7.

## Files

- `Get-VMwareInventory.ps1` inventories VMware workloads before planning migration waves.
- `Convert-VMDKtoVHDX.ps1` handles the conversion workflow for supported scenarios.
- `Invoke-PostMigrationValidation.ps1` validates the Hyper-V guest after cutover.

## Prerequisites

- A validated migration wave plan.
- Access to source VMware inventory.
- A supported conversion path for the guest OS and virtual hardware profile.
- A rollback plan before touching production workloads.

## Recommended Run Order

```powershell
pwsh .\Get-VMwareInventory.ps1
pwsh .\Convert-VMDKtoVHDX.ps1
pwsh .\Invoke-PostMigrationValidation.ps1
```

## What Success Looks Like

- VMware source inventory is exported and reviewed.
- Converted disks attach cleanly on Hyper-V.
- Guest boots without VMware-specific device assumptions blocking startup.
- Post-migration checks confirm networking, services, time sync, and application health.

## Common Failure Points

- Unsupported guest drivers or old VMware Tools residue.
- BIOS versus UEFI mismatches during conversion.
- Unplanned IP or DNS changes after first Hyper-V boot.

## Related Post

Blog post: Migrating VMs from VMware to Hyper-V
