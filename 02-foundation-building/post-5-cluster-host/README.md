# Post 5: Build and Validate a Cluster-Ready Host

This folder contains the companion scripts for Post 5 of The Hyper-V Renaissance.

## Files

- `Deploy-HyperVNode.ps1` builds a host through the staged deployment phases from the blog.
- `Validate-HyperVNode.ps1` runs post-build validation checks before cluster formation.

## Prerequisites

- Windows Server 2025 installed on the target host.
- Local administrator access.
- Planned host naming, IP addressing, VLAN IDs, and domain OU path.
- Physical NIC names confirmed with `Get-NetAdapter`.
- Storage target details available if you are using iSCSI.

## Before You Run Anything

1. Open `Deploy-HyperVNode.ps1` and replace the placeholder values at the top of the file.
2. Confirm your NIC names, VLAN IDs, IPs, DNS servers, and iSCSI target details.
3. Decide whether you want to run the script phase by phase or in a controlled orchestration wrapper.

## Recommended Run Order

Run the deployment script in stages because several phases require a reboot or a reconnect.

```powershell
pwsh .\Deploy-HyperVNode.ps1 -Phase 1
pwsh .\Deploy-HyperVNode.ps1 -Phase 1b
pwsh .\Deploy-HyperVNode.ps1 -Phase 2
pwsh .\Deploy-HyperVNode.ps1 -Phase 3
pwsh .\Deploy-HyperVNode.ps1 -Phase 4
pwsh .\Deploy-HyperVNode.ps1 -Phase 4b
pwsh .\Deploy-HyperVNode.ps1 -Phase 5
pwsh .\Deploy-HyperVNode.ps1 -Phase 6
pwsh .\Validate-HyperVNode.ps1
```

## What Success Looks Like

- Required roles install cleanly.
- SET switch and management vNICs are created with the expected addressing.
- MPIO and iSCSI sessions are visible.
- Hyper-V host defaults are set.
- Validation finishes without unresolved failures that would block `Test-Cluster`.

## Common Failure Points

- Placeholder NIC names were not updated.
- Domain join OU path is wrong.
- iSCSI target portals or IQNs are still sample values.
- Reboot phases were skipped and later phases were attempted anyway.

## Related Post

Blog post: Build and Validate a Cluster-Ready Host
