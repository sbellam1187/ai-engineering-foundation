---
id: ADR-ai-0013-prompt-as-artifact-versioning-and-promotion-lifecycle
concern: ai
status: active
owner: <owner>
created: '2026-02-23'
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0002-responsible-ai-guardrails
  - LAW-ai-0007-prompt-as-artifact
  adoptions:
  - ADOPTION-ai-0013-prompt-as-artifact-versioning-and-promotion-lifecycle
  adrs: []
---

# ADR-ai-0013-prompt-as-artifact-versioning-and-promotion-lifecycle: Prompt-as-Artifact: Versioning and Promotion Lifecycle

## Context
In agentic systems, the prompt is a core logic component. Because LLM outputs are sensitive to minor linguistic changes, a prompt update is functionally equivalent to a code change, yet it follows a different lifecycle.
Decision
Manage agent definitions as versioned configuration artifacts:
Source-Controlled Templates: Decouple prompt logic from binary application code.
Semantic Gating: Require accuracy benchmarks and hallucination checks as a requirement for promoting a prompt version.
Benefits
Enables rapid recovery/rollback from model-driven regressions.
Decouples AI behavior from infrastructure release cycles.
Consequences
Requires a specialized repository for prompt management.

## Decision
Manage agent definitions as versioned configuration artifacts:
Source-Controlled Templates: Decouple prompt logic from binary application code.
Semantic Gating: Require accuracy benchmarks and hallucination checks as a requirement for promoting a prompt version.
Benefits
Enables rapid recovery/rollback from model-driven regressions.
Decouples AI behavior from infrastructure release cycles.
Consequences
Requires a specialized repository for prompt management.

## Benefits
Enables rapid recovery/rollback from model-driven regressions.
Decouples AI behavior from infrastructure release cycles.
Consequences
Requires a specialized repository for prompt management.

## Consequences
Requires a specialized repository for prompt management.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0007-prompt-as-artifact, LAW-ai-0002-responsible-ai-guardrails
- Adoptions: ADOPTION-prompt-as-artifact-versioning-and-promotion-lifecycle-2213

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
