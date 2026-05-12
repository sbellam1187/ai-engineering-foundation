---
id: ADOPTION-cloud-0001-runtime-templates-and-guardrails
concern: cloud
status: active
owner: Platform Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-cloud-0001-enterprise-runtime-platform-default
---

# ADOPTION-cloud-001: Runtime templates and guardrails

## Intent
Make the enterprise runtime platform the default and easiest path for service delivery.

## Implementation
1. Provide approved infrastructure and service templates.
2. Embed security, networking, tagging, and observability baselines.
3. Offer golden paths for common service patterns.

## Compliance enforcement
- CI checks require reference to ADR-cloud-0001-enterprise-runtime-platform-default and LAW-0101.
- Policy enforcement blocks non-standard runtimes in production unless approved.

## Evidence
- Multiple services onboarded using standardized templates.
