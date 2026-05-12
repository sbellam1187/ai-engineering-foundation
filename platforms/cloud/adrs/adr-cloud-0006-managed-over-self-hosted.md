---
id: ADR-cloud-0006-managed-over-self-hosted
concern: cloud
status: accepted
owner: Cloud Governance Team
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs: []
---

# ADR-cloud-0006-managed-over-self-hosted: Prioritize Managed Service Versions; Self-Hosted Requires Strong Justification

## Context
Self-hosting databases, messaging, search, and observability increases operational toil and broadens security and compliance responsibilities.

## Decision
Favor managed offerings for common platform capabilities. Self-host only when required for functionality, performance, compliance, or cost justifications and with governance approval and hardened baselines.

## Considered options
1. Managed services first with a controlled exception process
2. Self-host by default for maximum control
3. Per-team choice without guardrails

## Rationale
- Reduces total cost and improves incident response through mature managed SLAs and tooling.
- Improves consistency of security and compliance posture.
- Aligns with standardized platform templates and automation.

## Consequences
### Positive
- Reduced operations burden and improved reliability.

### Negative
- Vendor roadmap dependencies.
- Exception governance and alignment requirements for self-hosted stacks.

## Follow-up actions
- Define baseline requirements for self-hosted exceptions.
- Maintain approved managed service standards and onboarding templates.
