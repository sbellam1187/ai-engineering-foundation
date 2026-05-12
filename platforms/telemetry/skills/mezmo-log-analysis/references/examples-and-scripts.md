# Mezmo Log Analysis — Examples and Scripts Reference

Detailed examples, scripts, and cross-service tracing patterns for the Mezmo Log Analysis Skill.

## Example Log Entries

### Example 1 — JSON structured log (error)
```json
{
  "@timestamp": "2026-03-11T06:22:54.652617248Z",
  "CID": "CID-d876c1fd-9b08-4683-8254-f198145d48af",
  "_app": "aa-ct-loyalty-servicebus-queue-publisher",
  "_host": "aa-ct-loyalty-servicebus-queue-publisher-5859b5749d-4c68x",
  "_label": {
    "environment": "prod",
    "service": "servicebus-queue-publisher",
    "service-group": "loyalty-benefits-bff"
  },
  "level": "ERROR",
  "logger_name": "c.a.l.S.s.EntitlementMessageService",
  "message": "Failed to save choice selection to ventana: Failed",
  "dt_trace_id": "0e21ddb14a5a0e8a6a9fc89408ef33fd",
  "dt_span_id": "92433519827f7c49"
}
```

### Example 2 — Meta log (info)
```json
{
  "_app": "aa-ct-loyalty-membenefits-entitlements",
  "_host": "aa-ct-loyalty-membenefits-entitlements-7cb5d987c7-wsv5d",
  "_label": {
    "environment": "prod",
    "service": "loyalty-entitlements",
    "service-group": "loyalty-benefits-bff"
  },
  "level": "INFO",
  "message": "Data service URI detected, appending service specific header."
}
```

## CI/CD Pipeline Integration

### GitLab CI
```yaml
validate_deployment:
  stage: verify
  script:
    - export MZM_ACCESS_KEY="${MEZMO_ACCESS_KEY}"
    - sleep 60
    - |
      mzm log search "level:error AND app:${CI_PROJECT_NAME}" \
        --from "5m ago" --output json > errors.json
    - |
      if [ $(cat errors.json | jq 'length') -gt 0 ]; then
        echo "Errors detected:"
        cat errors.json | jq '.[] | {timestamp, message}'
        exit 1
      fi
  only:
    - main
```

### GitHub Actions
```yaml
- name: Validate Deployment Logs
  env:
    MZM_ACCESS_KEY: ${{ secrets.MEZMO_ACCESS_KEY }}
  run: |
    sleep 60
    ERROR_COUNT=$(mzm log search "level:error AND app:my-service" \
      --from "5m ago" --output json | jq 'length')
    if [ "$ERROR_COUNT" -gt 0 ]; then
      echo "❌ Deployment failed: $ERROR_COUNT errors"
      exit 1
    fi
```

### Deployment Validation Script
```bash
#!/bin/bash
set -e
APP_NAME="my-service"
ENV="production"
WAIT_TIME=60
ERROR_THRESHOLD=0

echo "⏳ Waiting ${WAIT_TIME}s for deployment to stabilize..."
sleep $WAIT_TIME

mzm log search "level:error AND app:${APP_NAME} AND env:${ENV}" \
  --from "${WAIT_TIME}s ago" --output json > /tmp/errors.json

ERROR_COUNT=$(cat /tmp/errors.json | jq 'length')

if [ "$ERROR_COUNT" -gt "$ERROR_THRESHOLD" ]; then
  echo "❌ Deployment validation FAILED"
  cat /tmp/errors.json | jq -r '.[] | "[\(.timestamp)] \(.message)"' | head -10
  exit 1
else
  echo "✅ Deployment validation PASSED"
fi
```

## Cross-Service Distributed Tracing

### Available Correlation Identifiers

| Field | Description | Example |
|-------|-------------|---------|
| `correlation-id` | Request trace ID propagated across services | `req-abc-123-xyz` |
| `transaction-id` | Unique transaction identifier | `txn-987-def` |
| `aadvantage-number` | Member identifier (inline in log messages) | `4R3TD94` |
| `sessionId` | Browser/client session ID (`_meta.sessionId`) | `ac7d3283-4cba-427f-83c1-f4a905b54adf` |

### Recommended Investigation Workflow

```
Phase 1  ──►  Phase 2  ──►  Phase 3
Single svc     ±10 min       Cross-svc
error search   chain view    fan-out by
               (T0 anchor)   AA# / txn-id
```

