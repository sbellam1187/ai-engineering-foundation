---
id: LAW-ai-0001-govern-all-ai-artifacts
concern: ai
status: active
owner: <owner>
created: '2026-02-23'
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-ai-0005-make-ai-part-of-the-standard-enterprise-architecture-process
  - ADR-ai-0007-use-vendor-specific-tools-for-low-code-no-code-ai
  - ADR-ai-0009-authentication-federation-for-apis-apps-and-agents
---

# LAW-ai-0001-govern-all-ai-artifacts: All AI artifacts MUST be governed via the enterprise process

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
AI models, prompts, agents, datasets, evaluations, and AI services MUST follow the enterprise governance process and cybersecurity policy.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
