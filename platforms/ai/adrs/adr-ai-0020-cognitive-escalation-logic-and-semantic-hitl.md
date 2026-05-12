---
id: ADR-ai-0020-cognitive-escalation-logic-and-semantic-hitl
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0002-responsible-ai-guardrails
  adoptions:
  - ADOPTION-ai-0020-cognitive-escalation-logic-and-semantic-hitl
  adrs: []
---

# ADR-ai-0020-cognitive-escalation-logic-and-semantic-hitl: Cognitive Escalation Logic and Semantic HITL

## Context
Agents may reach "Dead Ends" or encounter ambiguity they cannot resolve. Without a standard escalation path, agents may attempt to "guess," leading to unsafe outputs.
Decision
Define mandatory Escalation Triggers:
Confidence Thresholds: Trigger Human-in-the-loop (HITL) if confidence falls below a set score.
Ambiguity Traps: Pause and request clarification if a reasoning loop exceeds 5 "thoughts" without resolution.
Benefits
Ensures safety by preventing agents from guessing on ambiguous tasks.
Optimizes human intervention only where the AI is uncertain.
Consequences
Requires a UI/Workflow to manage human interventions mid-loop.
Alignment
Governed via existing Agent Control Plane.

## Decision
Define mandatory Escalation Triggers:
Confidence Thresholds: Trigger Human-in-the-loop (HITL) if confidence falls below a set score.
Ambiguity Traps: Pause and request clarification if a reasoning loop exceeds 5 "thoughts" without resolution.
Benefits
Ensures safety by preventing agents from guessing on ambiguous tasks.
Optimizes human intervention only where the AI is uncertain.
Consequences
Requires a UI/Workflow to manage human interventions mid-loop.
Alignment
Governed via existing Agent Control Plane.

## Benefits
Ensures safety by preventing agents from guessing on ambiguous tasks.
Optimizes human intervention only where the AI is uncertain.
Consequences
Requires a UI/Workflow to manage human interventions mid-loop.
Alignment
Governed via existing Agent Control Plane.

## Consequences
Requires a UI/Workflow to manage human interventions mid-loop.
Alignment
Governed via existing Agent Control Plane.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0002-responsible-ai-guardrails
- Adoptions: ADOPTION-ai-0020-cognitive-escalation-logic-and-semantic-hitl

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