### Using `mezmo-troubleshoot.sh analyze`
```bash
./mezmo-troubleshoot.sh analyze "customer asset"
./mezmo-troubleshoot.sh analyze "customer asset" loyalty-engage-linked-partners-mfe
./mezmo-troubleshoot.sh analyze "level:error" loyalty-engage-linked-partners-mfe
export MZM_FROM="6h ago"
./mezmo-troubleshoot.sh analyze "Failed to fetch customer data"
```

### Manual 3-Phase Pattern

**Phase 1 — Analyse one service**
```bash
SERVICE="loyalty-engage-linked-partners-mfe"
mzm log search "Failed to fetch customer data" \
  --app "${SERVICE}" --from "1h ago" --limit 200 --output json > /tmp/svc-errors.json
jq 'length' /tmp/svc-errors.json
```

**Phase 2 — Anchor T0 and search ±10 min**
```bash
FIRST_TS_MS=$(jq -rs 'sort_by(._ts) | first | ._ts' /tmp/svc-errors.json)
T0=$(( FIRST_TS_MS / 1000 ))
T_MINUS=$(date -u -r $((T0 - 600)) '+%Y-%m-%dT%H:%M:%SZ')
T_PLUS=$(date -u -r $((T0 + 600)) '+%Y-%m-%dT%H:%M:%SZ')
mzm log search "*" --app "${SERVICE}" --from "${T_MINUS}" --to "${T_PLUS}" \
  --limit 500 --output json > /tmp/window.json
```

**Phase 3 — Fan out to other services**
```bash
AA_LIST=$(jq -rs '[.[]._ line // "" |
  scan("(?i)aadvantage.?number[: ]+([A-Z0-9]{5,8})") | .[0]] |
  unique | .[]' /tmp/window.json)
AA=$(echo "$AA_LIST" | head -1)
SERVICES=$(mzm log search "level:error" --from "1h ago" --limit 200 --output json 2>/dev/null | \
  jq -rs '[.[] | ._app] | unique[]')
echo "$SERVICES" | while read -r SVC; do
  [ "$SVC" = "$SERVICE" ] && continue
  COUNT=$(mzm log search "aadvantage-number:${AA}" --app "${SVC}" \
    --from "${T_MINUS}" --to "${T_PLUS}" --limit 100 --output json 2>/dev/null | jq 'length')
  [ "$COUNT" -gt 0 ] && echo "✔ ${SVC}: ${COUNT} related entries"
done
```

### Tracing by Identifier

**By AAdvantage Number:**
```bash
AA_NUMBER="4R3TD94"
SERVICES=$(mzm log search "aadvantage-number:${AA_NUMBER}" \
  --from "24h ago" --limit 200 --output json 2>/dev/null | jq -rs '[.[] | ._app] | unique[]')
echo "$SERVICES" | while read -r SERVICE; do
  mzm log search "aadvantage-number:${AA_NUMBER}" --app "${SERVICE}" --from "24h ago" --output json | \
    jq -rs 'sort_by(._ts) | .[] | "[\(._ts | todate)] [\(.level)] \(._line | .[0:150])"'
done
```

**By Session ID:**
```bash
SESSION_ID="ac7d3283-4cba-427f-83c1-f4a905b54adf"
mzm log search "sessionId:${SESSION_ID}" --from "2h ago" --output json
```

**By Correlation ID:**
```bash
CORRELATION_ID="req-abc-123-xyz"
mzm log search "correlation-id:${CORRELATION_ID}" --from "24h ago" --output json > /tmp/full-trace.json
jq -rs 'sort_by(._ts) | .[] | "[\(._ts | todate)] [\(.level)] [\(._app // "unknown")] \(._line | .[0:150])"' /tmp/full-trace.json
```

**Using `mezmo-troubleshoot.sh chain`:**
```bash
./mezmo-troubleshoot.sh chain aa-number 4R3TD94
./mezmo-troubleshoot.sh chain session ac7d3283-4cba-427f-83c1-f4a905b54adf
./mezmo-troubleshoot.sh chain correlation-id req-abc-123-xyz
./mezmo-troubleshoot.sh chain transaction-id txn-987-def
```

## Troubleshooting

**Authentication failed:** `echo $MZM_ACCESS_KEY` / `mzm config get account`

**No results:** Widen time range (`--from "24h ago"`), remove filters, verify app name with `mzm log search --app "*"`

**Query timeout:** Narrow time range, add more filters, reduce `--limit`
