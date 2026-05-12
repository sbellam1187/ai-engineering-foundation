---
id: LAW-ai-0006-ai-ready-data-products
concern: ai
status: active
owner: <owner>
created: '2026-02-23'
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs:
  - ADR-ai-0008-curated-managed-rag-providers-with-rich-connectors
---

# LAW-ai-0006-ai-ready-data-products: AI inputs MUST come from governed data products

## Intent
Make AI delivery safe, auditable, portable, and scalable.

## Law
Production AI solutions MUST use curated, governed data products with semantic definitions, lineage, and validated APIs.

## Scope
Applies to all production AI solutions and AI artifacts.

## Exceptions
Exceptions MUST be documented in an ADR with compensating controls and an expiry.

## Acceptance criteria
- Automated checks exist in CI/CD or at runtime.
- Evidence of compliance is produced for audit.
