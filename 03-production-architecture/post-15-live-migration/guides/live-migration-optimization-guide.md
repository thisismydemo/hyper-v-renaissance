# Live Migration Optimization Guide

## Focus Areas

- Dedicated migration networks
- SMB with RDMA where available
- Consistent switch naming across hosts
- Correct Kerberos constrained delegation if Kerberos is the chosen auth path
- Large-memory workload expectations set before maintenance windows

## Troubleshooting Order

1. Authentication and delegation
2. Host memory headroom
3. Network path and bandwidth
4. CPU pressure on source and destination
5. Event logs and `Compare-VM` output
