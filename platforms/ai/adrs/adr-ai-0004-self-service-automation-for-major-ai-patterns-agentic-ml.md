---
id: ADR-ai-0004-self-service-automation-for-major-ai-patterns-agentic-ml
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0002-responsible-ai-guardrails
  - LAW-ai-0003-platform-first-delivery
  - LAW-ai-0010-cost-protection-token-budgets
  adoptions:
  - ADOPTION-ai-0004-self-service-automation-for-major-ai-patterns-agentic-ml
  adrs: []
---

# ADR-ai-0004-self-service-automation-for-major-ai-patterns-agentic-ml: Self-Service Automation for Major AI Patterns (Agentic & ML)

## Context
Enablement calls for reference patterns, inner-source templates, and a unified self-service provisioning template (attributes for safety, cost, performance). This enables scaling AI with platforms for major AI patterns
Decision
Provide self-service, automated provisioning for core AI patterns (agentic, ML; expand to MCP/RAG next), including infrastructure, CI/CD, safety filters, observability, identity, and FinOps—all requested via a unified template and approved through platform governance.
Benefits
Cuts time-to-prod from months to days by automating end-to-end setup.
Ensures consistent controls (content filters, blocklists, cost budgets, monitoring) at provision time.
Consequences
Template coverage must expand with new patterns; otherwise teams may seek exceptions.
Approval gates persist for non-platform compliant patterns

## Decision
Provide self-service, automated provisioning for core AI patterns (agentic, ML; expand to MCP/RAG next), including infrastructure, CI/CD, safety filters, observability, identity, and FinOps—all requested via a unified template and approved through platform governance.
Benefits
Cuts time-to-prod from months to days by automating end-to-end setup.
Ensures consistent controls (content filters, blocklists, cost budgets, monitoring) at provision time.
Consequences
Template coverage must expand with new patterns; otherwise teams may seek exceptions.
Approval gates persist for non-platform compliant patterns

## Benefits
Cuts time-to-prod from months to days by automating end-to-end setup.
Ensures consistent controls (content filters, blocklists, cost budgets, monitoring) at provision time.
Consequences
Template coverage must expand with new patterns; otherwise teams may seek exceptions.
Approval gates persist for non-platform compliant patterns

## Consequences
Template coverage must expand with new patterns; otherwise teams may seek exceptions.
Approval gates persist for non-platform compliant patterns

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0003-platform-first-delivery, LAW-ai-0010-cost-protection-token-budgets, LAW-ai-0002-responsible-ai-guardrails
- Adoptions: ADOPTION-ai-0004-self-service-automation-for-major-ai-patterns-agentic-ml

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
