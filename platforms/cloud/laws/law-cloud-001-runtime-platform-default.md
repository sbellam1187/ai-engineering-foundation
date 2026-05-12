---
id: LAW-cloud-0001-runtime-platform-default
concern: cloud
status: active
owner: <owner>
created: '2026-02-23'
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs: []
---

# LAW-0101: Default to the enterprise runtime platform for in-house services

## Intent
Ensure workload portability, consistent governance, and standardized operations.

## Law
In-house microservices and components MUST run on the enterprise runtime platform unless an exception is approved.

## Scope
Applies to:
- New in-house microservices and shared components
- Agentic and AI-enabling services hosted by internal teams

Does not apply to:
- SaaS products where the organization is not responsible for runtime hosting

## Exceptions
Exceptions MUST be documented via an ADR or waiver that includes drivers, risks, and compensating controls.

## Acceptance criteria
- The service uses approved runtime templates and platform baselines.
- A waiver or ADR exists for any non-standard runtime hosting in production.
