---
id: ADR-ai-0003-scale-ai-via-enterprise-platforms-runtime-integration-developer-telemetry
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0003-platform-first-delivery
  adoptions:
  - ADOPTION-ai-0003-scale-ai-via-enterprise-platforms-runtime-integration-developer-telemetry
  adrs: []
---

# ADR-ai-0003-scale-ai-via-enterprise-platforms-runtime-integration-developer-telemetry: Scale AI via Enterprise Platforms (Runtime, Integration, Developer, Telemetry)

## Context
The strategy emphasizes Scale AI with Platforms. The AA AI Reference Architecture and SDLC slides show standardized patterns across developer, runtime, integration, and telemetry—plus cost/safety controls integrated throughout.
Decision
Deliver and scale AI solutions exclusively through enterprise platforms:
Developer: code/pipeline templates and generation.
Runtime: hosting for agents/models.
Integration: API/MCP tooling via gateways/catalogs.
Telemetry: synthetic monitoring, model/agent observability.
Major patterns must be templatized for reuse.
Benefits
Predictable delivery velocity from repeatable patterns and automation.
Consistent governance (security, privacy, safety, cost) embedded into the SDLC.
Consequences
Requires platform maturity and backlog prioritization to keep templates current.
Non-platform solutions face higher review overhead, approval gates, and are discouraged.

## Decision
Deliver and scale AI solutions exclusively through enterprise platforms:
Developer: code/pipeline templates and generation.
Runtime: hosting for agents/models.
Integration: API/MCP tooling via gateways/catalogs.
Telemetry: synthetic monitoring, model/agent observability.
Major patterns must be templatized for reuse.
Benefits
Predictable delivery velocity from repeatable patterns and automation.
Consistent governance (security, privacy, safety, cost) embedded into the SDLC.
Consequences
Requires platform maturity and backlog prioritization to keep templates current.
Non-platform solutions face higher review overhead, approval gates, and are discouraged.

## Benefits
Predictable delivery velocity from repeatable patterns and automation.
Consistent governance (security, privacy, safety, cost) embedded into the SDLC.
Consequences
Requires platform maturity and backlog prioritization to keep templates current.
Non-platform solutions face higher review overhead, approval gates, and are discouraged.

## Consequences
Requires platform maturity and backlog prioritization to keep templates current.
Non-platform solutions face higher review overhead, approval gates, and are discouraged.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0003-platform-first-delivery
- Adoptions: ADOPTION-ai-0003-scale-ai-via-enterprise-platforms-runtime-integration-developer-telemetry

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
