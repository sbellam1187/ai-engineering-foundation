---
id: SKILL-resiliency-0001-azure-log-analytics
name: azure-log-analytics
title: "Azure Log Analytics — SRE Copilot for Azure"
version: 2.0.0
status: active
owner: enterprise-architecture
concern: resiliency
created: 2026-04-22
lastUpdated: 2026-04-27
description: >
  SRE Copilot skill for Azure Services. Uses the Azure MCP Server, Azure Log Analytics (KQL),
  Azure Resource Graph, and ARM APIs to proactively analyze logs, detect configuration drift,
  track certificate expiries, assess alerts & incidents, and help engineers debug issues faster.
trigger_keywords:
  - log analytics
  - azure logs
  - app service logs
  - configuration drift
  - azure alerts
  - resiliency analysis
  - analyze logs
  - log issues
  - drift detection
  - certificate expiry
  - cert expiry
  - ssl expiry
  - tls certificate
  - incident analysis
  - outage investigation
  - debug azure
  - troubleshoot app service
  - KQL
  - kusto query
  - resource graph
  - health check
  - app service health
  - SRE
  - site reliability
  - performance anomaly
  - 5xx errors
  - error spikes
  - container crash
  - instance restart
  - cold start
  - scaling issues
  - diagnostic logs
  - azure monitor
  - alert rules
  - action groups
  - mean time to recover
  - MTTR
  - root cause analysis
  - RCA
related:
  laws: []
  adoptions: []
  skills: []
  plugins:
    - azure-mcp-server
---

# Azure App Service Log Analytics

> **SRE Copilot for Azure** — not just log search, but proactive resiliency analysis, drift detection, certificate tracking, incident assessment, and debugging assistance.

## Purpose

Analyze Azure App Service logs, detect configuration drifts, track certificate expiries, review fired alerts and incidents, and surface resiliency issues so teams can prioritize and remediate.

### Core Capabilities

| Capability | Description |
|------------|-------------|
| **Log Analysis** | Query App Service, platform, and HTTP logs via KQL to surface errors, failures, and anomalies |
| **Configuration Drift Detection** | Compare live ARM config against baselines or best-practice defaults |
| **Certificate Expiry Tracking** | Discover TLS/SSL certs bound to the App Service and flag upcoming expiries |
| **Alert & Incident Assessment** | Review fired Azure Monitor alerts, correlate with log findings, assess incident timelines |
| **Resource Graph Exploration** | Use Azure Resource Graph to audit resource topology, tags, SKU, and compliance posture |
| **Debugging Assistance** | Help engineers investigate outages and errors with guided KQL queries and evidence gathering |

### Technology Stack

This skill uses two locally running MCP servers and native Azure APIs:

| Component | Purpose |
|-----------|---------|
| **Azure MCP Server** | Query Log Analytics / App Insights (KQL), list alerts, inspect ARM configuration, Resource Graph queries |
| **Azure Log Analytics / KQL** | Primary query language for all log and metric analysis |
| **Azure Resource Graph** | Cross-subscription resource inventory, topology, and compliance queries |
| **ARM API** | Retrieve live App Service configuration, certificates, networking, and scaling rules |

## Trigger Keywords

`log analytics`, `azure logs`, `app service logs`, `configuration drift`, `azure alerts`,
`resiliency analysis`, `analyze logs`, `drift detection`, `certificate expiry`, `cert expiry`,
`ssl expiry`, `incident analysis`, `outage investigation`, `debug azure`, `troubleshoot app service`,
`KQL`, `resource graph`, `health check`, `SRE`, `performance anomaly`, `5xx errors`,
`error spikes`, `container crash`, `scaling issues`, `root cause analysis`, `RCA`, `MTTR`

---

## Input Expected from User

| Input | Required | Default |
|-------|----------|---------|
| Azure Subscription / Resource Group / App Service name | Yes | — |
| Time range | No | Last 7 days |
| Severity threshold | No | Warning and above |
| Known baseline configuration | No | Best-practice defaults |
| Certificate alert window | No | 30 days before expiry |

---

## Hard Constraints

