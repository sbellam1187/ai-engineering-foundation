---
id: REF-security-0003-copilot-security-fix-setup
title: Copilot Security Fix Setup Guide
version: 1.0.0
status: active
owner: enterprise-architecture
concern: security
created: 2026-04-22
lastUpdated: 2026-04-22
description: Step-by-step setup guide for deploying the Copilot Security Fix Automation workflow to a consuming repository. Covers file placement, secrets, octo-sts trust policy, and Copilot coding agent enablement.
related:
  workflows:
    - workflow-security-0005-copilot-security-fix
  skills:
    - SKILL-security-0001-dependency-upgrade-scanner
  agents:
    - AGENT-security-0001-security-scanner
    - AGENT-security-0002-github-vulnerability-fixer
---

# Copilot Security Fix — Setup Guide

## Overview

The **Copilot Security Fix Automation** workflow pre-fetches Dependabot and Code Scanning alerts, creates GitHub Issues with full context, and assigns them to the `copilot-swe-agent` bot which autonomously opens PRs to fix vulnerabilities.

The issues reference the **`@github-vulnerability-fixer`** agent and the **`dependency-upgrade-scanner`** skill, which Copilot uses to classify dependencies and apply the correct fix strategy.

### Source Files (this repo)

| Source path | Deploy to | Purpose |
|-------------|-----------|---------|
| `crosscutting/security/workflows/workflow-security-0005-copilot-security-fix.yml` | `.github/workflows/` | GitHub Actions workflow |
| `crosscutting/security/scripts/copilot-security/copilot-security-fix.sh` | `scripts/copilot-security/` | Main script (issue creation logic) |
| `crosscutting/security/chainguard/copilot-security-fix.sts.yaml` | `.github/chainguard/` | octo-sts trust policy |
| `crosscutting/security/agents/agent-security-0002-github-vulnerability-fixer.md` | `.github/agents/` | Copilot agent — fix strategies and constraints |
| `crosscutting/security/skills/skill-security-0001-dependency-upgrade-scanner.md` | `.github/skills/` | Copilot skill — dependency classification and CVE lookup |

---

## Step 1: Copy Files to Your Repository

Copy the source files to the following **deployed** locations in your target repository:

```
your-repo/
├── .github/
│   ├── agents/
│   │   └── agent-security-0002-github-vulnerability-fixer.md
│   ├── chainguard/
│   │   └── copilot-security-fix.sts.yaml
│   ├── skills/
│   │   └── skill-security-0001-dependency-upgrade-scanner.md
│   └── workflows/
│       └── workflow-security-0005-copilot-security-fix.yml
└── scripts/
    └── copilot-security/
        └── copilot-security-fix.sh
```

### Commands

```bash
# From your target repo root
mkdir -p .github/agents .github/chainguard .github/skills .github/workflows scripts/copilot-security

# Copy from foundation repo (adjust FOUNDATION_PATH)
FOUNDATION=path/to/aa-engineering-foundation

cp "$FOUNDATION/crosscutting/security/workflows/workflow-security-0005-copilot-security-fix.yml" \
   .github/workflows/

cp "$FOUNDATION/crosscutting/security/scripts/copilot-security/copilot-security-fix.sh" \
   scripts/copilot-security/

cp "$FOUNDATION/crosscutting/security/chainguard/copilot-security-fix.sts.yaml" \
   .github/chainguard/

cp "$FOUNDATION/crosscutting/security/agents/agent-security-0002-github-vulnerability-fixer.md" \
   .github/agents/

cp "$FOUNDATION/crosscutting/security/skills/skill-security-0001-dependency-upgrade-scanner.md" \
   .github/skills/

# Ensure script is executable
chmod +x scripts/copilot-security/copilot-security-fix.sh
```

> **Why the agent and skill?** The workflow creates issues that instruct Copilot to follow `@github-vulnerability-fixer` for fix strategies and to use the `dependency-upgrade-scanner` skill for dependency classification. Without these files in the target repo, Copilot will not have access to the fix constraints and may apply incorrect strategies.

---

## Step 2: Update the STS Trust Policy

Edit `.github/chainguard/copilot-security-fix.sts.yaml` and replace the `subject_pattern` with your repo:

```yaml
subject_pattern: "repo:AAInternal/<YOUR-REPO-NAME>:.*"
```

---

## Step 3: Configure Repository Secrets

Navigate to **Settings → Secrets and variables → Actions** and add:

| Secret | Required | Purpose |
|--------|----------|---------|
| `DEPENDABOT_PAT` | **Yes** | Personal Access Token with `repo` scope. Used for Copilot agent assignment via GraphQL — `GITHUB_TOKEN` and octo-sts tokens cannot discover or assign `copilot-swe-agent`. |

> **Note**: `GITHUB_TOKEN` is provided automatically by Actions and is used for issue creation, label management, and code scanning API access.

### Creating the DEPENDABOT_PAT

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Create a token with:
   - **Repository access**: Only select your target repo
   - **Permissions**: `Issues: Read & Write`, `Contents: Read`, `Metadata: Read`
3. Alternatively, use a classic token with `repo` scope
4. Add it as a repository secret named `DEPENDABOT_PAT`

---

## Step 4: Enable Copilot Coding Agent

1. Go to **Settings → Copilot → Coding agent**
2. **Enable** the Copilot coding agent for the repository
3. Verify `copilot-swe-agent` appears in the assignee dropdown on any issue

