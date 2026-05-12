---
id: ADR-ai-0016-standardized-agent-metadata-and-traceability
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0012-traceability-metadata-required
  adoptions:
  - ADOPTION-ai-0016-standardized-agent-metadata-and-traceability
  adrs: []
---

# ADR-ai-0016-standardized-agent-metadata-and-traceability: Standardized Agent Metadata and Traceability

## Context
Downstream systems must distinguish between human-initiated traffic and agent-initiated traffic to manage risk. Standard headers do not capture the "Cognitive Origin" of a request.
Decision
Implement a mandatory "Agent-User-Agent" header for all outbound tool calls:
Include Agent ID, Logic Version, and Parent Trace ID.
Ensure every autonomous action is traceable to its specific reasoning source.
Benefits
Enables granular auditing of autonomous actions.
Allows downstream systems to apply AI-specific traffic policies.
Consequences
Adds metadata overhead to every outbound request.

## Decision
Implement a mandatory "Agent-User-Agent" header for all outbound tool calls:
Include Agent ID, Logic Version, and Parent Trace ID.
Ensure every autonomous action is traceable to its specific reasoning source.
Benefits
Enables granular auditing of autonomous actions.
Allows downstream systems to apply AI-specific traffic policies.
Consequences
Adds metadata overhead to every outbound request.

## Benefits
Enables granular auditing of autonomous actions.
Allows downstream systems to apply AI-specific traffic policies.
Consequences
Adds metadata overhead to every outbound request.

## Consequences
Adds metadata overhead to every outbound request.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0012-traceability-metadata-required
- Adoptions: ADOPTION-ai-0016-standardized-agent-metadata-and-traceability

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
