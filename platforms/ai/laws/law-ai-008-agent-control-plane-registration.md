---
id: LAW-ai-0008-agent-control-plane-registration
concern: ai
status: active
owner: <owner>
created: '2026-02-23'
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-ai-0010-manage-all-agents-in-a-single-agent-control-plane
---

# LAW-ai-0008-agent-control-plane-registration: All agents MUST be registered in the agent control plane

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
All agents MUST be registered with centralized lifecycle, permissions, and compliance enforcement.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
