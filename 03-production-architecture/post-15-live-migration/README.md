# Post 15: Live Migration Internals and Optimization

This folder contains the supporting tools for Post 15.

## Contents

- `scripts/Test-LiveMigrationReadiness.ps1` checks common prerequisites for successful live migration.
- `scripts/Measure-LiveMigrationEstimate.ps1` estimates transfer time from memory size and effective bandwidth.
- `guides/live-migration-optimization-guide.md` summarizes the tuning and troubleshooting flow.

## Recommended Use

Run the readiness script before change windows. Use the estimator to set expectations with stakeholders for large-memory workloads.
