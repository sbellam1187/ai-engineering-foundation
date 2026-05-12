---
id: LAW-ai-0012-traceability-metadata-required
concern: ai
status: active
owner: <owner>
created: '2026-02-23'
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-ai-0006-serve-and-scale-ml-models-from-the-runtime-platform-with-ci-cd
  - ADR-ai-0010-manage-all-agents-in-a-single-agent-control-plane
  - ADR-ai-0016-standardized-agent-metadata-and-traceability
---

# LAW-ai-0012-traceability-metadata-required: Agent/tool calls MUST be traceable

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
Outbound tool calls MUST include standardized agent metadata to ensure auditing and downstream policy control.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
