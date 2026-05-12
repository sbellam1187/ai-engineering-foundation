---
id: LAW-ai-0004-open-portable-default-block-proprietary
concern: ai
status: active
owner: <owner>
created: '2026-02-23'
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-ai-0001-open-portable-ai-build-ml-and-agents-on-the-enterprise-runtime-platform
  - ADR-ai-0002-multi-provider-open-architecture-do-not-couple-to-a-single-provider
---

# LAW-ai-0004-open-portable-default-block-proprietary: Non-essential proprietary AI tech MUST be default-blocked

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
Proprietary AI frameworks, APIs, and managed features that create hard lock-in MUST be blocked by default unless explicitly approved with an exit strategy.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
