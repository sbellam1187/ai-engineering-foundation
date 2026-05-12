---
id: LAW-cloud-0002-managed-first-block-iaas-by-default
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

# LAW-0102: Prefer managed services; VM/IaaS requires exception

## Intent
Reduce operational burden and improve reliability by defaulting to managed offerings.

## Law
VM/IaaS hosting MUST NOT be used when a managed equivalent meets functional and non-functional requirements. VM/IaaS usage requires an approved exception.

## Scope
Applies to all production compute hosting choices.

## Exceptions
Allowed only when justified by performance constraints, specialized runtime needs, licensing constraints, compliance requirements, or total cost analysis.

## Acceptance criteria
- An approved ADR or waiver exists for any VM/IaaS usage.
- Operational baselines for patching, vulnerability management, backups, logging, and monitoring are defined.
