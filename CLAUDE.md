# hyper-v-renaissance — Claude Code Context

## What this repo is

This repository contains all scripts, templates, diagrams, checklists, and supporting resources for the blog series:

---

## ADO project details

- **ADO org:** https://dev.azure.com/hybridcloudsolutions
- **ADO project:** This Is My Demo
- **Area path:** Platform Engineering\Onboarding
- **Work item format:** `AB#<id>` in commit messages and PR descriptions

---

## Standards

This repo follows all HCS platform standards defined in the Platform Engineering repo:

| Standard | Reference |
|---|---|
| Governance | [docs/standards/governance.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/governance.md) |
| Scripting (PowerShell 7) | [docs/standards/scripting.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/scripting.md) |
| Automation | [docs/standards/automation.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/automation.md) |
| Variables and naming | [docs/standards/variables.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/variables.md) |
| Documentation | [docs/standards/documentation.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/documentation.md) |
| Claude Code | [docs/standards/claude-code.md](https://dev.azure.com/hybridcloudsolutions/Platform%20Engineering/_git/Platform%20Engineering?path=/docs/standards/claude-code.md) |

Key rules:
- All scripts: PowerShell 7+ only. `#Requires -Version 7.0`, `Set-StrictMode -Version Latest`, ` $ErrorActionPreference = 'Stop'`.
- All docs: Markdown only. No Word documents in any repo.
- Commit format: `type(scope): short description` — types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`
- No secrets, tokens, or credentials committed to any file.

---

## Key facts

| Fact | Value |
|---|---|
| Primary language | Mixed |
| GitHub org | thisismydemo |
| Azure login | kris@hybridsolutions.cloud |
| Key Vault | kv-hcs-vault-01 |

### Environment variables expected

| Variable | Source | Purpose |
|---|---|---|
| `GITHUB_TOKEN` | kv-hcs-vault-01 via Load-HCSEnvironment.ps1 | GitHub CLI and git operations |
| `AZURE_DEVOPS_EXT_PAT` | kv-hcs-vault-01 via Load-HCSEnvironment.ps1 | ADO CLI (`az boards`, `az devops`) |
Load before starting a session:
```powershell
. E:\git\platform\scripts\Load-HCSEnvironment.ps1
```

### Build and test commands

```
# No standard build commands detected
```

---

## Repo structure

```
hyper-v-renaissance/
├── .claude/
    └── settings.json
├── 01-case-for-change/
    ├── post-1-welcome/
    ├── post-2-tco/
    ├── post-3-myth-old-tech/
    └── post-4-reuse-vmware/
├── 02-foundation-building/
    ├── post-5-cluster-host/
    ├── post-6-storage-integration/
    ├── post-7-vm-migration/
    └── post-8-poc-cluster/
├── 03-production-architecture/
    ├── post-10-security/
    ├── post-11-management-tools/
    ├── post-12-storage-architecture/
    ├── post-13-backup-dr/
    └── post-14-multi-site-resilience/
├── 04-strategy-automation/
    ├── post-17-hybrid-without-handcuffs/
    ├── post-18-s2d-three-tier-azure-local/
    ├── post-19-powershell-automation/
    └── post-20-iac-ansible-terraform/
├── 05-series-wrap-up/
    └── post-21-what-was-under-your-nose-all-along/
├── diagrams/
    ├── azure-services-comparison.drawio
    ├── backup-architecture.drawio
    ├── cluster-set-architecture.drawio
    ├── csv-io-architecture.drawio
    └── csv-troubleshooting-tree.drawio
├── references/
    └── vcf/
├── CLAUDE.md
└── README.md
```

---

## Claude Code actions

**Run autonomously:**
- Read, search, and grep any file in this repo
- Write and edit files in this repo
- `git add`, `git commit`, `git push`
- `gh issue`, `gh pr`, `gh run` CLI commands


**Always confirm before:**
- Creating or deleting Azure resources
- Any `az` CLI write operation that modifies Azure state
- Running destructive operations
- Making API calls to external services


---

## Subagents available in this repo

- `hyper-v-renaissance-engineer` (model: sonnet) — Expert in `hyper-v-renaissance`: deep knowledge of this repo's structure, conventions, and development workflow.

User-level agents (available in every repo session): `triage-lookup`, `markdown-prose-editor`, `azurelocal-domain-expert`, `mkdocs-material-doctor`, `turner-module-scaffold-engineer`, `mms-2026-demo-presenter`.

---

## Owner

**Kristopher Turner**
kris@hybridsolutions.cloud
Senior Product Technology Architect, TierPoint | Microsoft MVP (Azure) | MCT
Owner, Hybrid Cloud Solutions LLC — hybridsolutions.cloud
Country Cloud Boy — thisismydemo.cloud