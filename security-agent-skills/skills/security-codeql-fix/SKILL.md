---
name: security-codeql-fix
description: Fix CodeQL security findings in Java/Spring Boot, JavaScript/Node.js, and Python projects. Use when addressing issues labeled 'security', 'copilot-fix', or 'copilot-security-fix' created by the Security CodeQL Auto-Remediation workflow. Covers SSRF, SQL Injection, XSS, Path Traversal, Command Injection, XXE, Deserialization, Information Exposure, and Cryptographic Failures with deep semantic analysis of what each CodeQL query detects and why naive fixes fail.
---

# Security CodeQL Fix Skill

Fix CodeQL security findings by understanding what the query's dataflow analysis detected, applying the correct root-cause fix, and validating that the rule no longer fires on the PR branch.

---

## When to Use

Trigger this skill when:
- Working on issues labeled `security`, `copilot-fix`, or `copilot-security-fix`
- The issue contains a **Rule ID** (e.g., `java/request-forgery`, `java/sql-injection`)
- The issue was created by the Security CodeQL Auto-Remediation workflow
- A CodeQL check is failing on a PR and needs to be resolved

---

## How to Read a CodeQL Issue

Every issue created by the workflow contains:

| Field | What it means |
|-------|--------------|
| **Rule ID** | The exact CodeQL query that fired — map this to a reference file below |
| **CWE** | The weakness class — confirms which fix pattern to apply |
| **File + Line** | Exact location of the vulnerability source or sink |
| **Alert message** | What CodeQL detected — read carefully, it describes the taint flow |
| **Source code block** | The vulnerable code with surrounding context |
| **Dedup marker** | `<!-- CODEQL_RULE_... -->` — do NOT remove this, it prevents duplicate issues |

> **Critical:** Fix ALL occurrences listed in the issue in a **single PR**. Do not suppress alerts — fix the root cause.

---

## How CodeQL Works — Semantic Analysis

CodeQL does not do text matching. It builds a full semantic model of your code:

1. **Source** — where untrusted data enters (HTTP params, headers, request body, path variables)
2. **Taint propagation** — CodeQL tracks the data through assignments, method calls, string operations
3. **Sink** — where the tainted data reaches a dangerous operation (SQL query, file path, HTTP request, OS command)
4. **Sanitizers** — operations that clean the data and break the taint flow

**Why naive fixes fail:**
- Renaming a variable does not fix it — taint follows the data, not the name
- Moving code to another method does not fix it — CodeQL tracks inter-procedural flow
- Adding a log statement does not fix it — it's not a sanitizer
- Suppression comments (`@SuppressWarnings`) do not fix it — CodeQL ignores them
- The fix must introduce a real sanitizer or eliminate the taint path entirely

---

## Rule ID → Reference File Mapping

Read the reference file that matches the Rule ID in the issue:

| Rule ID | CWE | Reference File |
|---------|-----|---------------|
| `java/request-forgery` | CWE-918 | `references/cwe-918-ssrf.md` |
| `java/sql-injection` | CWE-89 | `references/cwe-89-sql-injection.md` |
| `java/concatenated-sql-query` | CWE-89 | `references/cwe-89-sql-injection.md` |
| `java/xss` | CWE-79 | `references/cwe-79-xss.md` |
| `java/path-injection` | CWE-22 | `references/cwe-22-path-traversal.md` |
| `java/zipslip` | CWE-22 | `references/cwe-22-path-traversal.md` |
| `java/partial-path-traversal` | CWE-22 | `references/cwe-22-path-traversal.md` |
| `java/command-line-injection` | CWE-78 | `references/cwe-78-command-injection.md` |
| `java/concatenated-command-line` | CWE-78 | `references/cwe-78-command-injection.md` |
| `java/xml/xxe` | CWE-611 | `references/cwe-611-xxe.md` |
| `java/unsafe-deserialization` | CWE-502 | `references/cwe-502-deserialization.md` |
| `java/sensitive-log` | CWE-532 | `references/cwe-200-info-exposure.md` |
| `java/stack-trace-exposure` | CWE-209 | `references/cwe-200-info-exposure.md` |
| `java/sensitive-query-parameter` | CWE-598 | `references/cwe-200-info-exposure.md` |
| `java/insecure-randomness` | CWE-338 | `references/cwe-327-crypto.md` |
| `java/weak-cryptographic-algorithm` | CWE-327 | `references/cwe-327-crypto.md` |
| `java/ldap-injection` | CWE-90 | `references/cwe-89-sql-injection.md` |
| `java/log4j-injection` | CWE-20 | `references/cwe-78-command-injection.md` |

> **Only load the reference file for the Rule ID in the issue.** Do not load all files.

---

## Fix Validation Workflow

After applying the fix:

```
1. Build must compile cleanly
2. All existing tests must pass — no skipping
3. Add a security test that proves the fix works
4. CodeQL will re-scan automatically on PR push
5. The verify-fix workflow checks if the rule still fires
6. Status check turns green when the rule no longer fires
7. Do NOT merge — wait for security team approval
```

---

## Critical Guardrails

1. **Do NOT suppress alerts** — no `@SuppressWarnings`, no `// lgtm`, no CodeQL inline suppressions
2. **Do NOT move vulnerable code** to another file or method to avoid detection — CodeQL tracks inter-procedural flow
3. **Do NOT call methods that don't exist** in the codebase — if a helper is needed, create it in the same PR
4. **Do NOT reference config properties** not already in `application.properties` — add them with defaults if required
5. **Prefer framework-native patterns** — Spring URI templates over manual URLEncoder, JPA over raw SQL
6. **Keep fixes minimal** — change the fewest lines necessary to break the taint path
7. **All existing tests must pass** after your fix
8. **PR description must reference the issue:** `Fixes #issue-number`
9. **Do NOT merge your own PR** — wait for security team approval

---

## PR Requirements

### Branch Naming
```
security/fix-{rule-id}-{YYYYMMDD}
```

### PR Title
```
fix(security): fix {CWE} {rule-description} in {ClassName}
```

### PR Body
```markdown
## Security Fix

**Rule ID:** `{rule-id}`
**CWE:** {CWE}
**OWASP:** {category}
**Severity:** {severity}

### Root Cause
{Brief description of what CodeQL detected and why it was vulnerable}

### Fix Applied
{Description of the fix — what sanitizer or pattern was introduced}

### Why This Fix Works
{Explanation of how the fix breaks the taint flow}

### Validation
- [x] Build compiles successfully
- [x] All existing tests pass
- [x] Security test added proving fix works
- [x] CodeQL rule no longer fires on this branch

Fixes #{issue-number}
```

---

## References

| Resource | URL |
|----------|-----|
| CodeQL Java query source | https://github.com/github/codeql/tree/main/java/ql/src/Security/CWE |
| CodeQL Java query help | https://codeql.github.com/codeql-query-help/java/ |
| CodeQL Java CWE coverage | https://codeql.github.com/codeql-query-help/java-cwe/ |
| CodeQL docs | https://codeql.github.com/docs/ |
| OWASP Top 10 (2021) | https://owasp.org/Top10/ |
| OWASP Cheat Sheet Series | https://cheatsheetseries.owasp.org/ |
| CWE Top 25 | https://cwe.mitre.org/top25/ |
| Spring Security Reference | https://docs.spring.io/spring-security/reference/ |
| NVD CVE Database | https://nvd.nist.gov/vuln/search |
