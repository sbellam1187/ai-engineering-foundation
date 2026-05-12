# aa-security-agent-skills

GitHub Copilot skills for automated security remediation across AAInternal repositories.
Used by the Security Agent template workflows to give Copilot deep, structured knowledge
for fixing CodeQL findings and dependency CVEs.

---

## Skills

### `security-codeql-fix`
Deep CodeQL semantic analysis and fix patterns for Java/Spring Boot SAST findings.

**Covers:**
| Rule ID | CWE | Description |
|---------|-----|-------------|
| `java/request-forgery` | CWE-918 | Server-Side Request Forgery (SSRF) |
| `java/sql-injection` | CWE-89 | SQL Injection |
| `java/concatenated-sql-query` | CWE-89 | SQL Concatenation |
| `java/ldap-injection` | CWE-90 | LDAP Injection |
| `java/xss` | CWE-79 | Cross-Site Scripting |
| `java/path-injection` | CWE-22 | Path Traversal |
| `java/zipslip` | CWE-22 | Zip Slip |
| `java/command-line-injection` | CWE-78 | OS Command Injection |
| `java/xml/xxe` | CWE-611 | XML External Entity |
| `java/unsafe-deserialization` | CWE-502 | Unsafe Deserialization |
| `java/stack-trace-exposure` | CWE-209 | Stack Trace in Response |
| `java/sensitive-log` | CWE-532 | Sensitive Data in Logs |
| `java/weak-cryptographic-algorithm` | CWE-327 | Weak Crypto Algorithm |
| `java/insecure-randomness` | CWE-338 | Insecure Randomness |

Each reference includes:
- Exact CodeQL query source link (`github/codeql`)
- What CodeQL's dataflow analysis detects (sources, sinks, sanitizers)
- Why naive fixes fail (with examples)
- Correct fix patterns with working Java/Spring code
- Security tests to validate the fix

### `security-vulnerability-fix`
Dependency CVE remediation for Gradle, Maven, Python, Node.js, Angular, and React.

**Covers:**
- Direct dependency version bumps
- Transitive dependency overrides (constraints, resolution strategy, exclusions)
- BOM-managed version updates
- Build validation and test fixing
- PR creation following security compliance standards

---

## Installation

### Cloud Agent (Automatic)
The `copilot-setup-steps.yml` workflow clones this repo and installs skills automatically
before Copilot starts any security task. No manual steps needed.

### Local VS Code
```bash
git clone --depth 1 https://github.com/AAInternal/aa-security-agent-skills.git /tmp/aa-security-agent-skills \
  && /tmp/aa-security-agent-skills/install.sh --all \
  && rm -rf /tmp/aa-security-agent-skills
```

Then restart VS Code.

### Specific skills only
```bash
./install.sh security-codeql-fix
./install.sh security-vulnerability-fix
./install.sh security-codeql-fix security-vulnerability-fix
```

---

## Repo Structure

```
aa-security-agent-skills/
  install.sh                                    ← Skills installer
  copilot-setup-steps.yml                       ← Cloud agent setup workflow
  skills/
    security-codeql-fix/
      SKILL.md                                  ← Orchestrator + rule→reference routing
      references/
        cwe-918-ssrf.md                         ← SSRF deep reference
        cwe-89-sql-injection.md                 ← SQL Injection deep reference
        cwe-79-xss.md                           ← XSS deep reference
        cwe-22-path-traversal.md                ← Path Traversal + ZipSlip
        cwe-78-command-injection.md             ← OS Command Injection
        cwe-611-xxe.md                          ← XML External Entity
        cwe-502-deserialization.md              ← Unsafe Deserialization
        cwe-200-info-exposure.md                ← Info Exposure + sensitive logs
        cwe-327-crypto.md                       ← Weak Crypto + Insecure Random
    security-vulnerability-fix/
      SKILL.md                                  ← Orchestrator + ecosystem routing
      references/
        gradle.md                               ← Gradle dependency fix patterns
        maven.md                                ← Maven dependency fix patterns
        nodejs.md                               ← Node.js / npm fix patterns
        python.md                               ← Python / pip fix patterns
        angular.md                              ← Angular fix patterns
        react.md                                ← React fix patterns
```

---

## How Skills Work

1. Copilot picks up an assigned security issue
2. `copilot-setup-steps.yml` runs first — installs skills to `~/.copilot/skills/`
3. Copilot reads `SKILL.md` — identifies the Rule ID or ecosystem
4. Copilot loads the specific reference file for that CWE or ecosystem
5. Copilot applies the fix pattern, writes a security test, creates the PR
6. The verify-fix workflow checks if CodeQL still fires on the PR branch
7. Human security reviewer approves and merges

---

## References

| Resource | URL |
|----------|-----|
| CodeQL Java queries source | https://github.com/github/codeql/tree/main/java/ql/src/Security/CWE |
| CodeQL Java query help | https://codeql.github.com/codeql-query-help/java/ |
| CodeQL Java CWE coverage | https://codeql.github.com/codeql-query-help/java-cwe/ |
| OWASP Top 10 (2021) | https://owasp.org/Top10/ |
| OWASP Cheat Sheet Series | https://cheatsheetseries.owasp.org/ |
| CWE Top 25 | https://cwe.mitre.org/top25/ |
| Spring Security Reference | https://docs.spring.io/spring-security/reference/ |
