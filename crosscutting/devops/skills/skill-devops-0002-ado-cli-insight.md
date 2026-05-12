---
id: SKILL-devops-0002-ado-cli-insight
name: ado-cli-insight
title: Azure DevOps CLI Insight
version: 1.0.0
status: active
owner: enterprise-architecture
concern: devops
created: 2026-04-09
lastUpdated: 2026-04-09
description: Provide command-assist guidance for Azure DevOps work-item and flow queries using read-only az devops commands.
trigger_keywords:
  - azure devops
  - ado
  - backlog health
  - sprint flow
  - kanban flow
  - work items
  - delivery evaluation
related:
  laws: []
  adoptions: []
  skills: []
  plugins: []
---

# Azure DevOps CLI Insight

## Purpose
Provide command-assist guidance to run Azure DevOps CLI queries and summarize work-item flow quickly.

## When to Use
- The user asks to inspect backlog status or current work-item flow in Azure DevOps.
- The user wants fast command help for active, blocked, stale, or recently changed items.

## Workflow
1. Confirm organization, project, team, and time window.
2. Collect work-item and team metadata via `az devops` commands.
3. Group command outputs by aging, state changes, blocked items, and open versus closed inventory.
4. Return a concise operational summary and optional next commands.

## Connectivity and Auth Handling
- If commands fail with SSL, certificate, or connectivity errors, verify network/VPN first.
- Confirm CLI and extension state before assuming permissions are missing.
- Retry the same read-only query once connectivity is confirmed.

## Command Guidance
- Prefer read-only commands and WIQL-based queries.
- Use explicit output formatting (`-o table` or `-o json`) for easy review.
- Avoid method-specific assumptions (sprint vs kanban); infer from observed workflow data.

## Guardrails
- Do not create or modify work items unless explicitly requested.
- Do not prescribe one delivery methodology by default.
- Keep summaries scoped to returned command output.

## Output Expectations
- Scope summary (org, project, team, period).
- Key command output highlights by flow, aging, and inventory balance.
- Focused recommendations only when the user explicitly asks for them.
