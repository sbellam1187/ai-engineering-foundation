---
id: LAW-ai-0010-cost-protection-token-budgets
concern: ai
status: active
owner: <owner>
created: '2026-02-23'
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-ai-0004-self-service-automation-for-major-ai-patterns-agentic-ml
  - ADR-ai-0014-predictive-token-budgeting-and-recursive-loop-protection
  - ADR-ai-0018-semantic-caching-for-redundant-reasoning-paths
---

# LAW-ai-0010-cost-protection-token-budgets: Agentic workloads MUST enforce token budgets and loop protection

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
Agentic sessions MUST reserve and enforce token budgets and terminate runaway loops to prevent denial-of-wallet scenarios.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
