---
id: REF-devops-0001-github-cli-command-baselines
title: GitHub CLI Command Baselines
version: 1.0.0
status: active
owner: enterprise-architecture
concern: devops
created: 2026-04-09
lastUpdated: 2026-04-09
description: Canonical read-only GitHub CLI command baseline and key output fields used by the GitHub CLI command-assist skill.
related:
  skills:
    - SKILL-devops-0001-github-cli-insight
---

# GitHub CLI Command Baselines

## Purpose
Provide a reproducible, read-only command baseline for repository, pull request, and contributor command assist.

## Required Context
- Repository owner and name
- Time window for analysis
- Optional branch focus when comparing change activity

## Command Baseline

### Environment and Auth
```bash
gh --version
gh auth status
```

### Repository Summary
```bash
gh repo view <owner>/<repo>
gh repo view <owner>/<repo> --json name,defaultBranchRef,isPrivate,primaryLanguage,createdAt,pushedAt
```

### Pull Request Flow
```bash
gh pr list --repo <owner>/<repo> --state open --limit 200
gh pr list --repo <owner>/<repo> --state closed --limit 200
gh pr list --repo <owner>/<repo> --search "is:pr updated:>=<yyyy-mm-dd>" --limit 200
```

### PR Detail Sample
```bash
gh pr view <pr-number> --repo <owner>/<repo> --json title,author,createdAt,updatedAt,mergeStateStatus,reviewDecision,commits,additions,deletions
```

### Contributor Signals
```bash
gh api repos/<owner>/<repo>/contributors?per_page=100
gh api repos/<owner>/<repo>/commits?per_page=100
```

## Output Focus
- PR lifecycle: createdAt, updatedAt, state, mergedAt
- Review flow: reviewDecision, requested reviewers, checks state
- Change volume: additions, deletions, commits count
- Ownership: author login, top contributors by commit count

## Summary Checklist
- Use at least one open-state and one closed-state PR query.
- Confirm summary statements with direct command output.
- Explicitly report data limits when API pagination or scope constraints apply.

## Failure Handling
- If not authenticated, re-run after `gh auth login`.
- If repository is private and inaccessible, report scope limitation and stop.
- If rate-limited, reduce query volume and continue with sampled output.

## Output Template
- Scope
- Command output highlights
- Unknowns and constraints
- Optional next commands
