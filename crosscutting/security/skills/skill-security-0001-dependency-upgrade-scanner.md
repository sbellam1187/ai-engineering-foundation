---
id: SKILL-security-0001-dependency-upgrade-scanner
name: dependency-upgrade-scanner
title: Dependency Upgrade Scanner
version: 1.0.0
status: active
owner: enterprise-architecture
concern: security
created: 2026-03-23
lastUpdated: 2026-04-29
description: Scans pom.xml (or build.gradle / package.json) and produces a full dependency upgrade report. For every dependency it identifies the current version, latest stable version, upgrade type (patch / minor / major), known CVEs, breaking-change risk, and a prioritised action plan. Works with Maven, Gradle, and npm.
trigger_keywords:
  - dependencies
  - dependency
  - upgrade
  - outdated
  - CVE
  - vulnerability
  - scan dependencies
  - check dependencies
  - update dependencies
  - dependency audit
related:
  laws:
    - LAW-security-0001-security-by-design
  adoptions: []
  skills: []
  plugins: []
---

# Dependency Upgrade Scanner

## Skill: Dependency Upgrade Scanner

### Purpose
Scan the project's dependency manifest (`pom.xml`, `build.gradle`, or `package.json`), compare
every dependency against its latest published version, assess risk, flag CVEs, and produce a
prioritised upgrade action plan — all without leaving the IDE.

### Trigger Keywords
`dependencies`, `dependency`, `upgrade`, `outdated`, `CVE`, `vulnerability`, `scan dependencies`

### Scope / What to produce
- Dependency upgrade report in markdown format
- CVE vulnerability analysis
- Prioritised action plan for upgrades
- Version range audit (reproducibility check)
- BOM-managed dependency identification
- Plugin version analysis

### Hard constraints (must follow)
1. **Do not modify dependency files.** Only produce analysis and reports.
2. **Skip internal dependencies** — Organisation artifacts (e.g. `com.[org].*`) cannot be checked against public registries.
3. **Ignore pre-release versions** — Do not recommend `-alpha`, `-beta`, `-RC`, `-M` unless user is already on one.
4. **Prioritise CVE remediation** — Security vulnerabilities always come first in action plan.
5. **Respect BOM management** — Identify dependencies managed by parent BOM; don't flag as outdated incorrectly.
6. **One manifest per invocation** — If multiple manifests exist, ask user which to scan or scan all sequentially.
7. **Dynamic grouping** — Group alerts/dependencies by normalized Maven `groupId`; any groupId with 2+ alerts is flagged as an umbrella upgrade opportunity.
8. **No hardcoded libraries** — Never hardcode a list of library names for grouping or detection. Use the `groupId` to drive all grouping logic dynamically.

### Input expected from user
- Path to dependency manifest (`pom.xml`, `build.gradle`, `package.json`, etc.)
- Ecosystem type (Maven, Gradle, npm, pip) — auto-detect if possible
- Severity threshold (optional, default: all)
- Whether to include transitive dependencies (optional, default: true)

### Output format
- Save report to: `docs/reports/dependency-upgrade-report-{YYYY-MM-DD}.md`
- If `docs/reports/` doesn't exist, create it
- Report includes: Summary dashboard, Detailed table, CVE section, Action plan

---

## How to Activate This Skill

**Auto-trigger (easiest):**
- "Scan dependencies for outdated packages"
- "Check for CVEs in our dependencies"
- "What dependencies need upgrading?"
- "Audit pom.xml for vulnerable dependencies"
- "Show me outdated dependencies"

**Explicit reference:**
- "Use dependency-upgrade-scanner skill to audit pom.xml"
- "Following dependency-upgrade-scanner, check for upgrades"

---

## When to Use This Skill

- User asks to **scan**, **check**, or **audit** dependencies for upgrades
- User asks "what dependencies are outdated?" or "what needs upgrading?"
- User asks to **create an upgrade plan** or **dependency report**
- Before a sprint to plan dependency-upgrade work
- Before a release to verify no known CVEs ship to production
- After Dependabot PRs pile up and the team needs a single prioritised view
- User says "dependency health check", "version scan", "upgrade roadmap"

---

## Supported Ecosystems

