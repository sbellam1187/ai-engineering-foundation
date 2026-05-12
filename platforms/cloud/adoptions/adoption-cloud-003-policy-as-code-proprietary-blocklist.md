---
id: ADOPTION-cloud-0003-policy-as-code-proprietary-blocklist
concern: cloud
status: active
owner: Cloud Governance Team
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs: []
---

# ADOPTION-cloud-003: Policy-as-code proprietary service blocklist

## Intent
Prevent accidental lock-in by making portability guardrails enforceable.

## Implementation
1. Maintain a governed classification list of open-aligned versus proprietary services.
2. Enforce default deny for non-essential proprietary services in production.
3. Require exception metadata including expiry and exit strategy.

## Compliance enforcement
- CI and admission controls deny deployments using blocked services without approved exception metadata.
- Periodic reporting of exceptions and expiries to governance owners.
