---
id: ADR-cloud-0003-templatize-and-automate-cloud-native-patterns
concern: cloud
status: accepted
owner: Platform Engineering
created: 2026-02-23
lastUpdated: '2026-03-02'
related:
  laws: []
  adoptions: []
  adrs: []
---

# ADR-cloud-0003-templatize-and-automate-cloud-native-patterns: Templatize and Automate Enterprise Cloud-Native Patterns

## Context
Automation, DevOps enablement, and standardized IaC and CI/CD are critical to scale cloud adoption while maintaining security, compliance, and cost controls.

## Decision
Codify enterprise cloud-native patterns as templates delivered through the Developer Platform. Automate infrastructure provisioning, pipelines, security baselines, observability, and cost controls with self-service provisioning and policy enforcement.

## Considered options
1. Templated golden paths delivered via a developer platform
2. Documentation-only guidance and manual implementation by teams
3. Central implementation by a platform team without self-service

## Rationale
- Reduces time-to-production by providing repeatable patterns.
- Ensures consistent security, compliance, and FinOps from day one.
- Improves auditability through standardized and versioned artifacts.

## Consequences
### Positive
- Reduced onboarding friction and fewer one-off implementations.
- Higher consistency for telemetry, tagging, and guardrails.

### Negative
- Requires ongoing template maintenance and productization.
- Non-templated needs may require exceptions or backlog prioritization.

## Follow-up actions
- Establish template lifecycle management and versioning.
- Create CI gates and admission controls aligned to laws and adoptions.
