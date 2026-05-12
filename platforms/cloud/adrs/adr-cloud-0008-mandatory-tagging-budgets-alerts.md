---
id: ADR-cloud-0008-mandatory-tagging-budgets-alerts
concern: cloud
status: accepted
owner: FinOps Team
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs: []
---

# ADR-cloud-0008-mandatory-tagging-budgets-alerts: Enforce Mandatory Tagging, Budgets, and Alerts

## Context
Cost optimization is a strategic objective. Without standardized tagging and budget controls, cost accountability and forecasting degrade.

## Decision
Require standardized tagging, cost mapping to budgets, and automated alerts for all cloud resources. Integrate cost telemetry into platform dashboards and enforce compliance in provisioning workflows.

## Considered options
1. Enforced tagging and budget controls via policy and CI gates
2. Guidance-only approach and manual reporting
3. Per-team tagging conventions

## Rationale
- Improves cost accountability and forecasting.
- Enables early anomaly detection and waste reduction.
- Provides consistent unit-economics metrics across teams.

## Consequences
### Positive
- Improved cost visibility and reduced waste.

### Negative
- Initial effort to normalize tags across legacy resources.
- Enforcement introduces pipeline and provisioning gates.

## Follow-up actions
- Define the required tag schema and validation rules.
- Provide dashboards and alerting templates.
