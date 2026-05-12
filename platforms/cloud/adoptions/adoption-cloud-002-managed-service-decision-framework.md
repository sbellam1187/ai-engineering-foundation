---
id: ADOPTION-cloud-0002-managed-service-decision-framework
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

# ADOPTION-cloud-002: Managed-service-first decision framework

## Intent
Reduce VM and self-hosted sprawl by making managed services the default and exceptions explicit and auditable.

## Implementation
1. Publish approved managed service options per capability.
2. Provide an exception template capturing requirement gaps, TCO, risks, and compensating controls.
3. Define mandatory baselines for any approved VM or self-hosted usage.

## Compliance enforcement
- Policy-as-code blocks VM provisioning in production unless exception metadata is present.
- CI gates require linkage to the approved ADR or waiver for exceptions.
