# Storage Replica Deployment Guide

## Planning Questions

- Is the requirement zero data loss or near-zero data loss?
- Can the network sustain synchronous writes at the required latency?
- Are the log volumes sized and isolated correctly?
- Is the design server-to-server, cluster-to-cluster, or stretch cluster?

## Practical Notes

- Do not use Storage Replica as a backup replacement.
- Validate bandwidth and latency before promising synchronous behavior.
- Test failover and failback procedures with business owners present.
