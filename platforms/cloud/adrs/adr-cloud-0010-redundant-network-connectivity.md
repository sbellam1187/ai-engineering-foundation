---
id: ADR-cloud-0010-redundant-network-connectivity
concern: cloud
status: accepted
owner: Network Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs: []
---

# ADR-cloud-0010-redundant-network-connectivity: High-Speed, Redundant Network Connectivity

## Context
Multi-cloud and hybrid integration depend on reliable connectivity and consistent policy enforcement across network boundaries.

## Decision
Deploy redundant, high-bandwidth interconnects between primary cloud, secondary cloud, and on-prem environments. Standardize routing, segmentation, encryption, and observability across links.

## Considered options
1. Redundant dedicated connectivity with standardized controls
2. Best-effort internet VPN connectivity
3. Per-team networking patterns

## Rationale
- Reduces network single points of failure.
- Provides predictable performance for cross-cloud and hybrid integration.

## Consequences
### Positive
- Improved resiliency and stable latency.

### Negative
- Higher network spend and increased operational complexity.

## Follow-up actions
- Define reference connectivity architectures and monitoring requirements.
- Implement standardized traffic engineering and failure drills.