| Manifest | Ecosystem | Registry |
|----------|-----------|----------|
| `pom.xml` | Maven | Maven Central, private Cloudsmith/Artifactory |
| `build.gradle` / `build.gradle.kts` | Gradle | Maven Central, private |
| `package.json` | npm | npmjs.org, private |
| `requirements.txt` / `pyproject.toml` | pip | PyPI |

> Focus on one manifest per invocation. If multiple exist, ask the user which to scan or scan all.

---

## Step-by-Step Execution

### Step 1 — Parse the Manifest

Read the dependency file and extract **every** dependency with:

1. **GroupId / Package name**
2. **ArtifactId**
3. **Current version** (resolve property placeholders like `${lombok.version}`)
4. **Scope** (compile, test, provided, runtime, plugin, parent)
5. **Whether version is managed by parent BOM** (e.g. Spring Boot parent manages Jackson, Spring modules)

#### Maven-Specific Parsing Rules

- Resolve `<properties>` → actual version values
- Identify **parent BOM**-managed versions (no explicit `<version>` tag = managed by parent)
- Parse `<dependencyManagement>` sections
- Parse `<build><plugins>` and `<reporting><plugins>` for plugin versions
- Handle version ranges like `[2.10.0,)` — note the minimum and flag that the upper bound is open
- Identify `<exclusions>` — these often hint at transitive CVEs or conflicts

### Step 2 — Classify Each Dependency

For every dependency, determine:

| Classification | Meaning | Examples |
|----------------|---------|----------|
| **Parent / BOM** | Framework version that manages many transitive deps | `spring-boot-starter-parent` |
| **Direct - Explicit** | Version declared in `<properties>` or inline | `httpclient5`, `lombok`, `gson` |
| **Direct - BOM-Managed** | No version tag; version comes from parent BOM | `jackson-module-jsonSchema`, `jakarta.servlet-api` |
| **Plugin** | Build/reporting plugins | `jacoco-maven-plugin`, `maven-checkstyle-plugin` |
| **Internal** | Organisation-internal artifacts (skip public registry lookup) | `com.[org]:internal-lib`, `com.[org].tools:coding-standards` |

### Step 2b — Identify Umbrella Upgrade Opportunities

After classifying each dependency, group them by **normalized Maven `groupId`** to identify umbrella upgrade opportunities. The grouping is **dynamic** — no hardcoded library lists.

**GroupId normalization rules:**

| Raw groupId | Normalized Key | Display Name |
|-------------|---------------|--------------|
| `org.springframework.boot` | `org.springframework` | Spring Framework |
| `org.springframework.security` | `org.springframework` | Spring Framework |
| `com.fasterxml.jackson.core` | `com.fasterxml.jackson` | Jackson |
| `com.fasterxml.jackson.datatype` | `com.fasterxml.jackson` | Jackson |
| `tools.jackson.core` | `tools.jackson` | Jackson |
| `io.netty` | `io.netty` | Netty |
| `org.apache.tomcat.embed` | `org.apache.tomcat` | Tomcat |
| `org.yaml` | `org.yaml` | SnakeYAML |
| *(any groupId)* | *(first 2–3 segments)* | *(auto-derived)* |

**Rules:**
1. Keep the first **2–3 segments** of the groupId (e.g., `com.fasterxml.jackson.core` → `com.fasterxml.jackson`)
2. If **2+ alerts** share the same normalized key, flag as an **umbrella upgrade opportunity**
3. For well-known groups, derive the Maven property name (e.g., `jackson-bom.version`); for unknown groups, derive from the last segment (`<lastSegment.version>`)

**Output:** A "suspected umbrella groups" section in the report listing each group, its alert count, and the recommended property/BOM to upgrade.

### Step 3 — Look Up Latest Versions

For each **non-internal** dependency:

