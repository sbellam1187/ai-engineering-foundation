---
id: SKILL-devops-0003-azure-cli-insight
name: azure-cli-insight
title: Azure CLI Environment Insight
version: 1.0.0
status: active
owner: enterprise-architecture
concern: devops
created: 2026-04-09
lastUpdated: 2026-04-09
description: Provide command-assist guidance for exploring Azure subscriptions, resource groups, and resources using read-only Azure CLI commands.
trigger_keywords:
  - azure
  - az
  - subscription inventory
  - resource group analysis
  - environment discovery
  - cloud configuration
related:
  laws: []
  adoptions: []
  skills: []
  plugins: []
---

# Azure CLI Environment Insight

## Purpose
Provide command-assist guidance to map Azure environment structure and return concise inventory summaries.

## When to Use
- The user asks to explore an Azure environment or understand what exists.
- The user needs subscription, resource group, or service inventory analysis.

## Workflow
1. Confirm subscription scope, tenant context, and optional resource group filters.
2. Start broad with inventory-level queries.
3. Narrow to specific resource types and configurations based on command output.
4. Summarize command output in operational terms and suggest optional next commands.

## Command Guidance
- Prefer read-only `az` commands with stable output formats.
- Start with broad inventory (`az account list`, `az group list`, `az resource list`) before deep dives.
- Favor generic ARM inventory fallbacks when service-specific commands are unstable.

## Stability and Fallback
- If a command hangs or requires dynamic extension installation, switch to generic `az resource` queries.
- Avoid interactive prompts and preview dependencies unless explicitly requested.

## Guardrails
- Do not change resources or policy by default.
- Do not recommend remediations unless the user explicitly asks.
- Keep summaries scoped to command output and declared scope.

## Output Expectations
- Scope summary (subscriptions/resource groups examined).
- Command output highlights grouped by inventory, distribution, and notable configuration signals.
- Explicit unknowns when access or scope is limited.
