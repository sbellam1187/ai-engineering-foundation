---
id: ADOPTION-cloud-0004-finops-tagging-budgets-and-alerts
concern: cloud
status: active
owner: FinOps Team
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs: []
---

# ADOPTION-cloud-004: FinOps tagging, budgets, and alerts enforcement

## Intent
Optimize for efficiency and create cost accountability via mandatory tagging, budgets, and automated alerts.

## Implementation
1. Require a standard tag schema across resources.
2. Auto-provision budgets and alerts aligned to cost ownership.
3. Provide dashboards and anomaly detection to owners.

## Compliance enforcement
- Policy-as-code denies resources missing required tags.
- CI gates validate tag schema and budget linkage before production.
