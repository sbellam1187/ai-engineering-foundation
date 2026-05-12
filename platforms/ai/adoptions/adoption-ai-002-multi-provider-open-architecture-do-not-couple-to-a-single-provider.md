---
id: ADOPTION-ai-0002-multi-provider-open-architecture-do-not-couple-to-a-single-provider
concern: ai
status: active
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-ai-0002-multi-provider-open-architecture-do-not-couple-to-a-single-provider
---

# ADOPTION-AI-002: Adoption for Multi-Provider Open Architecture—Do Not Couple to a Single Provider

## Intent
Make the decision in ADR-ai-0002-multi-provider-open-architecture-do-not-couple-to-a-single-provider easy to adopt and hard to bypass.

## Implementation
1. Publish a reference implementation and template aligned to the ADR.
2. Add CI checks that require linkage to the ADR and applicable laws.
3. Add runtime enforcement where applicable (gateway policies, registries, admission controls).

## Compliance enforcement
- CI gates validate required metadata, evaluations, and guardrails.
- Platform policies enforce runtime constraints for production.

## Evidence
- Pipeline logs and telemetry provide compliance evidence.
