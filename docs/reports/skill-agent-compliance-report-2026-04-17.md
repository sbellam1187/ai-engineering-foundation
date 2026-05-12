# Skill & Agent Compliance Refactoring Report

**Date**: 2026-04-17  
**Scope**: Full repository scan  
**Files Analyzed**: 20 (4 agents, 16 skills including 3 duplicates)

---

## Compliance Summary

| File | Type | Before | After | Key Changes |
|------|------|--------|-------|-------------|
| `crosscutting/quality/agents/agent-quality-0001-code-reviewer.md` | Agent | PARTIAL | PASS | Moved coding standards to skill references; added agent sections |
| `crosscutting/quality/agents/agent-quality-0002-code-simplifier.md` | Agent | PARTIAL | PASS | Moved refactoring techniques to skill references; added agent sections |
| `crosscutting/security/agents/agent-security-0001-security-scanner.md` | Agent | PARTIAL | PASS | Moved scan layer details to skill references; added agent sections |
| `platforms/ai/agents/agent-ai-0001-prompt-generator.md` | Agent | PARTIAL | PASS | Removed embedded templates; added agent sections |
| `crosscutting/devops/skills/drawio/SKILL.md` | Skill | PARTIAL | PASS | Added missing structured sections |
| `crosscutting/devops/skills/tech-doc-generator/SKILL.md` | Skill | FAIL | PASS | Moved framework detection & doc templates to references |
| `crosscutting/devops/skills/user-story-generator/SKILL.md` | Skill | PARTIAL | PASS | Removed user-interaction orchestration; made deterministic |
| `crosscutting/quality/skills/skill-quality-0001-tech-doc-generator.md` | Skill | FAIL | PASS | Moved framework detection & doc templates to references |
| `crosscutting/quality/skills/skill-quality-0002-sonarqube-review.md` | Skill | PARTIAL | PASS | Moved rule categories & report templates to references |
| `crosscutting/quality/skills/sabre-test-data/SKILL.md` | Skill | PASS | PASS | No changes needed — model skill |
| `crosscutting/security/skills/skill-security-0001-dependency-upgrade-scanner.md` | Skill | PARTIAL | PASS | Moved report template to references |
| `crosscutting/security/skills/vulnerability-fix/SKILL.md` | Skill | PASS | PASS | No changes needed — model skill |
| `platforms/ai/skills/skill-ai-0001-standard-prompt-generation.md` | Skill | PARTIAL | PASS | Moved templates to references file |
| `platforms/telemetry/skills/mezmo-log-analysis/SKILL.md` | Skill | FAIL | PASS | Moved examples, scripts, tracing workflows to references |
| `runtimes/java-spring/skills/skill-java-spring-0001-junit-mockito.md` | Skill | PASS | PASS | No changes needed |
| `runtimes/java-spring/skills/skill-java-spring-0002-spring-boot-tdd.md` | Skill | PASS | PASS | No changes needed |
| `runtimes/java-spring/skills/test-driven-development/SKILL.md` | Skill | PASS | PASS | No changes needed |
| `runtimes/react/skills/skill-java-spring-0001-junit-mockito.md` | Skill | ⚠️ DUPLICATE | — | Duplicate of java-spring skill — misplaced in react folder |
| `runtimes/react/skills/skill-java-spring-0002-spring-boot-tdd.md` | Skill | ⚠️ DUPLICATE | — | Duplicate of java-spring skill — misplaced in react folder |
| `runtimes/react/skills/test-driven-development/SKILL.md` | Skill | ⚠️ DUPLICATE | — | Duplicate of java-spring skill — misplaced in react folder |

---

## Compliance Checklist

### Skills are execution-only

- [x] `drawio/SKILL.md` — Deterministic diagram generation
- [x] `tech-doc-generator/SKILL.md` — Deterministic doc generation (framework details moved to references)
- [x] `user-story-generator/SKILL.md` — Deterministic story generation (user interaction notes moved to agent responsibility)
- [x] `skill-quality-0001-tech-doc-generator.md` — Deterministic (framework details in references)
- [x] `skill-quality-0002-sonarqube-review.md` — Deterministic (rule catalogs in references)
- [x] `sabre-test-data/SKILL.md` — Already compliant
- [x] `skill-security-0001-dependency-upgrade-scanner.md` — Deterministic (report template in references)
- [x] `vulnerability-fix/SKILL.md` — Already compliant
- [x] `skill-ai-0001-standard-prompt-generation.md` — Deterministic (templates in references)
- [x] `mezmo-log-analysis/SKILL.md` — Deterministic (examples/scripts in references)
- [x] `skill-java-spring-0001-junit-mockito.md` — Already compliant
- [x] `skill-java-spring-0002-spring-boot-tdd.md` — Already compliant
- [x] `test-driven-development/SKILL.md` — Already compliant

### Agents are orchestration-only

- [x] `agent-quality-0001-code-reviewer.md` — Routes to skills, validates, stops
- [x] `agent-quality-0002-code-simplifier.md` — Routes to skills, validates, stops
- [x] `agent-security-0001-security-scanner.md` — Routes to skills, validates, stops
- [x] `agent-ai-0001-prompt-generator.md` — Detects intent, routes to skills/agents

---

## Skill → Agent Call Map

| Agent | Skills Called | Purpose |
|-------|-------------|---------|
| `agent-quality-0001-code-reviewer` | `skill-ai-0001-standard-prompt-generation` (Code Review template) | Load review template |
| `agent-quality-0001-code-reviewer` | `skill-quality-0002-sonarqube-review` | Run SonarQube-aligned checks |
| `agent-quality-0002-code-simplifier` | (inline execution — no skill dependency) | Direct refactoring |
| `agent-security-0001-security-scanner` | `skill-security-0001-dependency-upgrade-scanner` | CVE/dependency scanning |
| `agent-security-0001-security-scanner` | `skill-quality-0002-sonarqube-review` (Variant E) | Security-focused code review |
| `agent-ai-0001-prompt-generator` | `skill-ai-0001-standard-prompt-generation` | Load prompt templates |
| `agent-ai-0001-prompt-generator` | → `agent-quality-0001-code-reviewer` | Route REVIEW intent |
| `agent-ai-0001-prompt-generator` | → `agent-quality-0002-code-simplifier` | Route SIMPLIFY intent |
| `agent-ai-0001-prompt-generator` | → `agent-security-0001-security-scanner` | Route SECURITY intent |
| `agent-ai-0001-prompt-generator` | `skill-quality-0001-tech-doc-generator` | Route DOCUMENT intent |

---

## Anomalies Found

1. **Duplicate skills in `runtimes/react/skills/`**: Three Java/Spring skills are duplicated in the React folder. These should be removed or replaced with React-specific equivalents.
2. **Duplicate tech-doc-generator**: `crosscutting/devops/skills/tech-doc-generator/SKILL.md` and `crosscutting/quality/skills/skill-quality-0001-tech-doc-generator.md` contain nearly identical content. Consider consolidating.