1. **Never fabricate findings** — every issue must be backed by actual log entries, alert records, cert metadata, or config data retrieved via the Azure MCP server.
2. **Always cite evidence** — include timestamps, log excerpts, alert rule names, or config property names for every finding.
3. **Classify severity** — tag each finding as `Critical`, `High`, `Medium`, or `Low`.
4. **Deduplicate** — group recurring log errors by pattern; do not report the same root cause multiple times.
5. **Read-only operations only** — never perform write, update, delete, or modify operations against Azure resources; this skill is strictly observational.
6. **Never expose secrets** — redact connection string values, keys, tokens, and certificate private keys in all output.

---

## Workflow

### Phase 1: Discovery — Identify Target Resources

1. Use Azure MCP server to list subscriptions (if not provided).
2. Confirm the **resource group** and **App Service** name with the user.
3. Retrieve App Service metadata: runtime stack, SKU/tier, region, deployment slots, current configuration.
4. **Resource Graph inventory** — run an Azure Resource Graph query to capture:
   - Resource type, location, tags, provisioning state
   - Associated resources (App Service Plan, Key Vault, Application Gateway, Front Door, etc.)
   - Networking: VNet integration, private endpoints, hybrid connections

```kusto
resources
| where type == "microsoft.web/sites"
| where name =~ "<app_service_name>"
| project name, resourceGroup, location, sku=properties.sku, kind, tags, properties
```

### Phase 2: Log Analysis

Query the Azure MCP server to pull App Service logs from **Log Analytics / Application Insights**.

#### 2a. Application Errors & Exceptions

```kusto
AppServiceConsoleLogs
| where Level == "Error" or Level == "Critical"
| where TimeGenerated > ago(<time_range>)
| summarize Count=count() by ResultDescription, bin(TimeGenerated, 1h)
| order by Count desc
```

- Group by error message pattern (first 200 chars or exception type).
- For each unique pattern, capture: first occurrence, last occurrence, total count, sample stack trace.

#### 2b. HTTP Failures (5xx / 4xx Spikes)

```kusto
AppServiceHTTPLogs
| where ScStatus >= 500
| where TimeGenerated > ago(<time_range>)
| summarize Count=count() by CsUriStem, ScStatus, bin(TimeGenerated, 1h)
| order by Count desc
```

- Identify endpoints with elevated 5xx rates.
- Flag any endpoint returning > 1 % error rate relative to its total traffic.

#### 2c. Platform & Infrastructure Logs

```kusto
AppServicePlatformLogs
| where Level in ("Error", "Warning")
| where TimeGenerated > ago(<time_range>)
| summarize Count=count() by Message, Level
| order by Count desc
```

- Surface container crashes, instance restarts, health check failures, deployment errors.

#### 2d. Performance Anomalies

```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(<time_range>)
| summarize P95=percentile(TimeTaken, 95), P99=percentile(TimeTaken, 99), AvgTimeTaken=avg(TimeTaken) by CsUriStem
| where P95 > 3000
| order by P95 desc
```

- Flag endpoints where P95 latency exceeds 3 seconds.

#### 2e. Dependency Failures (Application Insights)

```kusto
dependencies
| where success == false
| where timestamp > ago(<time_range>)
| summarize FailureCount=count(), AvgDuration=avg(duration) by target, type, resultCode
| order by FailureCount desc
```

- Identify failing downstream calls (databases, APIs, caches, queues).
- Cross-reference with application errors from 2a.

#### 2f. Exception Hotspots (Application Insights)

```kusto
exceptions
| where timestamp > ago(<time_range>)
| summarize Count=count() by problemId, outerType, outerMessage
| order by Count desc
| take 20
```

- Rank top exception types for guided debugging.

### Phase 3: Configuration Drift Detection

1. Retrieve current App Service configuration via Azure MCP server (ARM API):
   - App settings (key-value pairs — **never include secret values**)
   - Connection strings (names only — **never expose values**)
   - General settings (always-on, ARR affinity, min TLS, HTTPS only, platform version)
   - Scaling rules (min/max instances, scale-out rules)
   - Health check path
   - Diagnostic settings (log retention, log categories enabled)
   - Networking (VNet integration, access restrictions, private endpoints)

2. Compare against **baseline** (if provided by user) or against **best-practice defaults**:

