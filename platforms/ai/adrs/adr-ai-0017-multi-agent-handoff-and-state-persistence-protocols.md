---
id: ADR-ai-0017-multi-agent-handoff-and-state-persistence-protocols
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0002-responsible-ai-guardrails
  adoptions:
  - ADOPTION-ai-0017-multi-agent-handoff-and-state-persistence-protocols
  adrs: []
---

# ADR-ai-0017-multi-agent-handoff-and-state-persistence-protocols: Multi-Agent Handoff and State Persistence Protocols

## Context
Complex workflows often require handoffs between specialized agents (e.g., Researcher to Writer). Without a standard, the "Reasoning State" is lost, leading to context decay and hallucinations.
Decision
Standardize the "Context Handoff" protocol:
Agents must package their "Thought History" and "Evidence Set" into a structured schema during a handoff.
The receiving agent must validate the "Summary of Intent" before starting a new loop.
Benefits
Maintains accuracy across multi-step, multi-agent workflows.
Reduces redundant reasoning steps between agents.
Consequences
Increases the token count of the initial prompt for the receiving agent.

## Decision
Standardize the "Context Handoff" protocol:
Agents must package their "Thought History" and "Evidence Set" into a structured schema during a handoff.
The receiving agent must validate the "Summary of Intent" before starting a new loop.
Benefits
Maintains accuracy across multi-step, multi-agent workflows.
Reduces redundant reasoning steps between agents.
Consequences
Increases the token count of the initial prompt for the receiving agent.

## Benefits
Maintains accuracy across multi-step, multi-agent workflows.
Reduces redundant reasoning steps between agents.
Consequences
Increases the token count of the initial prompt for the receiving agent.

## Consequences
Increases the token count of the initial prompt for the receiving agent.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0002-responsible-ai-guardrails
- Adoptions: ADOPTION-ai-0017-multi-agent-handoff-and-state-persistence-protocols

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
