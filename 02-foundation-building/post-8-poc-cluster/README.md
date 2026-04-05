# Post 8: POC Like You Mean It

This folder contains the lab automation referenced in Post 8.

## Files

- `Deploy-HyperVPOCCluster.ps1` builds the lab cluster.
- `Test-HyperVPOCFailover.ps1` runs the failover and validation checks after deployment.

## Prerequisites

- Lab hardware or nested environment sized for the POC.
- Matching network plan for management, migration, and storage traffic.
- Admin access to every node.
- Time reserved to validate each checkpoint instead of just running the script and hoping.

## Recommended Run Order

```powershell
pwsh .\Deploy-HyperVPOCCluster.ps1
pwsh .\Test-HyperVPOCFailover.ps1
```

## What To Validate After Deployment

- Cluster forms successfully and quorum is healthy.
- Shared storage is visible and available where expected.
- Live migration works between nodes.
- Planned failover and unplanned recovery behave the way the blog describes.

## Scope Note

This is a confidence-building lab workflow, not a production hardening script. Use it to prove the concepts, then carry the validated patterns into the production architecture posts.

## Related Post

Blog post: POC Like You Mean It
