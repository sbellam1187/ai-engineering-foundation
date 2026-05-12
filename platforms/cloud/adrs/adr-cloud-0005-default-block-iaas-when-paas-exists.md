---
id: ADR-cloud-0005-default-block-iaas-when-paas-exists
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

# ADR-cloud-0005-default-block-iaas-when-paas-exists: Default-Block VM and IaaS When a Managed Equivalent Exists

## Context
Managed services reduce operational burden and accelerate delivery. Unconstrained VM usage increases patching, vulnerability, and operations workload.

## Decision
Default to blocking VM and IaaS hosting where a managed equivalent meets requirements. Allow exceptions when VM and IaaS are justified with documented rationale and guardrails.

## Considered options
1. Block VM and IaaS by default with an exception path
2. Allow VM and IaaS by default with guidance
3. Mandate VM and IaaS for standardization

## Rationale
- Lowers operational overhead and reduces maintenance burdens.
- Improves reliability and security posture through managed capabilities.
- Aligns with platform engineering and automation objectives.

## Consequences
### Positive
- Reduced sprawl and fewer unmanaged server fleets.
- Clear and auditable decisions for exceptional cases.

### Negative
- Exceptional cases introduce additional security and monitoring overhead.
- Some workloads may require re-platforming as managed services mature.

## Follow-up actions
- Publish a managed service catalog with approved options.
- Provide a waiver template and IaaS baseline requirements.
