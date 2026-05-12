---
id: SKILL-devops-0001-github-cli-insight
name: github-cli-insight
title: GitHub CLI Insight
version: 1.0.0
status: active
owner: enterprise-architecture
concern: devops
created: 2026-04-09
lastUpdated: 2026-04-09
description: Provide command-assist guidance for GitHub repositories, pull requests, contributors, and recent code changes using read-only GitHub CLI commands.
trigger_keywords:
  - github
  - gh
  - pull request
  - pr
  - repository insights
  - contributor analysis
  - recent changes
related:
  laws: []
  adoptions: []
  skills: []
  plugins: []
---

# GitHub CLI Insight

## Purpose
Provide command-assist guidance to run GitHub CLI commands quickly and return concise summaries.

## When to Use
- The user asks for repository health, PR hygiene, contribution trends, or recent change summaries.
- The user wants help running the right read-only `gh` commands.

## Workflow
1. Confirm scope (owner/repo, branch, and time window) if missing.
2. Run read-only `gh` commands for PR, commit, and contributor context.
3. Capture key command output fields needed for a useful summary.
4. Return a concise summary with optional next commands.

## Command Guidance
- Prefer read-only commands (`gh pr list`, `gh pr view`, `gh repo view`, `gh api`, `gh search prs`).
- Favor table or JSON output for readability and reuse.
- Include command snippets used in the response.

## Guardrails
- Do not mutate repository state unless explicitly requested.
- Do not over-interpret results when scope is missing.
- Ask for missing repo context before broad summaries.

## Output Expectations
- Brief context summary (scope and time period).
- Command output highlights grouped by PR flow, ownership, and change activity.
- Optional follow-up command suggestions based on what was returned.
