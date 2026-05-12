---
id: ADR-cloud-0009-ha-topology-active-active-and-failover
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

# ADR-cloud-0009-ha-topology-active-active-and-failover: HA Topology for Critical Workloads

## Context
Critical and vital workloads require explicit availability and recovery strategies aligned to business RPO and RTO.

## Decision
For critical and vital applications:
- Application layer defaults to active-active across zones and where required across regions.
- Data layer uses active-active replication when supported or automated failover with RPO and RTO aligned to workload criticality.
- Constraints where active-active is infeasible must be documented, with runbooks and test plans.

## Considered options
1. Active-active where feasible plus automated failover for stateful components
2. Active-passive everywhere
3. Single-zone or single-region with manual recovery

## Rationale
- Improves availability and reduces mean time to recovery.
- Creates clear, testable failover pathways aligned to business needs.

## Consequences
### Positive
- Higher availability and predictable recovery.

### Negative
- Increased complexity and cost for replication and quorum design.
- Latency and consistency tradeoffs for stateful services.

## Follow-up actions
- Publish reference architectures by criticality tier.
- Require periodic failover testing and evidence.
