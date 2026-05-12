---
id: LAW-ai-0009-semantic-boundaries-and-action-scoping
concern: ai
status: active
owner: <owner>
created: '2026-02-23'
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-ai-0011-semantic-boundary-enforcement-and-action-group-scoping
---

# LAW-ai-0009-semantic-boundaries-and-action-scoping: Agents MUST enforce semantic boundaries and scoped actions

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
Agents MUST be bound to capability manifests and enforce semantic intent validation before side-effecting actions.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
