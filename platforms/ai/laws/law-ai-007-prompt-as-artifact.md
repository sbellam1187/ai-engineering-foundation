---
id: LAW-ai-0007-prompt-as-artifact
concern: ai
status: active
owner: <owner>
created: '2026-02-23'
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-ai-0013-prompt-as-artifact-versioning-and-promotion-lifecycle
---

# LAW-ai-0007-prompt-as-artifact: Prompts and agent definitions MUST be versioned and promoted like code

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
Prompts and agent configurations MUST be source-controlled, versioned, tested, and promoted with evaluation gates and rollback capability.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
