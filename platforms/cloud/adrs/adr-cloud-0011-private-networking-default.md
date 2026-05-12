---
id: ADR-cloud-0011-private-networking-default
concern: cloud
status: accepted
owner: Cloud Security
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs: []
---

# ADR-cloud-0011-private-networking-default: Private Networking by Default

## Context
Private networking reduces exposure and supports consistent identity and traffic policy enforcement.

## Decision
Default cloud services, resources, and component hosting to private network topologies unless a public interface is explicitly required and approved with controls.

## Considered options
1. Private by default with controlled public exposure
2. Public endpoints by default with best-effort controls
3. Mixed per-team networking approaches

## Rationale
- Reduces attack surface.
- Simplifies compliance and consistent governance.

## Consequences
### Positive
- Stronger security posture.

### Negative
- Additional provisioning overhead for private endpoints and routing.

## Follow-up actions
- Publish standard patterns for controlled public exposure.
- Enforce private endpoint requirements in templates and policy.
