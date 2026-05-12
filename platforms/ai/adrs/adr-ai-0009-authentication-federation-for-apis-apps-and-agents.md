---
id: ADR-ai-0009-authentication-federation-for-apis-apps-and-agents
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0001-govern-all-ai-artifacts
  adoptions:
  - ADOPTION-ai-0009-authentication-federation-for-apis-apps-and-agents
  adrs: []
---

# ADR-ai-0009-authentication-federation-for-apis-apps-and-agents: Authentication Federation for APIs, Apps, and Agents

## Context
Unifying governance of AI and non-AI along with low-code and enterprise grade agentic solutions requires federation across APIs, MCP servers, apps, agents, and integration platform.
Decision
Implement authentication federation across APIs, apps, and agents via Entra-issued tokens trusted by the integration gateway(s), with PingFed federation where required. This provides centralize auditing, conditional access, scope/role management, and lifecycle governance (APIs/tools/agents) through platform integration.
Benefits
Standardized auth for agents and apps; consistent kill-switch, auditing, and compliance posture.
Unified lifecycle management across agents, gateways, low-code AI (Copilot Studio), enterprise-grade AI (AI platform), and tools (API & MCP tools).
Consequences
Requires coordinated rollout of gateway policies, token validation, catalog sync, and group/role governance.
Initial overhead for federation setup and migration from legacy tokens to OAuth

## Decision
Implement authentication federation across APIs, apps, and agents via Entra-issued tokens trusted by the integration gateway(s), with PingFed federation where required. This provides centralize auditing, conditional access, scope/role management, and lifecycle governance (APIs/tools/agents) through platform integration.
Benefits
Standardized auth for agents and apps; consistent kill-switch, auditing, and compliance posture.
Unified lifecycle management across agents, gateways, low-code AI (Copilot Studio), enterprise-grade AI (AI platform), and tools (API & MCP tools).
Consequences
Requires coordinated rollout of gateway policies, token validation, catalog sync, and group/role governance.
Initial overhead for federation setup and migration from legacy tokens to OAuth

## Benefits
Standardized auth for agents and apps; consistent kill-switch, auditing, and compliance posture.
Unified lifecycle management across agents, gateways, low-code AI (Copilot Studio), enterprise-grade AI (AI platform), and tools (API & MCP tools).
Consequences
Requires coordinated rollout of gateway policies, token validation, catalog sync, and group/role governance.
Initial overhead for federation setup and migration from legacy tokens to OAuth

## Consequences
Requires coordinated rollout of gateway policies, token validation, catalog sync, and group/role governance.
Initial overhead for federation setup and migration from legacy tokens to OAuth

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0001-govern-all-ai-artifacts
- Adoptions: ADOPTION-ai-0009-authentication-federation-for-apis-apps-and-agents

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
