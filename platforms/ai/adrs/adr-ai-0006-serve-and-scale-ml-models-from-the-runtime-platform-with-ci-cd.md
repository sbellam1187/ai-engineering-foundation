---
id: ADR-ai-0006-serve-and-scale-ml-models-from-the-runtime-platform-with-ci-cd
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0003-platform-first-delivery
  - LAW-ai-0012-traceability-metadata-required
  adoptions:
  - ADOPTION-ai-0006-serve-and-scale-ml-models-from-the-runtime-platform-with-ci-cd
  adrs: []
---

# ADR-ai-0006-serve-and-scale-ml-models-from-the-runtime-platform-with-ci-cd: Serve and Scale ML Models from the Runtime Platform with CI/CD

## Context
The ML pattern shows model server inference, cataloged models, and runtime/provider options with CI/CD and observability. Release deliverables include agent/client services deployed with pipelines and monitoring.
Decision
Host ML models on the enterprise runtime platform, fronted by the integration gateway/catalog. Provide standardized CI/CD pipelines (build, deploy, validate), observability (model performance, token/call telemetry), and cost controls. Prefer runtime-managed model servers over ad hoc hosting.
Benefits
Consistent scale, security, and performance via platformized serving.
Faster iteration and safer rollouts through pipelines and monitoring defaults.
Consequences
Teams must conform to standardized pipelines and operational SLOs.
Specialized hardware (GPU/TPU) scheduling and capacity management become platform responsibilities. [AI Technol...sformation | PowerPoint]

## Decision
Host ML models on the enterprise runtime platform, fronted by the integration gateway/catalog. Provide standardized CI/CD pipelines (build, deploy, validate), observability (model performance, token/call telemetry), and cost controls. Prefer runtime-managed model servers over ad hoc hosting.
Benefits
Consistent scale, security, and performance via platformized serving.
Faster iteration and safer rollouts through pipelines and monitoring defaults.
Consequences
Teams must conform to standardized pipelines and operational SLOs.
Specialized hardware (GPU/TPU) scheduling and capacity management become platform responsibilities. [AI Technol...sformation | PowerPoint]

## Benefits
Consistent scale, security, and performance via platformized serving.
Faster iteration and safer rollouts through pipelines and monitoring defaults.
Consequences
Teams must conform to standardized pipelines and operational SLOs.
Specialized hardware (GPU/TPU) scheduling and capacity management become platform responsibilities. [AI Technol...sformation | PowerPoint]

## Consequences
Teams must conform to standardized pipelines and operational SLOs.
Specialized hardware (GPU/TPU) scheduling and capacity management become platform responsibilities. [AI Technol...sformation | PowerPoint]

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0003-platform-first-delivery, LAW-ai-0012-traceability-metadata-required
- Adoptions: ADOPTION-ai-0006-serve-and-scale-ml-models-from-the-runtime-platform-with-ci-cd

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
