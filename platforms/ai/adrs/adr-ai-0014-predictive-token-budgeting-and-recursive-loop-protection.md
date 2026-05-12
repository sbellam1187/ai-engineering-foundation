---
id: ADR-ai-0014-predictive-token-budgeting-and-recursive-loop-protection
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0010-cost-protection-token-budgets
  adoptions:
  - ADOPTION-ai-0014-predictive-token-budgeting-and-recursive-loop-protection
  adrs: []
---

# ADR-ai-0014-predictive-token-budgeting-and-recursive-loop-protection: Predictive Token Budgeting and Recursive Loop Protection

## Context
Agentic workflows often involve recursive "thought loops." These loops consume tokens at a non-linear rate. Traditional request-based rate limiting cannot detect or stop a single request that enters an expensive, recursive consumption loop.
Decision
Implement a token-aware budget reservation system:
Provisional Reservation: Reserve a token budget at the start of a reasoning turn based on max_tokens settings.
Loop Termination: Automatically terminate any agentic session that exceeds its reserved credits before the next turn begins.
Benefits
Protects against "Denial of Wallet" scenarios caused by runaway recursion.
Standardizes cost-per-reasoning-step metrics.
Consequences
May interrupt complex reasoning tasks if the budget is set too low.

## Decision
Implement a token-aware budget reservation system:
Provisional Reservation: Reserve a token budget at the start of a reasoning turn based on max_tokens settings.
Loop Termination: Automatically terminate any agentic session that exceeds its reserved credits before the next turn begins.
Benefits
Protects against "Denial of Wallet" scenarios caused by runaway recursion.
Standardizes cost-per-reasoning-step metrics.
Consequences
May interrupt complex reasoning tasks if the budget is set too low.

## Benefits
Protects against "Denial of Wallet" scenarios caused by runaway recursion.
Standardizes cost-per-reasoning-step metrics.
Consequences
May interrupt complex reasoning tasks if the budget is set too low.

## Consequences
May interrupt complex reasoning tasks if the budget is set too low.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0010-cost-protection-token-budgets
- Adoptions: ADOPTION-ai-0014-predictive-token-budgeting-and-recursive-loop-protection

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
