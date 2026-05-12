---
id: ADR-cloud-0012-centralized-cloud-provider-governance
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

# ADR-cloud-0012-centralized-cloud-provider-governance: Centralized Governance of Cloud Providers

## Context
The cloud footprint is fragmented across business units and teams. Some providers are managed in silos. This decentralized model creates security vulnerabilities through inconsistent identity and baseline enforcement, operational risk due to lack of unified audit trails, and unnecessary distribution of administrative work to product teams.

## Decision
All cloud providers will be centrally managed by the Cloud Governance Team. Management of all cloud environments, including IBM Cloud and OCI, will move under a central governance framework that includes centralized billing, a common administration model, and mandatory guardrails.

### Centralized Billing
All accounts must be owned under one central organization.

### Common Administration
Top-level access administration will be centrally handled, delegating to approved vertical administrators for day-to-day functions.

### Mandatory Guardrails
Uniform application of security, tagging, technology standards, and networking policies.

## Decision Drivers
- Reduce enterprise security exposure.
- Improve auditability and compliance reporting.
- Increase cost visibility and FinOps consistency.
- Align cloud usage with enterprise architecture standards.
- Keep product teams focused on delivery outcomes.

## Considered options
1. Fully decentralized provider management
2. Partial central oversight with optional adoption
3. Centralized governance with delegated operations

## Rationale
Centralized governance provides consistent identity, policy enforcement, cost controls, and auditability across providers. Delegated operations preserves necessary day-to-day execution flexibility while preventing drift from enterprise guardrails.

## Consequences
### Positive
- Enhanced security through global visibility and automated policy enforcement.
- Cost efficiency via consolidated FinOps and billing.
- Strategic alignment to architectural standards.
- Streamlined auditing via a single governance interface.

### Negative
- Administrative migrations required to integrate existing IBM and OCI accounts under central standards.
- Reduced local autonomy for teams that previously administered provider accounts independently.

## Follow-up actions
- Define onboarding runbooks to transition existing provider accounts.
- Implement centralized identity, tagging, and policy baselines across all providers.
