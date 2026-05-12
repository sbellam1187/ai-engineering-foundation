---
id: REF-devops-0003-azure-environment-inventory-patterns
title: Azure Environment Inventory Patterns
version: 1.0.0
status: active
owner: enterprise-architecture
concern: devops
created: 2026-04-09
lastUpdated: 2026-04-09
description: Inventory-first Azure CLI command-assist patterns with stable command sequences, fallback strategies, and output normalization.
related:
  skills:
    - SKILL-devops-0003-azure-cli-insight
---

# Azure Environment Inventory Patterns

## Purpose
Provide stable Azure CLI command patterns for broad environment discovery and consistent summaries.

## Required Context
- Tenant context (if multi-tenant)
- Subscription set in scope
- Optional resource group filters
- Time boundaries for activity-sensitive commands

## Command Baseline

### Account and Subscription Scope
```bash
az --version
az account show
az account list -o table
```

### Resource Group Inventory
```bash
az group list -o table
az group list --query "[].{name:name,location:location,tags:tags}" -o json
```

### Resource Inventory
```bash
az resource list -o table
az resource list --query "[].{name:name,type:type,location:location,resourceGroup:resourceGroup}" -o json
```

### Type-Focused Drilldown
```bash
az resource list --resource-type <provider/type> -o table
az resource show --ids <resource-id>
```

## Output Focus
- subscriptionId
- resourceGroup
- type
- location
- tags
- sku or tier when available

## Summary Checklist
- Describe estate composition directly from command output.
- Keep summary statements short and scope-aware.
- Identify blind spots caused by scope or permissions.

## Failure Handling
- If service-specific commands fail or require dynamic extension installs, continue using `az resource list` and `az resource show`.
- Avoid preview extensions unless user explicitly requests them.
- If auth context is missing, re-authenticate and re-run baseline sequence.
- If insufficient permissions, return partial inventory with explicit constraints.
- If command hangs, reduce query shape and pivot to type-filtered inventory.

## Output Template
- Scope
- Command output highlights
- Unknowns and constraints
- Optional next commands
