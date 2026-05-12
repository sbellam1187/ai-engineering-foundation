---
id: SKILL-quality-0002-sonarqube-review
name: sonarqube-review
title: SonarQube Code Quality Review
version: 1.1.0
status: active
owner: enterprise-architecture
concern: quality
created: 2026-04-05
lastUpdated: 2026-04-17
description: >
  Performs a SonarQube-aligned code quality review on any project. Covers bugs, vulnerabilities,
  security hotspots, code smells, cognitive complexity, duplication, and coverage gaps.
  Produces a prioritised finding report with fix patterns, quality-gate assessment, and
  SQALE technical-debt estimation. Works across Java, .NET, Node.js/TypeScript, and Python.
trigger_keywords:
  - sonar
  - sonarqube
  - code quality
  - code smells
  - cognitive complexity
  - coverage gap
  - static analysis
  - technical debt
  - quality gate
  - OWASP
related:
  laws:
    - LAW-security-0001-security-by-design
  adoptions: []
  skills:
    - SKILL-security-0001-dependency-upgrade-scanner
    - SKILL-quality-0001-tech-doc-generator
  plugins: []
---

# SonarQube Code Quality Review

## Purpose

Perform a SonarQube-aligned code quality review covering bugs, vulnerabilities, security hotspots, code smells, cognitive complexity, duplication, and coverage gaps. Findings are mapped to OWASP Top 10 / CWE and produce an actionable report with quality-gate assessment and SQALE debt estimation.

## Inputs

- Path to the codebase or specific files to review
- Ecosystem type (auto-detect from build files)
- Scope: full review vs. targeted (e.g., "just complexity", "only security")
- Quality profile (default: Sonar way)
- Whether to include fix suggestions or report-only

## Outputs

- Prioritised finding report grouped by severity (Bug → Vulnerability → Hotspot → Smell → Coverage)
- Before/after fix patterns for every finding
- Quality-gate pass/fail assessment
- OWASP / CWE mapping for security findings
- SQALE technical-debt estimation
- Remediation action plan

Format: Markdown report (inline or saved to `docs/reports/sonarqube-review-{YYYY-MM-DD}.md`).

## Steps

### Step 1 — Discover Project and Configuration

1. Identify language/framework from build files
2. Read SonarQube config (`sonar-project.properties`, plugin configs, lint configs)
3. Build exclusion registry: `sonar.exclusions`, `sonar.coverage.exclusions`, inline suppressions (`// NOSONAR`, `@SuppressWarnings`, `# noqa`)
4. **Excluded files are OFF-LIMITS** — do not flag issues in them

### Step 2 — Determine Quality-Gate Thresholds

Use project-specific config or enterprise defaults:

| Condition | Default | Applies To |
|-----------|---------|-----------|
| Coverage | ≥ 80% | New code |
| Duplicated Lines | ≤ 3% | New code |
| Reliability Rating | A | New code |
| Security Rating | A | New code |
| Maintainability Rating | A | New code |
| Cognitive Complexity | ≤ 15/method | All code |

### Step 3 — Scan Source Code by Layer

Read actual files layer by layer:

1. Entry point & bootstrap
2. Controllers / Routes / API layer
3. Service / Business logic
4. Data access layer
5. Domain model / Entities
6. Configuration
7. Security layer
8. Infrastructure / Integration
9. Test code

At each layer, check against rule categories in [references/ref-quality-0005-sonarqube-rules.md](references/ref-quality-0005-sonarqube-rules.md).

### Step 4 — Map Security Findings

Map every vulnerability and hotspot to OWASP Top 10 (2021) and CWE ID.

### Step 5 — Calculate Technical Debt

Estimate remediation effort per smell using SQALE model (see rules reference).

### Step 6 — Assess Quality Gate

Evaluate all conditions from Step 2. Overall: PASS if all pass, FAIL if any fail.

### Step 7 — Generate Report

Use templates from [references/ref-quality-0006-sonarqube-report-templates.md](references/ref-quality-0006-sonarqube-report-templates.md).

## Standards & Constraints

1. **Respect project exclusions** — Read config BEFORE flagging issues.
2. **Respect approved suppressions** — Only flag unjustified suppressions.
3. **Do not modify source code** unless explicitly asked.
4. **Verify coverage exclusions** before requesting tests.
5. **Cite file and line** for every finding.
6. **Prioritise security over style**.
7. **Map security findings** to OWASP / CWE.

## References

| File | Purpose |
|------|---------|
| [references/ref-quality-0005-sonarqube-rules.md](references/ref-quality-0005-sonarqube-rules.md) | Full rule categories, ecosystem-specific patterns, fix examples, anti-patterns, SQALE estimates |
| [references/ref-quality-0006-sonarqube-report-templates.md](references/ref-quality-0006-sonarqube-report-templates.md) | Report format templates (header, dashboard, finding detail, remediation plan) |

## Variants

### Variant A — Cognitive Complexity Focus
Scan all methods for complexity > 15. Rank highest first. Provide refactoring examples.

### Variant B — Pre-PR Quality Gate Check
Focus on new/modified files. Zero new bugs/vulns. Quick go/no-go.

### Variant C — Coverage Gap Analysis
Read exclusion configs first. Identify untested public methods. Suggest test cases.

### Variant D — Static Analysis Compliance
PMD, Checkstyle, ESLint, Pylint violations only. Check suppressions.

### Variant E — Security Review (OWASP / CWE)
Vulnerabilities and hotspots only. Full OWASP compliance matrix.

### Variant F — Technical Debt Assessment
SQALE model. Top 10 debt contributors. Sprint-by-sprint reduction plan.
