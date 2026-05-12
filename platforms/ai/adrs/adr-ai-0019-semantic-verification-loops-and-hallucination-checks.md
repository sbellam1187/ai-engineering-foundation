---
id: ADR-ai-0019-semantic-verification-loops-and-hallucination-checks
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0002-responsible-ai-guardrails
  adoptions:
  - ADOPTION-ai-0019-semantic-verification-loops-and-hallucination-checks
  adrs: []
---

# ADR-ai-0019-semantic-verification-loops-and-hallucination-checks: Semantic Verification Loops and Hallucination Checks

## Context
LLMs are prone to "Confident Hallucinations." A single-pass reasoning chain is often insufficient for production-grade reliability in high-ASL tasks.
Decision
Require a "Reflection/Critique" pattern for high-risk tasks:
An "Actor" agent generates a draft; a "Verifier" agent checks the draft against source documents.
Outputs are only delivered if the facts are grounded in the provided evidence set.
Benefits
Drastically reduces factual errors and hallucinations.
Builds enterprise trust in automated responses.
Consequences
Increases total token consumption and latency per request.

## Decision
Require a "Reflection/Critique" pattern for high-risk tasks:
An "Actor" agent generates a draft; a "Verifier" agent checks the draft against source documents.
Outputs are only delivered if the facts are grounded in the provided evidence set.
Benefits
Drastically reduces factual errors and hallucinations.
Builds enterprise trust in automated responses.
Consequences
Increases total token consumption and latency per request.

## Benefits
Drastically reduces factual errors and hallucinations.
Builds enterprise trust in automated responses.
Consequences
Increases total token consumption and latency per request.

## Consequences
Increases total token consumption and latency per request.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0002-responsible-ai-guardrails
- Adoptions: ADOPTION-ai-0019-semantic-verification-loops-and-hallucination-checks

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