| Setting | Expected | Issue if Different |
|---------|----------|-------------------|
| Always On | `true` | Cold-start latency, idle timeout |
| HTTPS Only | `true` | Insecure traffic allowed |
| Minimum TLS Version | `1.2` | Weak TLS negotiation |
| ARR Affinity | `false` (stateless apps) | Sticky sessions reduce scalability |
| Health Check | configured | No automated instance replacement |
| Diagnostic Logs | enabled | No observability |
| Min Instance Count | `≥ 2` (production) | Single point of failure |
| VNet Integration | configured (if required) | Public egress exposure |
| Access Restrictions | configured (if required) | Unrestricted inbound access |
| Managed Identity | enabled | Credential-based auth risk |

3. **Resource Graph compliance check** — query for tagging gaps, non-standard SKUs, or orphaned resources:

```kusto
resources
| where type == "microsoft.web/sites"
| where resourceGroup =~ "<resource_group>"
| extend alwaysOn = properties.siteConfig.alwaysOn,
         httpsOnly = properties.httpsOnly,
         minTlsVersion = properties.siteConfig.minTlsVersion
| project name, alwaysOn, httpsOnly, minTlsVersion, tags
```

4. Report each drift as a finding with the current value, expected value, and impact.

### Phase 4: Certificate Expiry Tracking

1. Retrieve TLS/SSL certificates bound to the App Service via Azure MCP server (ARM API):

```kusto
resources
| where type == "microsoft.web/certificates"
| where resourceGroup =~ "<resource_group>"
| extend expirationDate = todatetime(properties.expirationDate),
         subjectName = properties.subjectName,
         thumbprint = properties.thumbprint
| project name, subjectName, thumbprint, expirationDate,
          daysUntilExpiry = datetime_diff('day', expirationDate, now())
| order by daysUntilExpiry asc
```

2. Also check **App Service custom domains** for their certificate bindings.

3. Classify certificate findings:

| Days Until Expiry | Severity | Action |
|-------------------|----------|--------|
| ≤ 7 days | **Critical** | Immediate renewal required |
| 8–14 days | **High** | Urgent renewal |
| 15–30 days | **Medium** | Plan renewal |
| 31–60 days | **Low** | Awareness — schedule renewal |
| Expired | **Critical** | Service outage risk — renew NOW |

4. For each certificate, capture:
   - Subject name, thumbprint (last 8 chars only)
   - Issuer
   - Expiration date and days remaining
   - Bound domains
   - Auto-renewal status (if managed certificate)

5. Flag certificates that:
   - Use weak key sizes (< 2048-bit RSA)
   - Are self-signed in production
   - Have no auto-renewal configured
   - Are bound to multiple apps (blast radius)

### Phase 5: Alert & Incident Assessment

1. Query Azure MCP server for fired alerts on the App Service resource in the time range.
2. For each alert, capture:
   - Alert rule name and description
   - Severity (Sev0–Sev4)
   - Fired time and resolved time (if resolved)
   - Condition that triggered it (metric name, threshold, actual value)
3. Group alerts by rule — note repeat-fire patterns that indicate unresolved issues.
4. Cross-reference with Phase 2 log findings to link alerts to root causes.
5. **Incident timeline reconstruction** — for Sev0/Sev1 alerts, build a chronological timeline:

```
[timestamp] Alert fired: <rule name> — <condition>
[timestamp] Log error spike detected: <pattern>
[timestamp] Platform event: <instance restart / deployment / scaling>
[timestamp] Alert resolved: <rule name>
```

6. Calculate incident metrics:
   - **Time to Detect (TTD)** — gap between first log error and alert firing
   - **Time to Resolve (TTR)** — gap between alert fired and resolved
   - **Blast Radius** — number of affected endpoints / users (from HTTP logs)
7. Flag **missing alert coverage** — identify conditions observed in logs (e.g., 5xx spikes, high latency) for which no alert rule exists.

### Phase 6: Findings Summary & Triage

Compile all findings into a structured report:

```markdown
## Findings Summary — [App Service Name]
**Time Range:** [start] → [end]
**Total Findings:** [count]

### 🔴 Critical (must fix)
1. [Finding title] — [evidence summary]

### 🟠 High
1. [Finding title] — [evidence summary]

### 🟡 Medium
1. [Finding title] — [evidence summary]

### 🟢 Low
1. [Finding title] — [evidence summary]

### 📊 Incident Metrics
- Mean Time to Detect: [value]
- Mean Time to Resolve: [value]
- Alert Coverage Gaps: [count]

### 🔐 Certificate Status
- Expiring within 30 days: [count]
- Expired: [count]
- Weak / Self-signed: [count]
```

