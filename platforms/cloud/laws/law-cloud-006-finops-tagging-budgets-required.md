---
id: LAW-cloud-0006-finops-tagging-budgets-required
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

# LAW-0106: FinOps tagging, budgets, and alerts are mandatory

## Intent
Optimize for efficiency and maintain cost accountability.

## Law
All cloud resources MUST implement standardized tagging, cost allocation, budgets, and automated alerts. Resources failing required tagging and budget policies MUST be blocked from production deployment.

## Scope
Applies to all cloud resources.

## Exceptions
Temporary sandboxes may be pre-defined but must meet minimum tagging and expiry policies.

## Acceptance criteria
- Required tag set is enforced in CI/CD and or admission control.
- Budgets and alert thresholds are configured and visible to owners.
