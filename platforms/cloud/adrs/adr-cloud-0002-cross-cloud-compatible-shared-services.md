---
id: ADR-cloud-0002-cross-cloud-compatible-shared-services
concern: cloud
status: accepted
owner: Enterprise Architecture
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs: []
---

# ADR-cloud-0002-cross-cloud-compatible-shared-services: Favor Cross-Cloud Compatible Platforms and Shared Services

## Context
The strategy standardizes on a primary cloud while retaining a secondary cloud for flexibility, resiliency, and best-of-breed capabilities. Consistent enterprise patterns must work across both providers.

## Decision
Prefer cross-cloud compatible platform components and shared services such as service mesh, CI/CD, observability, and integration abstractions. Use provider-native services only where cross-cloud alternatives do not meet functional or non-functional needs, documenting tradeoffs and using the exception path.

## Considered options
1. Cross-cloud compatible services by default
2. Provider-native services by default
3. Per-team choice without constraints

## Rationale
- Enables consistent patterns and skills across primary and secondary clouds.
- Preserves exit options while leveraging best-of-breed selectively.
- Reduces heterogeneous operational risk.

## Consequences
### Positive
- Increased portability and reduced provider coupling.
- Simplified platform enablement and onboarding.

### Negative
- Exception governance overhead.
- Some teams may face broader design and test considerations.

## Follow-up actions
- Maintain a decision framework and service catalog indicating preferred cross-cloud services and approved native exceptions.
