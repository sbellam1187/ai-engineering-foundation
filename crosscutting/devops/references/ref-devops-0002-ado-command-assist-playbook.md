---
id: REF-devops-0002-ado-command-assist-playbook
title: Azure DevOps Command Assist Playbook
version: 1.0.0
status: active
owner: enterprise-architecture
concern: devops
created: 2026-04-09
lastUpdated: 2026-04-09
description: Standard command-assist playbook for running Azure DevOps CLI work-item queries and producing concise, consistent summaries.
related:
  skills:
    - SKILL-devops-0002-ado-cli-insight
---

# Azure DevOps Command Assist Playbook

## Purpose
Standardize how Azure DevOps command output is gathered and summarized for quick operational updates.

## Required Context
- Organization
- Project
- Team
- Time window
- Workflow model observed (iteration-based or continuous flow)

## Command Baseline
```bash
az devops configure -l
az devops team list --organization <org> --project <project> -o table
az boards query --organization <org> --project <project> --wiql "<wiql>" -o table
```

## Output Focus
- Open inventory count
- Closed inventory count in period
- Median work-item age (open items)
- Aged work-item count by threshold
- State-transition frequency
- Assignment concentration ratio

## Summary Checklist
- Each summary must include:
  - command reference
  - returned values
  - short plain-language summary
- Keep summaries scoped to returned command output.

## Failure Handling
1. If CLI errors include SSL or certificate failures, verify network and VPN.
2. If extension errors occur, verify `azure-devops` extension availability.
3. If auth errors occur, verify `az login` and org defaults.
4. If still blocked, report partial analysis with explicit unknowns.

## Output Template
- Scope
- Metric summary table
- Key command output highlights
- Unknowns and data gaps
- Optional recommendations only when requested by user
