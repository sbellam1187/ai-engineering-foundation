---
id: ADR-ai-0010-manage-all-agents-in-a-single-agent-control-plane
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0008-agent-control-plane-registration
  - LAW-ai-0012-traceability-metadata-required
  adoptions:
  - ADOPTION-ai-0010-manage-all-agents-in-a-single-agent-control-plane
  adrs: []
---

# ADR-ai-0010-manage-all-agents-in-a-single-agent-control-plane: Manage all agents in a single Agent Control Plane

## Context
As the adoption of AI agents accelerates across both low-code/no-code platforms (e.g., Copilot Studio) and enterprise-grade AI platform, the need for unified governance, visibility, and operational control becomes critical. Disparate agent management leads to fragmented auditing, inconsistent compliance enforcement
Decision
Manage all agents—regardless of whether they are created via low-code platforms or enterprise-grade AI platform—within a single, centralized agent control plane. This control plane will serve as the authoritative source for agent registration, lifecycle management, permissions, and compliance enforcement
Benefits
Unified auditing and compliance
Centralized visibility and permission control across apps, agents, and tools
Consistent policy enforcement
Agent kill switch for rapid response
Consequences
Integration and migration effort required
Will need to decide on a centralized agent control plane (preferably managed)
Integration platform, apps, and tools will need to support federated identity
Phase 0: Agentic Governance & Core Logic

## Decision
Manage all agents—regardless of whether they are created via low-code platforms or enterprise-grade AI platform—within a single, centralized agent control plane. This control plane will serve as the authoritative source for agent registration, lifecycle management, permissions, and compliance enforcement
Benefits
Unified auditing and compliance
Centralized visibility and permission control across apps, agents, and tools
Consistent policy enforcement
Agent kill switch for rapid response
Consequences
Integration and migration effort required
Will need to decide on a centralized agent control plane (preferably managed)
Integration platform, apps, and tools will need to support federated identity
Phase 0: Agentic Governance & Core Logic

## Benefits
Unified auditing and compliance
Centralized visibility and permission control across apps, agents, and tools
Consistent policy enforcement
Agent kill switch for rapid response
Consequences
Integration and migration effort required
Will need to decide on a centralized agent control plane (preferably managed)
Integration platform, apps, and tools will need to support federated identity
Phase 0: Agentic Governance & Core Logic

## Consequences
Integration and migration effort required
Will need to decide on a centralized agent control plane (preferably managed)
Integration platform, apps, and tools will need to support federated identity
Phase 0: Agentic Governance & Core Logic

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0008-agent-control-plane-registration, LAW-ai-0012-traceability-metadata-required
- Adoptions: ADOPTION-ai-0010-manage-all-agents-in-a-single-agent-control-plane

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
