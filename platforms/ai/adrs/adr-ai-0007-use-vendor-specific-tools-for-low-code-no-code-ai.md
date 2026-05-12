---
id: ADR-ai-0007-use-vendor-specific-tools-for-low-code-no-code-ai
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0001-govern-all-ai-artifacts
  - LAW-ai-0002-responsible-ai-guardrails
  adoptions:
  - ADOPTION-ai-0007-use-vendor-specific-tools-for-low-code-no-code-ai
  adrs: []
---

# ADR-ai-0007-use-vendor-specific-tools-for-low-code-no-code-ai: Use Vendor-Specific Tools for Low-Code/No-Code AI

## Context
Principles endorse a Pragmatic Build vs. Buy Philosophy: buy commodity AI services and build only where it differentiates us. Low-code/no-code AI tooling falls into commodity categories where self-building lacks strategic ROI at our scale.
Decision
Adopt vendor-specific low-code/no-code AI tools (and managed GenAI features) for rapid delivery of standard capabilities. Focus internal engineering on differentiated agentic orchestration, data semantics, enterprise integration, and platform automation.
Benefits
Accelerates time-to-value and reduces TCO by leveraging mature vendor capabilities.
Keeps engineering capacity focused on strategic differentiators (patterns, platform, airline enterprise grade AI).
Consequences
Increased dependency on vendor roadmaps for low-code/no-code AI; mitigate through abstractions and multi-provider stance.
Requires governance to ensure compliant usage and cost controls across citizen-developer solutions.

## Decision
Adopt vendor-specific low-code/no-code AI tools (and managed GenAI features) for rapid delivery of standard capabilities. Focus internal engineering on differentiated agentic orchestration, data semantics, enterprise integration, and platform automation.
Benefits
Accelerates time-to-value and reduces TCO by leveraging mature vendor capabilities.
Keeps engineering capacity focused on strategic differentiators (patterns, platform, airline enterprise grade AI).
Consequences
Increased dependency on vendor roadmaps for low-code/no-code AI; mitigate through abstractions and multi-provider stance.
Requires governance to ensure compliant usage and cost controls across citizen-developer solutions.

## Benefits
Accelerates time-to-value and reduces TCO by leveraging mature vendor capabilities.
Keeps engineering capacity focused on strategic differentiators (patterns, platform, airline enterprise grade AI).
Consequences
Increased dependency on vendor roadmaps for low-code/no-code AI; mitigate through abstractions and multi-provider stance.
Requires governance to ensure compliant usage and cost controls across citizen-developer solutions.

## Consequences
Increased dependency on vendor roadmaps for low-code/no-code AI; mitigate through abstractions and multi-provider stance.
Requires governance to ensure compliant usage and cost controls across citizen-developer solutions.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0001-govern-all-ai-artifacts, LAW-ai-0002-responsible-ai-guardrails
- Adoptions: ADOPTION-ai-0007-use-vendor-specific-tools-for-low-code-no-code-ai

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
