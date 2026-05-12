# SonarQube Report Templates

Report format templates for the SonarQube Code Quality Review Skill.

## Report Header

```markdown
# SonarQube Code Quality Review Report

| Field | Value |
|-------|-------|
| **Project** | {project-name} |
| **Date** | {YYYY-MM-DD} |
| **Scope** | {Full review / PR diff / Specific files} |
| **Ecosystem** | {Java / .NET / Node.js / Python} |
| **Quality Profile** | {Sonar way / Custom} |
| **Reviewer** | AI — SonarQube Review Skill v1.0.0 |
```

## Summary Dashboard

```markdown
## Summary

| Category | Count | Worst Severity |
|----------|-------|---------------|
| 🔴 Bugs | X | BLOCKER / CRITICAL / MAJOR |
| 🟠 Vulnerabilities | X | BLOCKER / CRITICAL / MAJOR |
| 🔶 Security Hotspots | X (Y unreviewed) | — |
| 🟡 Code Smells | X | CRITICAL / MAJOR / MINOR |
| 🔵 Coverage Gaps | X | — |

### Ratings
| Dimension | Rating | Basis |
|-----------|--------|-------|
| Reliability | A–E | Worst open bug |
| Security | A–E | Worst open vulnerability |
| Maintainability | A–E | Debt ratio |

### Quality Gate
| Condition | Threshold | Actual | Status |
|-----------|-----------|--------|--------|
| Coverage on new code | ≥ 80% | X% | ✅ / ❌ |
| Duplicated lines | ≤ 3% | X% | ✅ / ❌ |
| Reliability rating | A | X | ✅ / ❌ |
| Security rating | A | X | ✅ / ❌ |
| **Overall** | — | — | **✅ PASS / ❌ FAIL** |

### Technical Debt
| Metric | Value |
|--------|-------|
| Total debt | ~X hours |
| Debt ratio | X% |
```

## Finding Detail Template

```markdown
### [SEVERITY-EMOJI] [TYPE]: Brief title

**File:** `path/to/File.java` (line ~N)
**Rule:** squid:SXXXX / eslint:rule-name
**Severity:** BLOCKER / CRITICAL / MAJOR / MINOR
**OWASP:** A0X:2021 (if security)
**CWE:** CWE-XXX (if security)
**Remediation:** ~X min
**Issue:** What is wrong.
**Fix:**
\`\`\`java
// before/after code
\`\`\`
```

## Remediation Plan Template

```markdown
## Recommended Remediation Order

### 🔴 Immediate (blocks release)
1. Fix BLOCKER/CRITICAL bugs
2. Fix vulnerabilities
3. Review security hotspots

### 🟡 Short Term (this sprint)
4. Reduce cognitive complexity (top 5 methods)
5. Fix MAJOR code smells

### 🔵 Planned (next sprint)
6. Remaining code smells
7. Improve branch coverage

### 📋 Backlog
8. MINOR smells and style
```
