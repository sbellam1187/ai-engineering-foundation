---
id: LAW-cloud-0004-private-networking-by-default
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

# LAW-0104: Private networking by default

## Intent
Reduce attack surface and standardize security controls.

## Law
Cloud services, resources, and component hosting MUST default to private networking unless a public interface is explicitly required and risk-appropriate controls are in place.

## Scope
Applies to internal services, data stores, and platform components.

## Exceptions
Public exposure is allowed only with documented controls including authentication, threat protection, and logging.

## Acceptance criteria
- Private endpoints and segmentation are used where supported.
- Any public endpoint has approved threat protections and authentication controls.
