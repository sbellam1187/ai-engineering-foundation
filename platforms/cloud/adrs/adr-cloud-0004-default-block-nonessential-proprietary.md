---
id: ADR-cloud-0004-default-block-nonessential-proprietary
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

# ADR-cloud-0004-default-block-nonessential-proprietary: Default-Block Non-Essential Proprietary Cloud Services

## Context
Portability and interoperability are strategic objectives. Some provider services create hard coupling and reduce the ability to shift workloads.

## Decision
Implement policy-based default-blocking of non-open or proprietary services where such services are not essential to meet functional or non-functional requirements. Require a documented tradeoff analysis and exception approval when proprietary features are necessary.

## Considered options
1. Default-blocking with an explicit exception process
2. Allow proprietary services by default with guidance
3. Per-team choice without governance controls

## Rationale
- Minimizes lock-in and preserves portability.
- Simplifies multi-cloud operations and reduces heterogeneous risk.
- Forces deliberate selection when coupling is justified.

## Consequences
### Positive
- Reduced accidental lock-in.
- Clearer service selection and governance posture.

### Negative
- Potentially slower adoption of proprietary features.
- Requires a maintained classification and exception workflow.

## Follow-up actions
- Maintain a catalog of services classified as open-aligned versus proprietary.
- Implement enforcement policies and exception metadata requirements.
