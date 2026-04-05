# Post 6: Three-Tier Storage Integration

This folder contains the storage integration scripts referenced in Post 6.

## Files

- `Configure-iSCSIStorage.ps1` configures MPIO, iSCSI initiator settings, and target connectivity.
- `Configure-PureStorage.ps1` contains the Pure Storage-oriented workflow used in the post's reference implementation.

## Prerequisites

- Hyper-V host already built and domain joined.
- Storage networking configured and tested.
- MPIO feature installed.
- Target portal IPs, initiator IPs, and target IQNs documented.
- Vendor best-practice guide for your array reviewed before production use.

## Recommended Run Order

1. Start with the generic iSCSI script and validate pathing.
2. Apply the vendor-specific reference script only after the base connectivity is clean.
3. Confirm MPIO policy, visible disks, and SAN policy before presenting production CSVs.

```powershell
pwsh .\Configure-iSCSIStorage.ps1
pwsh .\Configure-PureStorage.ps1
```

## What To Review Before Production

- Path count and failover behavior.
- Jumbo frame and RDMA settings if your network design uses them.
- Array-specific timeout and multipath recommendations.
- Backup tooling support for the final filesystem and snapshot design.

## Related Post

Blog post: Three-Tier Storage Integration
