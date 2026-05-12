---
id: LAW-ai-0005-multi-provider-compatibility
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
  - ADR-ai-0008-curated-managed-rag-providers-with-rich-connectors
  - ADR-ai-0012-cognitive-model-alignment-and-dynamic-routing-policy
---

# LAW-ai-0005-multi-provider-compatibility: AI patterns MUST support multi-provider routing

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
AI model access and enabling services MUST support provider interchange and routing based on policy.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