1. Query **Maven Central** (https://search.maven.org/solrsearch/select?q=g:{groupId}+AND+a:{artifactId}&rows=1&wt=json)
   or the appropriate registry for the ecosystem.
2. Record the **latest stable release** (ignore `-alpha`, `-beta`, `-RC`, `-M` milestones unless user is already on one).
3. If the user has a private registry (like Cloudsmith in this project), note that the latest version may differ — flag it.

### Step 4 — Determine Upgrade Type

Compare current → latest using semver:

| Type | Definition | Risk | Example |
|------|-----------|------|---------|
| **Patch** | `x.y.Z` changed | LOW — bug fixes only | `1.18.32` → `1.18.36` |
| **Minor** | `x.Y.z` changed | MEDIUM — new features, backward-compatible | `5.5` → `5.6` |
| **Major** | `X.y.z` changed | HIGH — possible breaking changes | `3.0.1` → `4.0.0` |
| **Current** | Already on latest | NONE | — |

### Step 5 — CVE Check

For each dependency at its **current** version:

1. Check for known CVEs using the GitHub Advisory Database, NVD, or OSV.
2. Report: CVE ID, severity (CRITICAL/HIGH/MEDIUM/LOW), and minimum fixed version.
3. Flag if the upgrade to latest resolves the CVE.

> Use the `validate_cves` tool if available, or instruct the user to cross-reference with
> Dependabot alerts / OWASP dependency-check.

### Step 6 — Assess Breaking-Change Risk

For each upgrade, assess risk:

| Signal | Risk Level |
|--------|-----------|
| Major version bump | HIGH — read changelog/migration guide |
| Dependency has known breaking changes documented | HIGH |
| Spring Boot parent upgrade (manages 100+ transitive deps) | HIGH — test everything |
| Minor version of mature library (e.g., Apache Commons) | LOW |
| Patch version | VERY LOW |
| Library is excluded/overridden in pom (hints at past conflicts) | MEDIUM — verify exclusion still needed |

### Step 7 — Generate the Report

Produce a **structured markdown report** with these sections:

---

## Report Format

### Header

```markdown
# Dependency Upgrade Report
**Project**: {project.name}
**Scanned**: {manifest file}
**Date**: {current date}
**Total Dependencies**: {count}
**Outdated**: {count} | **Current**: {count} | **Internal (skipped)**: {count}
```

### Summary Dashboard

```markdown
## Summary

| Status | Count |
|--------|-------|
| 🔴 CRITICAL (CVE or 2+ major versions behind) | X |
| 🟠 MAJOR upgrade available | X |
| 🟡 MINOR upgrade available | X |
| 🟢 PATCH upgrade available | X |
| ✅ UP-TO-DATE | X |
| ⬜ INTERNAL (not checked) | X |
| 📌 BOM-MANAGED (upgrade parent to update) | X |
```

### Detailed Table

```markdown
## Dependency Details

| # | Dependency | Current | Latest | Type | Scope | CVEs | Risk | Action |
|---|-----------|---------|--------|------|-------|------|------|--------|
| 1 | org.springframework.boot:spring-boot-starter-parent | 4.0.2 | 4.0.3 | PATCH | parent | None | LOW | Upgrade parent |
| 2 | org.projectlombok:lombok | 1.18.32 | 1.18.38 | PATCH | provided | None | LOW | Bump property |
| 3 | org.springdoc:springdoc-openapi-starter-webmvc-ui | 3.0.1 | 3.1.0 | MINOR | compile | None | MED | Test Swagger UI |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |
```

### BOM-Managed Dependencies Section

```markdown
## BOM-Managed Dependencies (version controlled by parent)

These dependencies do NOT have an explicit version in your pom.xml.
Their version is determined by `spring-boot-starter-parent:4.0.2`.
Upgrading the parent will automatically upgrade these.

| Dependency | Version via BOM | Latest if Standalone |
|-----------|----------------|---------------------|
| jakarta.servlet:jakarta.servlet-api | (from parent) | — |
| com.fasterxml.jackson.module:jackson-module-jsonSchema | (from parent) | — |
| com.fasterxml.jackson.datatype:jackson-datatype-jsr310 | (from parent) | — |
| org.springframework.boot:spring-boot-configuration-processor | (from parent) | — |
```


### Umbrella Upgrade Opportunities

```markdown
## 🔄 Umbrella Upgrade Opportunities

Dependencies grouped by normalized Maven groupId. Groups with 2+ alerts/outdated
dependencies may be resolved by a single parent BOM or property upgrade.

| Group | Display Name | Alert Count | Recommended Property | Affected Packages |
|-------|-------------|-------------|---------------------|-------------------|
| `org.springframework` | Spring Framework | 4 | `spring-boot-starter-parent` | spring-web, spring-security-core, ... |
| `com.fasterxml.jackson` | Jackson | 3 | `jackson-bom.version` | jackson-databind, jackson-core, ... |
| `io.netty` | Netty | 2 | `netty.version` | netty-handler, netty-codec, ... |

> **Dynamic detection**: This table is generated automatically by normalizing each dependency's
> `groupId` to its first 2–3 segments. No hardcoded library lists are used — any groupId family
> with 2+ alerts appears here.
```

### Plugin Upgrade Details

```markdown
## Plugin Upgrades

| Plugin | Current | Latest | Risk |
|--------|---------|--------|------|
| spring-boot-maven-plugin | 4.0.1 | 4.0.2 | LOW — align with parent |
| jacoco-maven-plugin | 0.8.11 | 0.8.13 | LOW |
| maven-checkstyle-plugin | 3.6.0 | 3.7.0 | LOW |
| maven-pmd-plugin | 3.28.0 | 3.29.0 | LOW |
| maven-deploy-plugin | 3.1.1 | 3.1.3 | LOW |
| azure-webapp-maven-plugin | 2.14.1 | 2.15.0 | MED — check Azure SDK compat |
| maven-site-plugin | 4.0.0-M9 | 4.0.0 | LOW — milestone to GA |
```

### CVE Section (if any found)

```markdown
## 🔴 Security Vulnerabilities

| Dependency | Current | CVE | Severity | Fixed In | Action |
|-----------|---------|-----|----------|----------|--------|
| example:lib | 1.2.3 | CVE-2025-XXXX | HIGH | 1.2.5 | Upgrade immediately |
```

### Exclusions Audit

```markdown
## Exclusions Audit

Your pom.xml has the following exclusions. These often exist because of past CVEs
or dependency conflicts. After upgrading, verify whether each exclusion is still needed.

| Parent Dependency | Excluded | Reason (from pom comment) | Still Needed? |
|-------------------|----------|---------------------------|---------------|
| spring-boot-starter-actuator | org.yaml:snakeyaml | Blackduck alert | CHECK after parent upgrade |
| spring-boot-starter-test | net.minidev:json-smart | Dependabot US1637901 | CHECK after parent upgrade |
| spring-boot-starter-test | junit:junit | Migrated to JUnit 5 | YES — keep excluding JUnit 4 |
| springdoc-openapi-starter | org.yaml:snakeyaml | Blackduck alert | CHECK after parent upgrade |
| springdoc-openapi-starter | commons-lang3 | Dependabot US1955510 | CHECK — commons-lang3 declared separately |
```

### Version Range Audit

```markdown
## ⚠️ Version Ranges

Version ranges make builds non-reproducible. The same pom.xml can resolve to
different versions on different days.

| Dependency | Range | Resolved Min | Recommendation |
|-----------|-------|-------------|----------------|
| com.google.code.gson:gson | [2.10.1,) | 2.10.1 | Pin to exact: 2.12.1 |
| org.xmlunit:xmlunit-core | [2.10.0,) | 2.10.0 | Pin to exact: 2.10.0 |
```

### Prioritised Action Plan

```markdown
## 📋 Recommended Upgrade Order

Upgrades should be done in this order to minimise risk and catch issues early.
Each step should be a separate commit with full test run.

### 🔴 Immediate (this sprint)
1. **Fix CVEs**: [list any CVE-affected dependencies]
2. **Pin version ranges**: Replace `[x.y.z,)` with exact versions
3. **Align plugin with parent**: `spring-boot-maven-plugin` 4.0.1 → 4.0.2

### 🟡 Short Term (next 2 sprints)
4. **Patch upgrades** (lowest risk, highest count):
   - lombok 1.18.32 → 1.18.38
   - jacoco 0.8.11 → 0.8.13
   - maven-checkstyle-plugin 3.6.0 → 3.7.0
   - [etc.]
5. **Minor upgrades** (test after each):
   - springdoc-openapi 3.0.1 → 3.1.x — test Swagger UI loads
   - [etc.]

### 🟠 Planned (next quarter)
6. **Major upgrades** (dedicated spike):
   - [any major version jumps]
7. **Parent BOM upgrade** (if new Spring Boot version):
   - Spring Boot 4.0.2 → 4.1.x — full regression test
   - Re-evaluate all exclusions after parent upgrade

### 🧹 Cleanup (after all upgrades)
8. **Remove stale exclusions** that are no longer needed
9. **Remove dependabot override versions** (assertj, xmlunit) if parent now ships safe versions
10. **Update Dependabot config** — consider allowing patch updates (`ignore` currently blocks them)
```

---

## Special Handling

### Internal Dependencies
Dependencies with organisation groupIds (e.g. `com.[org]`, `com.[org].tools`) cannot be
checked against Maven Central. For these:
- Note them as **INTERNAL — skipped**
- Suggest the user check their private artifact repository (Cloudsmith)
- Flag the internal dependency version so the user can manually verify

### Dependabot Interaction
This project has Dependabot configured (`dependabot.yml`) with:
- Daily Maven scans
- **Patch updates are ignored** (`ignore: version-update:semver-patch`)
- This means Dependabot will NOT alert on patch upgrades

**Recommendation**: This skill fills the gap — it reports ALL upgrades including patches.
The user should consider allowing patch updates in Dependabot or using this skill's report
as the monthly patch-upgrade driver.

### Spring Boot Parent BOM
When the parent is `spring-boot-starter-parent`, upgrading it changes **dozens** of
transitive dependency versions. The report must:
1. List what the parent manages (BOM-managed section)
2. Warn that upgrading the parent is a **big-bang operation**
3. Recommend a dedicated branch + full regression test for parent upgrades
4. Check if any explicit version overrides in `<properties>` conflict with the new parent

### Version Ranges
Flag any dependency using Maven version ranges (`[x,)`, `(,y]`, etc.) as a
**reproducibility risk**. Recommend pinning to exact versions.

### Milestone / Pre-release Versions
If the project uses a milestone version (e.g. `maven-site-plugin:4.0.0-M9`):
- Check if a GA (General Availability) release now exists
- Recommend upgrading from milestone to GA

---

## Standard Prompt (copy/paste)

You are the **Dependency Upgrade Scanner skill**.  
Scan the specified dependency manifest and produce a comprehensive upgrade report.  
Follow constraints in this skill:
- Do not modify dependency files
- Skip internal/organisation dependencies
- Prioritise CVE remediation in action plan
- Identify BOM-managed dependencies correctly
Output the report in markdown format and save to `docs/reports/`.

---

## Checklist

After generating the report, verify:
- [ ] All `<properties>` values were correctly resolved
- [ ] BOM-managed dependencies are identified (no false "outdated" flags)
- [ ] Internal dependencies are marked as skipped, not flagged as errors
- [ ] Version ranges are flagged as reproducibility risk
- [ ] Exclusions are listed with comments from pom.xml
- [ ] Plugin versions are included (not just dependencies)
- [ ] CVE section is populated (if vulnerabilities found)
- [ ] Umbrella upgrade opportunities are detected (groupId families with 2+ alerts)
- [ ] Action plan is ordered by risk (CVE → pin ranges → patch → minor → major → parent)
- [ ] Report saved to `docs/reports/dependency-upgrade-report-{YYYY-MM-DD}.md`

---

## Example Invocations

**Basic scan**:
```
"Scan my pom.xml for outdated dependencies"
```

**Focused on security**:
```
"Check my dependencies for CVEs and tell me what to upgrade"
```

**Upgrade planning**:
```
"Create a dependency upgrade plan for the next sprint"
```

**Post-Dependabot triage**:
```
"I have 15 Dependabot PRs open. Give me a prioritized list of what to merge first"
```

**Pre-release audit**:
```
"We're releasing v5.1 next week. Are all our dependencies on safe, stable versions?"
```

---

## Variants

### Variant A — Security-focused (CVE only)
If user only wants security vulnerabilities:
- Skip version comparison for non-CVE dependencies
- Focus report on CVE section and immediate remediation
- Use `validate_cves` tool for comprehensive CVE lookup

### Variant B — Pre-release audit
If user is preparing for a release:
- Flag any dependency on milestone/pre-release versions
- Highlight version ranges as blocking issues
- Produce a go/no-go summary for release readiness

### Variant C — Sprint planning
If user wants to plan upgrade work:
- Group upgrades by estimated effort (small/medium/large)
- Suggest which upgrades can be batched together
- Estimate test scope for each upgrade group