**Present this summary to the user** for review and prioritization.

---

## Output

1. **Findings Report** — Markdown summary presented to the user for review.
2. **Incident Timeline** — Chronological event reconstruction for Sev0/Sev1 incidents.
3. **Certificate Status Report** — Expiry dashboard for all bound certificates.

---

## When to Use This Skill

- User asks to **analyze App Service logs** or **check for errors**
- User asks to **detect configuration drift** in Azure App Service
- User asks to **review Azure alerts** for an application
- User asks to **check certificate expiry** or **TLS status**
- User asks to **investigate an incident** or **outage**
- User asks to **debug an Azure App Service issue**
- User wants a **resiliency health check** for an Azure App Service
- User asks for **root cause analysis (RCA)** after an incident
- User wants to **reduce MTTR** or improve alert coverage

---

## Best Practices

### ✅ DO

- **Always use the Azure MCP server** to query live data — never guess at log contents
- **Use KQL** for all Log Analytics and Application Insights queries
- **Use Azure Resource Graph** for cross-resource topology and compliance checks
- **Deduplicate findings** — group recurring errors by root cause pattern
- **Cite timestamps and log excerpts** in every finding
- **Redact secrets** — never include connection string values, keys, or tokens
- **Cross-reference** log errors with alerts and cert status to provide richer context
- **Build incident timelines** for Sev0/Sev1 events to accelerate RCA
- **Flag missing alert coverage** — proactively recommend alert rules for unmonitored conditions

### ❌ DON'T

- **Don't fabricate log entries** or invent error patterns not found in data
- **Don't expose secret values** from app settings, connection strings, or certificate private keys
- **Don't ignore low-severity drift** — surface it, let the user decide priority
- **Don't skip certificate checks** — expiry is a top cause of preventable outages
- **Don't limit analysis to a single data source** — correlate logs, alerts, config, and certs

---

## Quick Examples

**User says:** "Analyze the logs for my App Service `api-prod-east` in the last 3 days"

→ Execute Phases 1–6:
1. Connect via Azure MCP, pull logs for `api-prod-east` (last 3 days)
2. Analyze errors, HTTP failures, platform issues, performance, dependency failures
3. Check configuration drift
4. Check certificate expiries
5. Review fired alerts and build incident timelines
6. Present findings summary

**User says:** "Check for config drift on `web-frontend-prod`"

→ Execute Phase 1 + Phase 3 + Phase 6:
1. Retrieve current config via Azure MCP and Resource Graph
2. Compare against best-practice baseline
3. Present drift findings

**User says:** "Are any certs expiring soon on our production apps?"

→ Execute Phase 1 + Phase 4 + Phase 6:
1. Discover target resources via Resource Graph
2. Check certificate expiries across all bound certs
3. Present certificate status report with severity classification

**User says:** "We had an outage last night on `order-service`. Pull the logs."

→ Execute full workflow (Phases 1–6):
1. Pull error/platform logs for the outage window
2. Identify root cause patterns and dependency failures
3. Build incident timeline, calculate TTD/TTR
4. Check if alerts fired and correlate
5. Present findings with severity

**User says:** "Debug why `checkout-api` is slow — P95 latency spiked"

→ Execute Phase 1 + Phase 2d + Phase 2e + Phase 5 + Phase 6:
1. Query performance anomaly logs and dependency failures
2. Cross-reference with fired alerts
3. Present root cause hypothesis with supporting evidence

---

## Checklist

After executing this skill, verify:

- [ ] All findings are backed by actual Azure data (logs, configs, alerts, certs)
- [ ] No secrets or sensitive values are exposed in findings or stories
- [ ] Findings are deduplicated and grouped by root cause
- [ ] Each finding has severity, evidence, and timestamps
- [ ] Certificate expiry status is checked and reported
- [ ] Incident timelines are built for Sev0/Sev1 events
- [ ] Missing alert coverage is flagged
