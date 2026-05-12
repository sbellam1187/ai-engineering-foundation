---
id: ADR-ai-0015-logical-idempotency-and-side-effect-classification
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0011-tool-idempotency-and-side-effects
  adoptions:
  - ADOPTION-ai-0015-logical-idempotency-and-side-effect-classification
  adrs: []
---

# ADR-ai-0015-logical-idempotency-and-side-effect-classification: Logical Idempotency and Side-Effect Classification

## Context
Agents operate in iterative loops. If an agent fails to parse a result, it may "retry" the thought, potentially leading to duplicate side-effects (e.g., moving money twice) within the same logical session.
Decision
Standardize the Agent-to-Tool interface:
Side-Effect Tagging: Classify all tools as either "Read-Only" or "Side-Effecting."
Logical Idempotency Keys: Require agents to generate and pass unique session-based keys for any side-effecting action.
Benefits
Protects downstream systems from accidental duplicate actions.
Improves the reliability of automated workflows.
Consequences
Requires consistent API conventions for all tool adapters.
Phase 1: Advanced Cognitive Architecture

## Decision
Standardize the Agent-to-Tool interface:
Side-Effect Tagging: Classify all tools as either "Read-Only" or "Side-Effecting."
Logical Idempotency Keys: Require agents to generate and pass unique session-based keys for any side-effecting action.
Benefits
Protects downstream systems from accidental duplicate actions.
Improves the reliability of automated workflows.
Consequences
Requires consistent API conventions for all tool adapters.
Phase 1: Advanced Cognitive Architecture

## Benefits
Protects downstream systems from accidental duplicate actions.
Improves the reliability of automated workflows.
Consequences
Requires consistent API conventions for all tool adapters.
Phase 1: Advanced Cognitive Architecture

## Consequences
Requires consistent API conventions for all tool adapters.
Phase 1: Advanced Cognitive Architecture

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0011-tool-idempotency-and-side-effects
- Adoptions: ADOPTION-ai-0015-logical-idempotency-and-side-effect-classification

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
