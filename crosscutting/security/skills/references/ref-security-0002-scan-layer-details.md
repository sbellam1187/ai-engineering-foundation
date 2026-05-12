# Security Scan Layer Details

Detailed checklists and patterns for each scan layer used by the Security Scanner Agent.

## Layer 1: Dependency & CVE Scan

**Why**: A single vulnerable transitive dependency can compromise the entire service.

**Actions**:
1. Identify dependency manifest (`pom.xml`, `build.gradle`, `package.json`, `requirements.txt`, `go.mod`, `*.csproj`)
2. Extract all dependencies with versions (resolve variable placeholders)
3. Check for known CVEs using `dependency-upgrade-scanner` skill, NVD, GitHub Advisory Database
4. Flag version ranges — non-reproducible builds
5. Audit exclusions/overrides — each signals a past vulnerability
6. Check Dependabot/Renovate config for gaps

**Severity**: CRITICAL (CVSS ≥ 9.0) | HIGH (7.0–8.9) | MEDIUM (4.0–6.9) | LOW (outdated, no CVE)

## Layer 2: Secrets & Credential Exposure

**Why**: Hardcoded secrets are the #1 cause of breaches.

**Scan targets**:
- Configuration files: hardcoded passwords, tokens, API keys, connection strings
- Source code: string literals that look like secrets, env var defaults with real values
- IaC files: unencrypted secrets, variables not marked sensitive
- Container configs: inline env secrets, missing secret providers
- `.gitignore`: verify exclusion of `.pfx`, `.pem`, `.key`, `.env`, `*.tfvars`
- Git history: committed certificate private keys, SSH keys

**Severity**: CRITICAL (plaintext secret, private key) | HIGH (hardcoded default, unmarked sensitive) | MEDIUM (test credentials) | LOW (missing .gitignore patterns)

## Layer 3: Authentication & Authorization

**Why**: Missing or misconfigured auth is OWASP #1.

**Actions**:
1. List all API endpoints
2. Check security framework config (Spring Security, Passport.js, FastAPI security, .NET `[Authorize]`)
3. Map endpoint protection (public vs authenticated)
4. Check infrastructure-level auth (API Gateway, service mesh)
5. Audit sensitive endpoints (actuator, debug, admin)
6. Verify token handling (signature, expiry, issuer, audience, storage)

**Severity**: CRITICAL (no auth framework, exposed sensitive endpoints) | HIGH (debug endpoints, missing authz) | MEDIUM (permissive token validation) | LOW (missing method-level security)

## Layer 4: Input Validation & Injection

**Why**: Unvalidated input is the entry point for injection attacks.

**Search for**:
- SQL Injection: raw queries, string concatenation in SQL
- Command Injection: `exec()`, `system()`, `ProcessBuilder`
- NoSQL Injection: unvalidated MongoDB queries
- XSS: unescaped template output
- XXE: XML parsing without disabled external entities
- Log Injection: user input in log statements

**Also check**: request size limits, content-type validation, file upload limits

**Severity**: CRITICAL (SQL/command injection, XXE) | HIGH (missing validation, no size limits) | MEDIUM (DTO validation gaps) | LOW (log injection)

## Layer 5: Sensitive Data Exposure

**Why**: PII in logs, responses, or error messages violates compliance.

**Scan**:
- Logging: personal data, full request/response bodies, stack traces, credentials
- Error responses: stack traces, internal details
- Response headers: server version disclosure, missing security headers (CSP, HSTS, X-Frame-Options)
- Data objects: sensitive fields in serialization (toString, JSON)
- URLs: sensitive IDs, emails, SSNs in path/query

**Severity**: HIGH (PII logged, stack traces in prod) | MEDIUM (sensitive fields serialized, missing headers) | LOW (server version exposed)

## Layer 6: Configuration Security

**Why**: One misconfiguration can undo all other security measures.

**Audit**:
- Debug mode in production, insecure defaults
- Profile handling (can dev profile activate in prod?)
- CORS: overly permissive origins (`*`), credentials with wildcard
- TLS/HTTPS: redirects, version, cipher config, certificate validation
- Session management: secure config, timeouts, fixation protection
- Debug configs: flags in entrypoints, remote debugging ports

**Severity**: CRITICAL (debug mode in prod) | HIGH (CORS `*` with credentials, insecure TLS) | MEDIUM (profile misconfiguration) | LOW (missing HTTPS redirect if handled by infra)

## Layer 7: Infrastructure Security (IaC & Containers)

**Why**: Secure code on insecure infrastructure is insecure.

**IaC audit**: network security, encryption at-rest/in-transit, IAM/RBAC, secrets management, audit logging, pinned module versions

**Container audit**: pinned base image, USER directive (not root), dropped capabilities, resource limits, health checks, no baked-in secrets

**K8s audit**: security contexts, network policies, resource quotas, minimal RBAC

**Severity**: CRITICAL (root container, exposed debug ports) | HIGH (permissive firewall, missing encryption) | MEDIUM (unpinned modules) | LOW (missing resource limits)

## Layer 8: API & External Communication Security

**Why**: Your service is only as secure as its weakest outbound connection.

**Audit**:
- All outbound URLs use HTTPS, certificate validation enabled
- SSRF: URLs constructed from user input
- Rate limiting, API versioning
- Token/credential handling (secure storage, rotation, not logged)
- Mutual TLS for service-to-service communication

**Severity**: CRITICAL (TLS disabled, SSRF) | HIGH (no timeouts, tokens logged) | MEDIUM (missing mTLS) | LOW (missing rate limiting)

## OWASP Top 10 (2021) Mapping

| OWASP ID | Category | Layers |
|----------|----------|--------|
| A01:2021 | Broken Access Control | 3, 8 |
| A02:2021 | Cryptographic Failures | 2, 6 |
| A03:2021 | Injection | 4 |
| A04:2021 | Insecure Design | 4, 6 |
| A05:2021 | Security Misconfiguration | 6, 7 |
| A06:2021 | Vulnerable Components | 1 |
| A07:2021 | Auth Failures | 3 |
| A08:2021 | Data Integrity Failures | 4 |
| A09:2021 | Logging Failures | 5 |
| A10:2021 | SSRF | 8 |
