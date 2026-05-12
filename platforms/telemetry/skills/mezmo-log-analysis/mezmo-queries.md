# Mezmo Query Reference

A collection of reusable Mezmo CLI queries for troubleshooting production issues across microservices.

## Setup

```bash
export MZM_ACCESS_KEY="your-mezmo-access-key"
export MZM_APP="your-service-name"    # e.g. entitlements, payment-service
export MZM_ENV="production"           # production, staging, dev

# Verify
mzm version
```

---

## Quick Reference

| Goal | Command |
|------|---------|
| Live errors | `mzm log tail --app $MZM_APP --level error` |
| Last-hour errors | `mzm log search "level:error AND app:$MZM_APP" --from "1h ago"` |
| Trace request | `mzm log search "correlation-id:abc-123" --from "24h ago"` |
| 5xx errors | `mzm log search "status:[500 TO 599] AND app:$MZM_APP" --from "1h ago"` |


---

## Real-Time Monitoring

```bash
# Errors and warnings
mzm log tail --app "$MZM_APP" --level error --level warn

# Specific pod/host
mzm log tail --app "$MZM_APP" --host prod-pod-xyz --level error

# Custom query
mzm log tail --app "$MZM_APP" --query "env:${MZM_ENV}"
```

---

## Historical Search

```bash
# Last 1 hour
mzm log search "level:error AND app:${MZM_APP}" --from "1h ago"

# Custom window
mzm log search "level:error AND app:${MZM_APP}" \
  --from "2026-02-28T10:00:00Z" --to "2026-02-28T11:00:00Z"

# JSON output for scripting
mzm log search "level:error AND app:${MZM_APP}" \
  --from "1h ago" --output json | jq '.[] | {time: .timestamp, msg: .message}'
```

---

## Error Patterns

```bash
# 5xx HTTP errors
mzm log search "status:[500 TO 599] AND app:${MZM_APP}" --from "30m ago"

# Exceptions
mzm log search "message:*Exception* AND level:error AND app:${MZM_APP}" --from "2h ago"

# Timeouts
mzm log search "(message:*timeout* OR message:*timed out*) AND app:${MZM_APP}" --from "1h ago"

# Validation errors
mzm log search "(message:*validation* OR status:400) AND app:${MZM_APP}" --from "30m ago"

# Auth failures
mzm log search "(status:401 OR status:403) AND app:${MZM_APP}" --from "1h ago"

# Database / connectivity
mzm log search "(message:*connection refused* OR message:*database*) AND level:error AND app:${MZM_APP}" --from "1h ago"
```

---

## Service Discovery

Before tracing across services, discover which services are actually logging — never hardcode service names.

```bash
# Discover all services with errors in the last hour
mzm log search "level:error" --from "1h ago" --limit 200 --output json 2>/dev/null | \
  jq -rs '[.[] | ._app] | unique[]'

# Broader discovery: any log level (useful when errors are sparse)
mzm log search "*" --from "24h ago" --limit 200 --output json 2>/dev/null | \
  jq -rs '[.[] | ._app] | unique[]'

# Store discovered services for use in loops
SERVICES=$(mzm log search "level:error" --from "1h ago" --limit 200 --output json 2>/dev/null | \
  jq -rs '[.[] | ._app] | unique[]')

# Fan out across all discovered services
echo "$SERVICES" | while read -r SERVICE; do
  echo "=== ${SERVICE} ==="
  mzm log search "level:error AND app:${SERVICE}" --from "1h ago" \
    --output json | jq -r '.[] | "[\(._ts | todate)] \(._line | .[0:150])"' | head -5
done
```

---

## Request Tracing

### By Correlation ID (cross-service, all apps)
```bash
# Trace correlation ID across all services — no --app filter
mzm log search "correlation-id:${CORRELATION_ID}" --from "24h ago" --output json > trace.json

# Chronological flow with service attribution
jq -r 'sort_by(.timestamp) | .[] | "[\(.timestamp)] [\(.level)] [\(.app // "?")] — \(.message)"' trace.json

# Error summary by service
jq -r '[.[] | select(.level == "error")] | group_by(.app) | .[] |
  "\(.[0].app): \(length) error(s)"' trace.json
```

### By AAdvantage Number (AA loyalty — inline in log messages)
```bash
# AAdvantage number appears as "aadvantage-number: XXXXX - " in log lines
AA_NUMBER="4R3TD94"

# Step 1: Discover which services have logs for this member
SERVICES=$(mzm log search "aadvantage-number:${AA_NUMBER}" \
  --from "24h ago" --limit 200 --output json 2>/dev/null | \
  jq -rs '[.[] | ._app] | unique[]')

echo "Services with logs for AA# ${AA_NUMBER}: $(echo "$SERVICES" | tr '\n' ' ')"

# Step 2: Fan out to each discovered service
echo "$SERVICES" | while read -r SERVICE; do
  echo "=== ${SERVICE} ==="
  mzm log search "aadvantage-number:${AA_NUMBER}" \
    --app "${SERVICE}" --from "24h ago" --output json | \
    jq -r 'sort_by(._ts) | .[] | "[\(._ts | todate)] [\(.level)] \(._line | .[0:150])"'
  echo ""
done

# All services combined (no app filter — single query)
mzm log search "aadvantage-number:${AA_NUMBER}" --from "24h ago" --output json | \
  jq -rs 'sort_by(._ts) | .[] | "[\(._ts | todate)] [\(._app // "?")] \(._line | .[0:150])"'
```

