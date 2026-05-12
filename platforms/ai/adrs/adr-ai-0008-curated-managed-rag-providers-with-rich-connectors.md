---
id: ADR-ai-0008-curated-managed-rag-providers-with-rich-connectors
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0002-responsible-ai-guardrails
  - LAW-ai-0005-multi-provider-compatibility
  - LAW-ai-0006-ai-ready-data-products
  adoptions:
  - ADOPTION-ai-0008-curated-managed-rag-providers-with-rich-connectors
  adrs: []
---

# ADR-ai-0008-curated-managed-rag-providers-with-rich-connectors: Curated Managed RAG Providers with Rich Connectors

## Context
Building RAG at scale requires ingesting diverse enterprise data sources and maintaining freshness. Managed RAG providers offer rich connectors, pipelines, and operational maturity that reduce complexity. To align with our open architecture, these providers must be pluggable into frameworks like LangGraph and accessed via portable patterns.
Decision
Adopt a curated set of managed RAG providers that:
Deliver enterprise-grade connectors (M365/Graph, Confluence, Databricks, ADLS, storage, DBs, third party connectors…).
Integrate via portable adapters callable from LangGraph and registered in our integration platform.
Support multi-provider routing, standard interfaces (REST/gRPC), and governance (auth, safety, cost).
Provision through self-service templates with CI/CD, observability, and compliance controls.
Benefits
Accelerates RAG delivery using out-of-the-box connectors and managed pipelines.
Reduces custom ETL and operational overhead.
Preserves portability and multi-provider flexibility.
Centralizes governance and safety at platform level.
Consequences
Requires maintaining portability patterns and adapters.
Introduces vendor dependency and cost; mitigated via multi-provider stance.
Connector gaps may require custom integration.

## Decision
Adopt a curated set of managed RAG providers that:
Deliver enterprise-grade connectors (M365/Graph, Confluence, Databricks, ADLS, storage, DBs, third party connectors…).
Integrate via portable adapters callable from LangGraph and registered in our integration platform.
Support multi-provider routing, standard interfaces (REST/gRPC), and governance (auth, safety, cost).
Provision through self-service templates with CI/CD, observability, and compliance controls.
Benefits
Accelerates RAG delivery using out-of-the-box connectors and managed pipelines.
Reduces custom ETL and operational overhead.
Preserves portability and multi-provider flexibility.
Centralizes governance and safety at platform level.
Consequences
Requires maintaining portability patterns and adapters.
Introduces vendor dependency and cost; mitigated via multi-provider stance.
Connector gaps may require custom integration.

## Benefits
Accelerates RAG delivery using out-of-the-box connectors and managed pipelines.
Reduces custom ETL and operational overhead.
Preserves portability and multi-provider flexibility.
Centralizes governance and safety at platform level.
Consequences
Requires maintaining portability patterns and adapters.
Introduces vendor dependency and cost; mitigated via multi-provider stance.
Connector gaps may require custom integration.

## Consequences
Requires maintaining portability patterns and adapters.
Introduces vendor dependency and cost; mitigated via multi-provider stance.
Connector gaps may require custom integration.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0006-ai-ready-data-products, LAW-ai-0005-multi-provider-compatibility, LAW-ai-0002-responsible-ai-guardrails
- Adoptions: ADOPTION-ai-0008-curated-managed-rag-providers-with-rich-connectors

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
