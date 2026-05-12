---
id: ADOPTION-ai-0001-open-portable-ai-build-ml-and-agents-on-the-enterprise-runtime-platform
concern: ai
status: active
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-ai-0001-open-portable-ai-build-ml-and-agents-on-the-enterprise-runtime-platform
---

# ADOPTION-AI-001: Adoption for Open & Portable AI—Build ML and Agents on the Enterprise Runtime Platform

## Intent
Make the decision in ADR-ai-0001-open-portable-ai-build-ml-and-agents-on-the-enterprise-runtime-platform easy to adopt and hard to bypass.

## Implementation
1. Publish a reference implementation and template aligned to the ADR.
2. Add CI checks that require linkage to the ADR and applicable laws.
3. Add runtime enforcement where applicable (gateway policies, registries, admission controls).

## Compliance enforcement
- CI gates validate required metadata, evaluations, and guardrails.
- Platform policies enforce runtime constraints for production.

## Evidence
- Pipeline logs and telemetry provide compliance evidence.