### By Session ID (browser session, SPA apps)
```bash
SESSION_ID="ac7d3283-4cba-427f-83c1-f4a905b54adf"

# All activity for this session (sessionId from _meta.sessionId)
mzm log search "sessionId:${SESSION_ID}" --from "2h ago" --output json | \
  jq -r 'sort_by(.timestamp) | .[] | "[\(.timestamp)] [\(.level)] [\(.app // "?")] \(.message)"'

# Errors only
mzm log search "sessionId:${SESSION_ID}" --from "2h ago" --output json | \
  jq -r '.[] | select(.level == "error") | "[\(.timestamp)] \(.message)"'
```

### By Transaction ID
```bash
TXN_ID="txn-987-def"
mzm log search "transaction-id:${TXN_ID}" --from "24h ago" --output json | \
  jq -r 'sort_by(.timestamp) | .[] | "[\(.timestamp)] [\(.level)] [\(.app // "?")] \(.message)"'
```

### Time-Anchored Multi-Service Fan-Out
```bash
# Set incident window
START_TIME="2026-02-28T22:30:00Z"
END_TIME="2026-02-28T22:40:00Z"

# Discover services active in that window
SERVICES=$(mzm log search "level:error" \
  --from "${START_TIME}" --to "${END_TIME}" \
  --limit 200 --output json 2>/dev/null | \
  jq -rs '[.[] | ._app] | unique[]')

echo "Services with errors in window: $(echo "$SERVICES" | tr '\n' ' ')"

# Fan out to each discovered service
echo "$SERVICES" | while read -r SERVICE; do
  echo "=== ${SERVICE} ==="
  mzm log search "level:error AND app:${SERVICE}" \
    --from "${START_TIME}" --to "${END_TIME}" \
    --output json | jq -r '.[] | "[\(._ts | todate)] \(._line | .[0:150])"' | head -10
done
```

### Combined Identifier Query
```bash
# Use OR to correlate across multiple identifiers simultaneously
mzm log search "correlation-id:${CORRELATION_ID} OR aadvantage-number:${AA_NUMBER}" \
  --from "1h ago" --output json | \
  jq -r 'sort_by(.timestamp) | .[] |
    "[\(.timestamp)] [\(.level | ascii_upcase)] [\(.app // "?")] \(.message)"'
```

---

## Performance

```bash
# Slow requests (if response_time field is present)
mzm log search "response_time:[5000 TO *] AND app:${MZM_APP}" --from "30m ago"

# OOM / memory issues
mzm log search "message:*OutOfMemoryError* AND app:${MZM_APP}" --from "24h ago"

# Thread pool exhaustion
mzm log search "message:*thread* AND message:*exhausted* AND app:${MZM_APP}" --from "1h ago"
```

---

## Error Rate Analysis

```bash
# Count errors by hour
mzm log search "level:error AND app:${MZM_APP}" --from "24h ago" --output json | \
  jq -r '.[].timestamp' | cut -dT -f2 | cut -d: -f1 | sort | uniq -c

# Deduplicated error patterns
mzm log search "level:error AND app:${MZM_APP}" --from "1h ago" --output json | \
  jq -r '.[].message' | sed 's/[0-9a-f\-]\{8,\}/ID/g; s/[0-9]\+/N/g' | \
  sort | uniq -c | sort -rn | head -10
```

---

## Troubleshooting Script

Use the bundled script for a guided workflow:

```bash
chmod +x skills/mezmo-log-analysis/mezmo-troubleshoot.sh

export MZM_ACCESS_KEY="..."
export MZM_APP="your-service"
export MZM_ENV="production"

# Tail live errors
./skills/mezmo-log-analysis/mezmo-troubleshoot.sh tail

# Search last 2 hours
./skills/mezmo-log-analysis/mezmo-troubleshoot.sh search "2h ago"

# Critical errors
./skills/mezmo-log-analysis/mezmo-troubleshoot.sh critical

# Trace a request
./skills/mezmo-log-analysis/mezmo-troubleshoot.sh trace abc-123-xyz

# Deep analysis: single service → T0 anchor → ±10 min chain of events → cross-service trace
./skills/mezmo-log-analysis/mezmo-troubleshoot.sh analyze "level:error" your-service
```

---

## Reusable Views

Register saved views once, then query them any time:

```bash
APP_NAME=my-service envsubst < skills/mezmo-log-analysis/mezmo-views.yaml | mzm create -f -
mzm get views
```
