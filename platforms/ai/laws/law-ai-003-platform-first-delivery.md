---
id: LAW-ai-0003-platform-first-delivery
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
  - ADR-ai-0003-scale-ai-via-enterprise-platforms-runtime-integration-developer-telemetry
  - ADR-ai-0004-self-service-automation-for-major-ai-patterns-agentic-ml
  - ADR-ai-0005-make-ai-part-of-the-standard-enterprise-architecture-process
  - ADR-ai-0006-serve-and-scale-ml-models-from-the-runtime-platform-with-ci-cd
---

# LAW-ai-0003-platform-first-delivery: AI solutions MUST use enterprise platforms by default

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
AI workloads MUST be delivered through enterprise developer, runtime, integration, and telemetry platforms unless an exception is approved.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
