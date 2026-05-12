---
id: ADR-ai-0005-make-ai-part-of-the-standard-enterprise-architecture-process
concern: ai
status: accepted
owner: AI Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws:
  - LAW-ai-0001-govern-all-ai-artifacts
  - LAW-ai-0003-platform-first-delivery
  adoptions:
  - ADOPTION-ai-0005-make-ai-part-of-the-standard-enterprise-architecture-process
  adrs: []
---

# ADR-ai-0005-make-ai-part-of-the-standard-enterprise-architecture-process: Make AI Part of the Standard Enterprise Architecture Process

## Context
The transformation plan calls for Streamlined AI Architecture Approval and scaling AI with platform-compliant paths and goal of removing manual reviews once controls are validated. The initial governance flow includes additional manual AI reviews for non-prod/prod.
Decision
Adopt a single enterprise architecture governance process for all applications (on-prem/cloud; operations/customer/workplace/infrastructure; IoT/algorithmic/AI/optimization/drone; security/privacy classes), integrating AI concerns into the standard review. To enable scaling, target full automation and removal of manual approvals for platform-compliant patterns once the platform solution is  released and matured
Benefits
Eliminates parallel AI-only processes; reduces friction and improves throughput.
Scales reviews via automated controls for safety, privacy, security, and cost.
Consequences
Requires rigorous validation of platform controls (e.g., redaction, groundedness detection) before removing manual gates.
Non-platform compliant patterns to require additional review.

## Decision
Adopt a single enterprise architecture governance process for all applications (on-prem/cloud; operations/customer/workplace/infrastructure; IoT/algorithmic/AI/optimization/drone; security/privacy classes), integrating AI concerns into the standard review. To enable scaling, target full automation and removal of manual approvals for platform-compliant patterns once the platform solution is  released and matured
Benefits
Eliminates parallel AI-only processes; reduces friction and improves throughput.
Scales reviews via automated controls for safety, privacy, security, and cost.
Consequences
Requires rigorous validation of platform controls (e.g., redaction, groundedness detection) before removing manual gates.
Non-platform compliant patterns to require additional review.

## Benefits
Eliminates parallel AI-only processes; reduces friction and improves throughput.
Scales reviews via automated controls for safety, privacy, security, and cost.
Consequences
Requires rigorous validation of platform controls (e.g., redaction, groundedness detection) before removing manual gates.
Non-platform compliant patterns to require additional review.

## Consequences
Requires rigorous validation of platform controls (e.g., redaction, groundedness detection) before removing manual gates.
Non-platform compliant patterns to require additional review.

## Considered options
1. Platform-standard approach (preferred)
2. Provider-specific implementation without portability abstractions
3. Team-specific bespoke solution without platform guardrails

## Rationale
- Aligns with AI strategy principles for governance, portability, and platform scale.
- Concentrates safety, security, and cost controls at shared control points.

## Spec compliance
- Laws: LAW-ai-0001-govern-all-ai-artifacts, LAW-ai-0003-platform-first-delivery
- Adoptions: ADOPTION-ai-0005-make-ai-part-of-the-standard-enterprise-architecture-process

## Follow-up actions
- Implement the corresponding adoption and enforcement checks mapped to the listed laws.
