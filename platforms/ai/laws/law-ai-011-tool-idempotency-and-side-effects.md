---
id: LAW-ai-0011-tool-idempotency-and-side-effects
concern: ai
status: active
owner: <owner>
created: '2026-02-23'
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-ai-0015-logical-idempotency-and-side-effect-classification
---

# LAW-ai-0011-tool-idempotency-and-side-effects: Side-effecting tools MUST be classified and idempotent

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
All tools MUST be tagged read-only or side-effecting; side-effecting actions MUST use session-based idempotency keys.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
