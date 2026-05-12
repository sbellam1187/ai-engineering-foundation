---
name: mezmo-log-analysis
description: Analyze logs using Mezmo CLI for production troubleshooting, distributed tracing, and CI/CD automation. Use when the user asks to search logs, tail logs, troubleshoot production issues, trace requests across microservices, or automate log analysis in pipelines.
---

# Mezmo Log Analysis Skill

## Purpose

Analyze application logs using the Mezmo CLI (`mzm`) for production troubleshooting, distributed tracing, and CI/CD automation.

## Inputs

- **Operation**: tail (real-time) | search (historical) | trace (cross-service) | automate (CI/CD)
- **Filters**: app name, log level, time range, correlation ID, AAdvantage number, session ID
- **Output format**: text (default) | json (for automation)

## Outputs

- Filtered log output (text or JSON)
- Error counts and pattern summaries
- Cross-service trace timelines
- Pass/fail deployment validation results

## Steps

1. **Identify operation** from user request (tail, search, trace, or automate)
2. **Construct query** using appropriate filters (app, level, time range, identifiers)
3. **Execute** via `mzm log tail` (real-time) or `mzm log search` (historical)
4. **Parse results** — use `--output json | jq` for structured analysis
5. **Present** findings to user with timestamps, service attribution, and error summaries

## Standards & Constraints

| Rule | Detail |
|------|--------|
| Always specify time range | Use `--from` to avoid expensive unbounded queries |
| Use specific filters | Combine `--app`, `--level`, and query terms to reduce noise |
| Never hardcode service names | Discover services dynamically from log data |
| Secure access keys | Use `$MZM_ACCESS_KEY` from environment/secrets — never hardcode |
| JSON for automation | Use `--output json` when scripting or piping to `jq` |
| Appropriate limits | Use `--limit` to control result size |

## Quick Command Reference

| Command | Purpose | Example |
|---------|---------|---------|
| `mzm log tail` | Stream real-time logs | `mzm log tail --app my-service --level error` |
| `mzm log search` | Query historical logs | `mzm log search "level:error" --from "1h ago"` |
| `mzm get views` | List saved views | `mzm get views` |
| `mzm create` | Create resources | `mzm create -f view.yaml` |

## Query Syntax

```bash
# Boolean operators
mzm log search "level:error AND app:my-service" --from "1h ago"
mzm log search "status:500 OR status:502" --from "30m ago"
mzm log search "level:error NOT app:batch-job" --from "1h ago"

# Wildcards and phrases
mzm log search "message:*timeout*" --from "1h ago"
mzm log search "message:\"connection refused\"" --from "2h ago"

# Trace by correlation identifier
mzm log search "correlation-id:req-abc-123" --from "24h ago"
mzm log search "aadvantage-number:4R3TD94" --from "24h ago"
```

## Prerequisites

```bash
# Install
curl -sSL https://get.mezmo.com/cli | sh

# Authenticate
export MZM_ACCESS_KEY="your-access-key-here"

# Optional: set default account
mzm config set account YOUR_ACCOUNT_ID
```

Requires network access to `api.mezmo.com` and `tail.mezmo.com`.

## References

| File | Purpose |
|------|---------|
| [references/examples-and-scripts.md](references/examples-and-scripts.md) | Detailed examples, CI/CD scripts, cross-service tracing workflows, troubleshooting |
