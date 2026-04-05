# Post 10: Security Architecture for Hyper-V Clusters

This folder contains audit-first security deliverables for Post 10.

## Contents

- `scripts/Invoke-HyperVSecurityBaseline.ps1` audits key host and cluster security settings and can optionally enforce a small safe subset.
- `scripts/Test-HgsReadiness.ps1` evaluates whether a host is ready for a guarded fabric conversation.
- `checklists/hardening-checklist.md` is a tiered checklist from baseline to advanced controls.
- `guides/compliance-mapping.md` maps the core controls to common compliance language.

## Operating Principle

Run the audit scripts first. Change control comes after evidence.
