---
id: LAW-cloud-0005-multi-az-default-multi-region-by-criticality
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

# LAW-0105: Multi-AZ is the default; multi-region is required by criticality

## Intent
Design for failure and rapid recovery.

## Law
All production workloads MUST be deployed across multiple availability zones where supported. Critical or vital workloads MUST implement a multi-region strategy aligned to business RPO and RTO.

## Scope
Applies to production workloads deployed in cloud.

## Exceptions
Allowed only when the service or region does not support the required topology; compensating controls and an improvement plan are required.

## Acceptance criteria
- Evidence of zone redundancy exists for production.
- For vital workloads: documented DR plan, tested failover, and explicit RPO/RTO targets.
