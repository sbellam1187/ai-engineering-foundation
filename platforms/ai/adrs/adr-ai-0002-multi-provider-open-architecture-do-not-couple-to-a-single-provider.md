---
id: ADR-ai-0002-multi-provider-open-architecture-do-not-couple-to-a-single-provider
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0004-open-portable-default-block-proprietary
  - LAW-ai-0005-multi-provider-compatibility
  adoptions:
  - ADOPTION-ai-0002-multi-provider-open-architecture-do-not-couple-to-a-single-provider
  adrs: []
---

# ADR-ai-0002-multi-provider-open-architecture-do-not-couple-to-a-single-provider: Multi-Provider Open Architecture—Do Not Couple to a Single Provider

## Context
Principles call for a Vendor-Agnostic AI Architecture Foundation with an integration platform enabling AI provider routing. The Integration Platform Direction explicitly positions Apigee and catalog sync for multi-cloud/provider interoperability and federation.
Decision
Adopt a multi-provider architecture for AI models and enabling services. All patterns (runtime, integration, developer, telemetry) must support provider interchange and dual registration (catalog/federation) so we can route agents and apps to the best-fit AI services over time.
Benefits
Resilience against provider outages/terms changes and freedom to select best-fit capabilities.
Future-proofs integration via gateway/catalog interoperability and identity federation.
Consequences
Increases design/test matrix and operational complexity across providers.
Requires ongoing catalog sync, identity federation, and policy harmonization between platforms.

## Decision
Adopt a multi-provider architecture for AI models and enabling services. All patterns (runtime, integration, developer, telemetry) must support provider interchange and dual registration (catalog/federation) so we can route agents and apps to the best-fit AI services over time.
Benefits
Resilience against provider outages/terms changes and freedom to select best-fit capabilities.
Future-proofs integration via gateway/catalog interoperability and identity federation.
Consequences
Increases design/test matrix and operational complexity across providers.
Requires ongoing catalog sync, identity federation, and policy harmonization between platforms.

## Benefits
Resilience against provider outages/terms changes and freedom to select best-fit capabilities.
Future-proofs integration via gateway/catalog interoperability and identity federation.
Consequences
Increases design/test matrix and operational complexity across providers.
Requires ongoing catalog sync, identity federation, and policy harmonization between platforms.

## Consequences
Increases design/test matrix and operational complexity across providers.
Requires ongoing catalog sync, identity federation, and policy harmonization between platforms.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0005-multi-provider-compatibility, LAW-ai-0004-open-portable-default-block-proprietary
- Adoptions: ADOPTION-ai-0002-multi-provider-open-architecture-do-not-couple-to-a-single-provider

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
