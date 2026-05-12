---
id: LAW-cloud-0003-default-block-nonessential-proprietary-services
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

# LAW-0103: Non-essential proprietary services are default-blocked

## Intent
Minimize lock-in and preserve portability.

## Law
Non-open or proprietary cloud services that are not essential to meet functional or non-functional requirements MUST be default-blocked via policy. Exceptions require documented tradeoffs and approval.

## Scope
Applies to new provisioning of services classified as non-open or proprietary.

## Exceptions
Exceptions MUST include tradeoff analysis and an exit strategy such as abstraction or adapters where feasible.

## Acceptance criteria
- Policy-as-code denies disallowed services by default.
- Exceptions are time-bounded, traceable, and reviewed.