> Without this, the workflow will create issues but fail to assign them to Copilot. Issues will include a fallback message: _"Manually click 'Assign to Agent'"_.

---

## Step 5: Enable Dependabot Alerts

1. Go to **Settings → Code security and analysis**
2. Enable **Dependabot alerts**
3. (Optional) Enable **Dependabot security updates** for automatic PRs

---

## Step 6: Request octo-sts Permissions

The octo-sts GitHub App must have **"Dependabot alerts: Read"** permission at the App level.

1. Check if the [octo-sts App](https://github.com/octo-sts/app) is installed on your org
2. If the App does **not** have `vulnerability_alerts:read`, open an issue at: https://github.com/octo-sts/app/issues
3. Request: _"Please add Dependabot alerts: Read permission to the octo-sts App for our organization"_

> If octo-sts cannot fetch alerts, the workflow logs actionable guidance and skips Dependabot processing (Code Scanning still works via `GITHUB_TOKEN`).

---

## Step 7: Run the Workflow

1. Go to **Actions → Copilot Security Fix Automation**
2. Click **Run workflow**
3. Select `fix_type`:
   - `all` — Dependabot + Code Scanning (default)
   - `dependabot` — Dependabot alerts only
   - `code-scanning` — Code Scanning alerts only
4. Click **Run workflow**

### Enabling the Scheduled Run

The cron schedule is commented out by default. To enable daily runs, edit the workflow and uncomment:

```yaml
on:
  schedule:
    - cron: '0 15 * * *'   # Daily at 3 PM UTC (9 AM CST)
```

---

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│  workflow_dispatch (or schedule)                         │
└────────────────────┬────────────────────────────────────┘
                     │
    ┌────────────────▼────────────────────┐
    │  Job 1: assign-to-copilot           │
    │                                     │
    │  1. Checkout scripts/               │
    │  2. Get octo-sts ephemeral token    │
    │  3. Create labels if missing        │
    │  4. Run copilot-security-fix.sh:    │
    │     a. Fetch Dependabot alerts      │
    │     b. Group by parent BOM          │
    │     c. Create umbrella issues (2+)  │
    │     d. Create individual issues     │
    │     e. Fetch Code Scanning alerts   │
    │     f. Create code scanning issue   │
    │     g. Assign all to copilot-swe    │
    └────────────────┬────────────────────┘
                     │
    ┌────────────────▼────────────────────┐
    │  copilot-swe-agent picks up issue   │
    │                                     │
    │  Uses:                              │
    │  • @github-vulnerability-fixer      │
    │    (agent-security-0002)            │
    │  • dependency-upgrade-scanner       │
    │    (skill-security-0001)            │
    │                                     │
    │  → Classifies dependency            │
    │  → Applies fix strategy             │
    │  → Verifies build                   │
    │  → Opens PR                         │
    └────────────────┬────────────────────┘
                     │
    ┌────────────────▼────────────────────┐
    │  Job 2: close-security-issues       │
    │                                     │
    │  1. Wait 2 min for agent pickup     │
    │  2. Close issues assigned to        │
    │     copilot-swe-agent               │
    └─────────────────────────────────────┘
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `⚠️ DEPENDABOT_PAT not set` | Secret missing | Add `DEPENDABOT_PAT` secret (Step 3) |
| `⚠️ copilot-swe-agent not found` | Coding agent not enabled | Enable in Settings → Copilot (Step 4) |
| `⚠️ Dependabot API returned HTTP 403` | octo-sts lacks permission | Request `vulnerability_alerts:read` (Step 6) |
| `⚠️ Dependabot API returned HTTP 404` | Dependabot alerts not enabled | Enable in Settings → Code security (Step 5) |
| Issues created but not assigned | `DEPENDABOT_PAT` lacks scope | Ensure PAT has `repo` scope or fine-grained issue write |
| `❌ Parent upgrade issue creation failed` | `GITHUB_TOKEN` lacks `issues:write` | Already in workflow permissions — check org policy |
| Copilot applies wrong fix strategy | Agent/skill files missing from target repo | Copy agent and skill files to `.github/agents/` and `.github/skills/` (Step 1) |

---

## File Reference

### Workflow → Script → Agent Path Mapping

When deployed, the workflow expects:

```
.github/workflows/workflow-security-0005-copilot-security-fix.yml
  └── runs: scripts/copilot-security/copilot-security-fix.sh
        └── creates issues referencing:
              ├── .github/agents/agent-security-0002-github-vulnerability-fixer.md
              └── .github/skills/skill-security-0001-dependency-upgrade-scanner.md

.github/chainguard/copilot-security-fix.sts.yaml
  └── identity: copilot-security-fix (matched by octo-sts action)
```

### Required Permissions Summary

| Token | Permission | Used For |
|-------|-----------|----------|
| `GITHUB_TOKEN` | `contents:read` | Checkout |
| `GITHUB_TOKEN` | `id-token:write` | octo-sts OIDC exchange |
| `GITHUB_TOKEN` | `security-events:read` | Code Scanning alerts |
| `GITHUB_TOKEN` | `issues:write` | Create/close issues, labels |
| `GITHUB_TOKEN` | `pull-requests:read` | Duplicate PR check |
| octo-sts token | `vulnerability_alerts:read` | Dependabot alerts API |
| `DEPENDABOT_PAT` | `repo` or `issues:write` | Copilot agent GraphQL assignment |
