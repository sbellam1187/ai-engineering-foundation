---
id: ADR-cloud-0007-enforce-cloud-config-and-policies
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

# ADR-cloud-0007-enforce-cloud-config-and-policies: Enforce Enterprise Cloud Configuration and Policies Across All Resources

## Context
A robust governance framework is required to manage security, compliance, and operational risk across all cloud resources.

## Decision
Implement mandatory policy controls across all cloud resources, enforced via policy-as-code, continuous audit, and automated remediation. Policies include security baselines, encryption, identity, network controls, data protection, backups, and tagging.

## Considered options
1. Mandatory enforcement via policy-as-code and continuous remediation
2. Periodic manual reviews and best-effort compliance
3. Decentralized policies per team

## Rationale
- Creates a uniform, auditable compliance posture.
- Reduces drift and accelerates remediation.
- Scales governance without relying on manual reviews.

## Consequences
### Positive
- Consistent controls and faster remediation.

### Negative
- Policy maintenance burden and exception handling overhead.
- Requires clear sandbox patterns for experimentation.

## Follow-up actions
- Publish policy bundles mapped to laws.
- Implement exception tagging, expiry, and reporting.
