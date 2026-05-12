---
id: ADR-ai-0001-open-portable-ai-build-ml-and-agents-on-the-enterprise-runtime-platform
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0003-platform-first-delivery
  - LAW-ai-0004-open-portable-default-block-proprietary
  - LAW-ai-0005-multi-provider-compatibility
  adoptions:
  - ADOPTION-ai-0001-open-portable-ai-build-ml-and-agents-on-the-enterprise-runtime-platform
  adrs: []
---

# ADR-ai-0001-open-portable-ai-build-ml-and-agents-on-the-enterprise-runtime-platform: Open & Portable AI—Build ML and Agents on the Enterprise Runtime Platform

## Context
Our AI Technology Strategy commits to Open and Portable AI and to Scaling AI with Platforms, avoiding lock-in while standardizing how we deploy and operate AI. The reference architecture shows an AI-enabled runtime platform hosting agents, ML/LLM endpoints, and enabling services;
Decision
Implement ML models and agentic workloads using open, portable frameworks (e.g., LangGraph/LangChain for orchestration; interoperable protocols like MCP where applicable) and host them on our AI-enabled runtime platform as the default. Provider SDKs may be used behind a portability abstraction (patterns/templates) to preserve exit options.
Benefits
Reduces vendor lock-in through portability patterns and protocol alignment.
Accelerates delivery via standardized runtime hosting, CI/CD, and observability baked into platform templates.
Simplifies governance by concentrating security, cost, and safety controls at the platform layer.
Consequences
Requires upfront investment in platform abstractions/templates and maintenance across evolving provider APIs.
Some managed provider features may not be fully portable; teams must follow patterns to keep exit paths viable.

## Decision
Implement ML models and agentic workloads using open, portable frameworks (e.g., LangGraph/LangChain for orchestration; interoperable protocols like MCP where applicable) and host them on our AI-enabled runtime platform as the default. Provider SDKs may be used behind a portability abstraction (patterns/templates) to preserve exit options.
Benefits
Reduces vendor lock-in through portability patterns and protocol alignment.
Accelerates delivery via standardized runtime hosting, CI/CD, and observability baked into platform templates.
Simplifies governance by concentrating security, cost, and safety controls at the platform layer.
Consequences
Requires upfront investment in platform abstractions/templates and maintenance across evolving provider APIs.
Some managed provider features may not be fully portable; teams must follow patterns to keep exit paths viable.

## Benefits
Reduces vendor lock-in through portability patterns and protocol alignment.
Accelerates delivery via standardized runtime hosting, CI/CD, and observability baked into platform templates.
Simplifies governance by concentrating security, cost, and safety controls at the platform layer.
Consequences
Requires upfront investment in platform abstractions/templates and maintenance across evolving provider APIs.
Some managed provider features may not be fully portable; teams must follow patterns to keep exit paths viable.

## Consequences
Requires upfront investment in platform abstractions/templates and maintenance across evolving provider APIs.
Some managed provider features may not be fully portable; teams must follow patterns to keep exit paths viable.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0003-platform-first-delivery, LAW-ai-0004-open-portable-default-block-proprietary, LAW-ai-0005-multi-provider-compatibility
- Adoptions: ADOPTION-ai-0001-open-portable-ai-build-ml-and-agents-on-the-enterprise-runtime-platform

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
