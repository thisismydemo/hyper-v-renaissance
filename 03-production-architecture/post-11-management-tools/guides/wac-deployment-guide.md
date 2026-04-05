# WAC Deployment Guide

## Recommended Pattern

- Deploy WAC on a dedicated management server.
- Use HTTPS with a trusted certificate.
- Keep the gateway separate from the hosts it manages.
- Treat extensions and preview features as change-controlled additions.

## Baseline Steps

1. Install WAC on a management server.
2. Bind HTTPS and confirm DNS resolution.
3. Add hosts and clusters.
4. Validate cluster, VM, and performance workflows before expanding access.

## Operational Notes

- WAC is excellent for day-to-day administration.
- It complements PowerShell and does not replace it.
- Validate preview features against current Microsoft release notes before treating them as a strategic dependency.
