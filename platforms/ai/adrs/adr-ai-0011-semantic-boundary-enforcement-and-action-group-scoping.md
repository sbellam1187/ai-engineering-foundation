---
id: ADR-ai-0011-semantic-boundary-enforcement-and-action-group-scoping
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0002-responsible-ai-guardrails
  - LAW-ai-0009-semantic-boundaries-and-action-scoping
  adoptions:
  - ADOPTION-ai-0011-semantic-boundary-enforcement-and-action-group-scoping
  adrs: []
---

# ADR-ai-0011-semantic-boundary-enforcement-and-action-group-scoping: Semantic Boundary Enforcement and Action Group Scoping

## Context
Agentic systems utilize LLMs to generate tool-calls based on non-deterministic reasoning. Unlike traditional software, an agent can theoretically attempt any action it "reasons" is necessary. This requires a boundary based on semantic intent rather than just network access.
Decision
Enforce execution boundaries through:
Scoped Action Groups: Bind every agent to a "Capability Manifest" that restricts tool-calls to specific functional domains.
Semantic Interceptors: Use model-based validation to inspect the "intent" of a reasoning turn before it triggers a downstream system side-effect.
Benefits
Prevents agents from "reasoning" their way into unauthorized domains.
Limits the blast radius of prompt-injection attacks.
Consequences
Requires a specialized registry to manage agent personas and tool manifests.
Alignment
Governed via existing Agent Control Plane.

## Decision
Enforce execution boundaries through:
Scoped Action Groups: Bind every agent to a "Capability Manifest" that restricts tool-calls to specific functional domains.
Semantic Interceptors: Use model-based validation to inspect the "intent" of a reasoning turn before it triggers a downstream system side-effect.
Benefits
Prevents agents from "reasoning" their way into unauthorized domains.
Limits the blast radius of prompt-injection attacks.
Consequences
Requires a specialized registry to manage agent personas and tool manifests.
Alignment
Governed via existing Agent Control Plane.

## Benefits
Prevents agents from "reasoning" their way into unauthorized domains.
Limits the blast radius of prompt-injection attacks.
Consequences
Requires a specialized registry to manage agent personas and tool manifests.
Alignment
Governed via existing Agent Control Plane.

## Consequences
Requires a specialized registry to manage agent personas and tool manifests.
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
- Laws: LAW-ai-0009-semantic-boundaries-and-action-scoping, LAW-ai-0002-responsible-ai-guardrails
- Adoptions: ADOPTION-ai-0011-semantic-boundary-enforcement-and-action-group-scoping

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
