---
id: ADR-cloud-0001-enterprise-runtime-platform-default
concern: cloud
status: accepted
owner: Enterprise Architecture
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions:
  - ADOPTION-cloud-0001-runtime-templates-and-guardrails
  adrs: []
---

# ADR-cloud-0001-enterprise-runtime-platform-default: Default to the Enterprise Runtime Platform

## Context
The cloud strategy prioritizes platform engineering, cloud-native design, and Kubernetes and OCI container standards to enable portability across primary and secondary clouds.

## Decision
Adopt the Enterprise Runtime Platform as the default hosting surface for in-house microservices and components. Build services to be portable across primary and secondary clouds by adhering to standard runtime abstractions, platform templates, and avoiding provider-specific coupling unless explicitly approved.

## Considered options
1. Enterprise Runtime Platform (Kubernetes plus platform services)
2. Provider-specific PaaS as the default hosting surface
3. VM/IaaS hosting as the default

## Rationale
- Provides consistent deployment, operations, and governance across clouds.
- Reduces lock-in through runtime portability and platform abstractions.
- Accelerates delivery through standardized pipelines, observability, and guardrails.

## Consequences
### Positive
- Faster onboarding and consistent compliance across teams.
- Reduced operational variance across providers.

### Negative
- Some native features may be constrained to preserve portability.
- Exceptions require governance approval and ongoing review.

## Follow-up actions
- Publish and maintain runtime golden-path templates.
- Implement CI checks to enforce runtime default and exception tagging.
