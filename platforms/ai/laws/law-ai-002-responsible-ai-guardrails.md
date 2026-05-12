---
id: LAW-ai-0002-responsible-ai-guardrails
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
  - ADR-ai-0007-use-vendor-specific-tools-for-low-code-no-code-ai
  - ADR-ai-0008-curated-managed-rag-providers-with-rich-connectors
  - ADR-ai-0011-semantic-boundary-enforcement-and-action-group-scoping
  - ADR-ai-0013-prompt-as-artifact-versioning-and-promotion-lifecycle
  - ADR-ai-0017-multi-agent-handoff-and-state-persistence-protocols
  - ADR-ai-0019-semantic-verification-loops-and-hallucination-checks
  - ADR-ai-0020-cognitive-escalation-logic-and-semantic-hitl
---

# LAW-ai-0002-responsible-ai-guardrails: Responsible AI guardrails MUST be implemented

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
AI solutions MUST implement safety controls, testing, monitoring, and human oversight appropriate to risk.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
