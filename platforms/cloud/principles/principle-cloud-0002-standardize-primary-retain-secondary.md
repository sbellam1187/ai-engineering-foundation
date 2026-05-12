---
id: principle-cloud-0002-standardize-primary-retain-secondary
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

# principle-standardize-primary-retain-secondary-0101: Standardize on a primary cloud; retain a secondary

## Statement
The organization SHOULD standardize on one primary cloud provider for most workloads while retaining a single secondary provider for strategic flexibility, redundancy, and selective best-of-breed capabilities.

## Implications
- Default workload placement targets the primary cloud unless the secondary is explicitly justified (latency, best-of-breed capability, disaster recovery).
- Portability is enabled through runtime and platform abstractions and open standards.

## Measures of success
- Reduced toolchain and provider sprawl.
- Demonstrable portability patterns across providers for targeted workloads.
