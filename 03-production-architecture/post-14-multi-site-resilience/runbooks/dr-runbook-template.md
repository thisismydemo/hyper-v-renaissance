# DR Runbook Template

## Scenario

Describe the outage or maintenance event that triggers the runbook.

## Preconditions

- Secondary site healthy
- Replication state current enough for business approval
- Change approval and communications issued

## Execution Steps

1. Validate primary-site status.
2. Confirm replication health.
3. Execute failover.
4. Validate core services.
5. Release applications to users.

## Failback Steps

Document the reverse path and any data reconciliation activity.
