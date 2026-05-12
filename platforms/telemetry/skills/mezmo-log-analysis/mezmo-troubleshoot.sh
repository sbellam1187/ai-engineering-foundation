#!/bin/bash
#
# Mezmo Log Analysis - Production Troubleshooting Script
#
# A reusable script for investigating production errors using the Mezmo CLI.
# Suitable for any microservice.
#
# Prerequisites:
# - Mezmo CLI installed: curl -sSL https://get.mezmo.com/cli | sh
# - MZM_ACCESS_KEY environment variable set
#
# Usage:
#   ./mezmo-troubleshoot.sh [option] [args]
#
# Options:
#   tail      - Real-time error monitoring (default)
#   search    - Historical error search
#   critical  - Critical errors only (5xx, exceptions)
#   trace     - Trace request by correlation ID
#   chain     - Cross-service distributed tracing (AA number, session, correlation ID)
#   analyze   - Deep single-service analysis → timestamp anchor → cross-service trace
#

set -e

# ─────────────────────────────────────────────
# Configuration — override via environment vars
# ─────────────────────────────────────────────
APP_NAME="${MZM_APP:-}"                 # Set via: export MZM_APP="my-service" (optional — auto-discovered if unset)
ENV="${MZM_ENV:-production}"            # Set via: export MZM_ENV="production"
DEFAULT_TIME_RANGE="${MZM_FROM:-1h ago}"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# ─────────────────────────────────────────────
# Auth check
# ─────────────────────────────────────────────
if [ -z "$MZM_ACCESS_KEY" ]; then
    echo -e "${RED}❌ Error: MZM_ACCESS_KEY is not set${NC}"
    echo ""
    echo "Set your Mezmo access key:"
    echo "  export MZM_ACCESS_KEY=\"your-key-here\""
    echo ""
    echo "Optionally configure target app and env:"
    echo "  export MZM_APP=\"my-service\""
    echo "  export MZM_ENV=\"production\""
    exit 1
fi

echo -e "${GREEN}✅ Mezmo CLI authenticated${NC}"
echo -e "${BLUE}📌 Env: ${ENV}${NC}"
echo ""

# ─────────────────────────────────────────────
# discover_services: Discover active service names from logs
# Returns a space-separated list of unique _app values
# ─────────────────────────────────────────────
function discover_services() {
    local TIME_RANGE="${1:-$DEFAULT_TIME_RANGE}"

    echo -e "${BLUE}🔭 Discovering active services from logs (${TIME_RANGE})...${NC}" >&2

    local SERVICES
    SERVICES=$(mzm log search "level:error" \
        --from "${TIME_RANGE}" \
        --limit 200 \
        --output json 2>/dev/null | \
        jq -rs '[.[] | ._app] | unique | .[]' 2>/dev/null)

    if [ -z "$SERVICES" ]; then
        # Fall back to any log level if no errors found
        SERVICES=$(mzm log search "*" \
            --from "${TIME_RANGE}" \
            --limit 100 \
            --output json 2>/dev/null | \
            jq -rs '[.[] | ._app] | unique | .[]' 2>/dev/null)
    fi

    if [ -z "$SERVICES" ]; then
        echo -e "${YELLOW}⚠️  No services discovered. Check time range or credentials.${NC}" >&2
        echo ""
        return 1
    fi

    echo -e "${GREEN}✅ Discovered services:${NC}" >&2
    echo "$SERVICES" | while read -r svc; do
        echo -e "   • ${svc}" >&2
    done
    echo "" >&2

    echo "$SERVICES"
}

# ─────────────────────────────────────────────
# tail: Real-time error monitoring
# ─────────────────────────────────────────────
function cmd_tail() {
    echo -e "${BLUE}📡 Streaming live errors and warnings — press Ctrl+C to stop...${NC}"
    echo ""

    if [ -n "$APP_NAME" ]; then
        mzm log tail \
            --app "${APP_NAME}" \
            --level error \
            --level warn \
            --query "env:${ENV}"
    else
        # No app specified — tail all services
        mzm log tail \
            --level error \
            --level warn \
            --query "env:${ENV}"
    fi
}

# ─────────────────────────────────────────────
# search: Historical error search
# ─────────────────────────────────────────────
function cmd_search() {
    local TIME_RANGE="${1:-$DEFAULT_TIME_RANGE}"
    local OUTFILE="/tmp/mzm-errors-$(date +%s).json"

    # Discover services if MZM_APP not set
    if [ -z "$APP_NAME" ]; then
        local DISCOVERED
        DISCOVERED=$(discover_services "${TIME_RANGE}") || exit 1
        APP_NAME=$(echo "$DISCOVERED" | head -1)
        echo -e "${YELLOW}ℹ️  MZM_APP not set — using first discovered service: ${APP_NAME}${NC}"
        echo -e "${YELLOW}   To target a specific service: export MZM_APP=\"<service-name>\"${NC}"
        echo ""
    fi

    echo -e "${BLUE}🔍 Searching errors — app: ${APP_NAME}  from: ${TIME_RANGE}${NC}"
    echo ""

    mzm log search "level:error AND app:${APP_NAME} AND env:${ENV}" \
        --from "${TIME_RANGE}" \
        --output json > "${OUTFILE}"

    local COUNT; COUNT=$(jq -s 'length' "${OUTFILE}")

    if [ "$COUNT" -eq 0 ]; then
        echo -e "${GREEN}✅ No errors found${NC}"
        return 0
    fi

    echo -e "${YELLOW}⚠️  Found ${COUNT} errors${NC}"
    echo ""

    echo -e "${BLUE}📋 Recent errors:${NC}"
    jq -rs '.[] | "[\(._ts | . / 1000 | todate)] \(._line // "")"' "${OUTFILE}" | head -20

    echo ""
    echo -e "${BLUE}📊 Top error patterns (deduplicated):${NC}"
    jq -rs '[.[]._line // ""] |
        map(gsub("[0-9a-f\\-]{8,}"; "ID") | gsub("[0-9]+"; "N")) |
        group_by(.) | sort_by(-length) | .[] | "\(length)x \(.[0])"' "${OUTFILE}" | head -10

    echo ""
    echo -e "${GREEN}💾 Saved to: ${OUTFILE}${NC}"
}

# ─────────────────────────────────────────────
# critical: 5xx, exceptions, fatal errors
# ─────────────────────────────────────────────
function cmd_critical() {
    local TIME_RANGE="${1:-$DEFAULT_TIME_RANGE}"
    local OUTFILE="/tmp/mzm-critical-$(date +%s).json"

    # Discover services if MZM_APP not set
    if [ -z "$APP_NAME" ]; then
        local DISCOVERED
        DISCOVERED=$(discover_services "${TIME_RANGE}") || exit 1
        APP_NAME=$(echo "$DISCOVERED" | head -1)
        echo -e "${YELLOW}ℹ️  MZM_APP not set — using first discovered service: ${APP_NAME}${NC}"
        echo ""
    fi

    echo -e "${RED}🚨 Searching critical errors (5xx / Exception / fatal) in ${APP_NAME}...${NC}"
    echo ""

    local QUERY="(level:error OR level:fatal) AND app:${APP_NAME} AND env:${ENV} AND (status:[500 TO 599] OR message:*Exception* OR message:*Error*)"

    mzm log search "${QUERY}" \
        --from "${TIME_RANGE}" \
        --output json > "${OUTFILE}"

    local COUNT; COUNT=$(jq -s 'length' "${OUTFILE}")

    if [ "$COUNT" -eq 0 ]; then
        echo -e "${GREEN}✅ No critical errors found${NC}"
        return 0
    fi

    echo -e "${RED}❌ Found ${COUNT} critical errors${NC}"
    echo ""

    echo -e "${BLUE}📋 Critical errors:${NC}"
    jq -rs '.[] | "[\(._ts / 1000 | todate)] [\(.level)] \(._line // "")"' "${OUTFILE}" | head -20

    echo ""
    echo -e "${GREEN}💾 Saved to: ${OUTFILE}${NC}"
}

# ─────────────────────────────────────────────
# trace: Trace request by correlation ID
# ─────────────────────────────────────────────
function cmd_trace() {
    local CORRELATION_ID="$1"
    if [ -z "$CORRELATION_ID" ]; then
        echo -e "${RED}❌ Usage: $0 trace <correlation-id>${NC}"
        exit 1
    fi

    local OUTFILE="/tmp/mzm-trace-$(date +%s).json"

    echo -e "${BLUE}🔍 Tracing correlation-id: ${CORRELATION_ID}${NC}"
    echo ""

    mzm log search "correlation-id:${CORRELATION_ID}" \
        --from "24h ago" \
        --output json > "${OUTFILE}"

    local COUNT; COUNT=$(jq -s 'length' "${OUTFILE}")

    if [ "$COUNT" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No logs found for correlation-id: ${CORRELATION_ID}${NC}"
        return 1
    fi

    echo -e "${GREEN}✅ Found ${COUNT} log entries${NC}"
    echo ""

    echo -e "${BLUE}📋 Request flow (chronological):${NC}"
    jq -rs 'sort_by(._ts) | .[] | "[\(._ts | . / 1000 | todate)] [\(.level // "?")] \(._app // "?") — \(._line // "")"' "${OUTFILE}"

    local ERROR_COUNT; ERROR_COUNT=$(jq -s '[.[] | select(.level == "error")] | length' "${OUTFILE}")

    echo ""
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${RED}❌ Errors in trace (${ERROR_COUNT}):${NC}"
        jq -rs '.[] | select(.level == "error") | "[\(._ts | . / 1000 | todate)] \(._line // "")"' "${OUTFILE}"
    else
        echo -e "${GREEN}✅ No errors in trace${NC}"
    fi

    echo ""
    echo -e "${GREEN}💾 Saved to: ${OUTFILE}${NC}"
}

# ─────────────────────────────────────────────
# chain: Cross-service distributed tracing
# Usage:
#   chain aa-number      <AA_NUMBER>       — by AAdvantage number
#   chain session        <SESSION_ID>      — by browser session ID
#   chain correlation-id <CORRELATION_ID>  — by correlation ID
#   chain transaction-id <TXN_ID>         — by transaction ID
# ─────────────────────────────────────────────
function cmd_chain() {
    local TRACE_TYPE="$1"
    local TRACE_VALUE="$2"

    if [ -z "$TRACE_TYPE" ] || [ -z "$TRACE_VALUE" ]; then
        echo -e "${RED}❌ Usage: $0 chain <type> <value>${NC}"
        echo ""
        echo "  Types:"
        echo "    aa-number       <AAdvantage number>     e.g. 4R3TD94"
        echo "    session         <session ID>            e.g. ac7d3283-..."
        echo "    correlation-id  <correlation ID>        e.g. req-abc-123"
        echo "    transaction-id  <transaction ID>        e.g. txn-987-def"
        exit 1
    fi

    # Map type to query field
    local QUERY_FIELD
    case "$TRACE_TYPE" in
        aa-number)      QUERY_FIELD="aadvantage-number" ;;
        session)        QUERY_FIELD="sessionId" ;;
        correlation-id) QUERY_FIELD="correlation-id" ;;
        transaction-id) QUERY_FIELD="transaction-id" ;;
        *)
            echo -e "${RED}❌ Unknown trace type: ${TRACE_TYPE}${NC}"
            echo "Valid types: aa-number, session, correlation-id, transaction-id"
            exit 1
            ;;
    esac

    local TIME_RANGE="${DEFAULT_TIME_RANGE}"
    local OUTDIR="/tmp/mzm-chain-$(date +%s)"
    mkdir -p "${OUTDIR}"

    echo -e "${BLUE}🔗 Cross-service trace — ${TRACE_TYPE}: ${TRACE_VALUE}${NC}"
    echo -e "${BLUE}⏱  Time window: ${TIME_RANGE}${NC}"
    echo ""

    # Dynamically discover services — no hardcoded list
    local SERVICES_RAW
    SERVICES_RAW=$(discover_services "${TIME_RANGE}") || exit 1
    mapfile -t SERVICES <<< "$SERVICES_RAW"

    local TOTAL_ERRORS=0

    for SERVICE in "${SERVICES[@]}"; do
        local OUTFILE="${OUTDIR}/${SERVICE}.json"

        echo -e "${BLUE}--- ${SERVICE} ---${NC}"

        mzm log search "${QUERY_FIELD}:${TRACE_VALUE}" \
            --app "${SERVICE}" \
            --from "${TIME_RANGE}" \
            --output json > "${OUTFILE}" 2>/dev/null || echo '[]' > "${OUTFILE}"

        local COUNT; COUNT=$(jq 'length' "${OUTFILE}")
        local ERR_COUNT; ERR_COUNT=$(jq '[.[] | select(.level == "error")] | length' "${OUTFILE}")
        TOTAL_ERRORS=$((TOTAL_ERRORS + ERR_COUNT))

        if [ "$COUNT" -eq 0 ]; then
            echo -e "  ${YELLOW}(no logs found)${NC}"
        else
            echo -e "  ${GREEN}${COUNT} entries, ${RED}${ERR_COUNT} error(s)${NC}"
            jq -r 'sort_by(.timestamp) | .[] | "  [\(.timestamp)] [\(.level)] \(.message | .[0:120])"' "${OUTFILE}"
        fi
        echo ""
    done

    echo -e "${BLUE}━━━ Summary ━━━${NC}"
    echo -e "Trace type:  ${TRACE_TYPE}"
    echo -e "Trace value: ${TRACE_VALUE}"
    echo -e "Time window: ${TIME_RANGE}"
    if [ "$TOTAL_ERRORS" -gt 0 ]; then
        echo -e "${RED}Total errors across all services: ${TOTAL_ERRORS}${NC}"
    else
        echo -e "${GREEN}No errors found across any service${NC}"
    fi
    echo -e "${GREEN}💾 Raw data saved to: ${OUTDIR}/${NC}"
}

# ─────────────────────────────────────────────
# analyze: Deep single-service analysis, then cross-service trace
#
# Workflow:
#   1. Discover services (if no service given)
#   2. Analyse ONE service first — find errors matching the pattern
#   3. Anchor T0 = timestamp of the first matching error
#   4. Search ±10 min around T0 in that service → chain of events
#   5. Extract transaction-id / aadvantage-number / correlation-id from window
#   6. Fan out to every other discovered service using those identifiers
#      constrained to the same ±10 min window
#   7. Present a unified timeline and analysis summary
#
# Usage:
#   ./mezmo-troubleshoot.sh analyze "<error keyword or query>" [service-name]
# ─────────────────────────────────────────────
function cmd_analyze() {
    local ERROR_PATTERN="${1:-level:error}"   # e.g. "customer asset" or "401" or "level:error"
    local TARGET_SERVICE="${2:-}"             # optional; auto-discovered if empty

    # ── Step 1: Discover / confirm target service ───────────────────────────
    if [ -z "$TARGET_SERVICE" ]; then
        local ALL_SERVICES_RAW
        ALL_SERVICES_RAW=$(discover_services "${DEFAULT_TIME_RANGE}") || exit 1
        TARGET_SERVICE=$(echo "$ALL_SERVICES_RAW" | head -1)
        echo -e "${YELLOW}🎯 No service specified — starting with first discovered service: ${TARGET_SERVICE}${NC}"
        echo -e "${YELLOW}   To target a specific service: $0 analyze \"${ERROR_PATTERN}\" <service-name>${NC}"
        echo ""
    fi

    # ── Step 2: Find errors in the target service ───────────────────────────
    echo -e "${BLUE}━━━ Phase 1 · Single-Service Error Analysis: ${TARGET_SERVICE} ━━━${NC}"
    echo -e "${BLUE}🔍 Query: \"${ERROR_PATTERN}\"  |  window: ${DEFAULT_TIME_RANGE}${NC}"
    echo ""

    local SERVICE_ERRORS="/tmp/mzm-analyze-svc-$(date +%s).json"
    mzm log search "${ERROR_PATTERN}" \
        --app "${TARGET_SERVICE}" \
        --from "${DEFAULT_TIME_RANGE}" \
        --limit 200 \
        --output json 2>/dev/null > "${SERVICE_ERRORS}" || echo '[]' > "${SERVICE_ERRORS}"

    local ERROR_COUNT
    ERROR_COUNT=$(jq -s 'length' "${SERVICE_ERRORS}" 2>/dev/null || echo 0)

    if [ "${ERROR_COUNT:-0}" -eq 0 ]; then
        echo -e "${GREEN}✅ No errors matching \"${ERROR_PATTERN}\" found in ${TARGET_SERVICE} within ${DEFAULT_TIME_RANGE}${NC}"
        echo -e "${YELLOW}   Try a broader time range: export MZM_FROM=\"24h ago\"${NC}"
        return 0
    fi

    echo -e "${RED}❌ Found ${ERROR_COUNT} matching entries in ${TARGET_SERVICE}${NC}"
    echo ""

    # Show top error patterns in this service
    echo -e "${BLUE}📊 Top error patterns (${TARGET_SERVICE}):${NC}"
    jq -rs '[.[]._line // ""] |
        group_by(
            gsub("[0-9a-fA-F]{8}-[0-9a-fA-F-]{27}"; "<uuid>") |
            gsub("[0-9]+"; "<N>")
        ) | sort_by(-length) | .[] |
        "\(length)x  \(.[0] | .[0:140])"' \
        "${SERVICE_ERRORS}" 2>/dev/null | head -8 || \
    jq -rs 'group_by(._line) | sort_by(-length) | .[0:8] | .[] |
        "\(length)x  \(.[0]._line // "" | .[0:140])"' \
        "${SERVICE_ERRORS}" 2>/dev/null | head -8 || true
    echo ""

    # ── Step 3: Anchor T0 = first error timestamp ───────────────────────────
    local FIRST_TS_MS
    FIRST_TS_MS=$(jq -rs 'sort_by(._ts) | first | ._ts // empty' "${SERVICE_ERRORS}" 2>/dev/null)

    if [ -z "$FIRST_TS_MS" ] || [ "$FIRST_TS_MS" = "null" ]; then
        echo -e "${YELLOW}⚠️  Could not extract timestamp (_ts) from logs — cannot anchor window${NC}"
        return 1
    fi

    local T0=$(( FIRST_TS_MS / 1000 ))   # milliseconds → seconds
    local T0_ISO T_MINUS_ISO T_PLUS_ISO
    T0_ISO=$(date -u -r "${T0}" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d "@${T0}" '+%Y-%m-%dT%H:%M:%SZ')
    T_MINUS_ISO=$(date -u -r "$((T0 - 600))" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d "@$((T0 - 600))" '+%Y-%m-%dT%H:%M:%SZ')
    T_PLUS_ISO=$(date -u -r "$((T0 + 600))" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d "@$((T0 + 600))" '+%Y-%m-%dT%H:%M:%SZ')

    echo -e "${GREEN}⏰ First error T0 : ${T0_ISO}${NC}"
    echo -e "${GREEN}📅 Analysis window: ${T_MINUS_ISO}  →  ${T_PLUS_ISO}  (±10 min)${NC}"
    echo ""

    # ── Step 4: Fetch all logs ±10 min in the target service ────────────────
    echo -e "${BLUE}━━━ Phase 2 · Chain of Events in ${TARGET_SERVICE} (±10 min) ━━━${NC}"

    local WINDOW_LOGS="/tmp/mzm-analyze-window-$(date +%s).json"
    mzm log search \
        --app "${TARGET_SERVICE}" \
        --from "${T_MINUS_ISO}" \
        --to "${T_PLUS_ISO}" \
        --limit 500 \
        --output json 2>/dev/null > "${WINDOW_LOGS}" || echo '{}' > "${WINDOW_LOGS}"

    local WINDOW_COUNT
    WINDOW_COUNT=$(jq -s 'length' "${WINDOW_LOGS}" 2>/dev/null || echo 0)
    echo -e "${GREEN}📋 ${WINDOW_COUNT} log entries in window${NC}"
    echo ""

    # Print chronological chain with level colour-coding
    jq -rs 'sort_by(._ts) | .[] |
        (._ts / 1000 | floor | strftime("%H:%M:%S")) as $t |
        (._line // "" | .[0:160]) as $msg |
        if (.level // "") == "error" then "  \u001b[31m[ERR]\u001b[0m  \($t)  \($msg)"
        elif (.level // "") == "warn"  then "  \u001b[33m[WRN]\u001b[0m  \($t)  \($msg)"
        elif (.level // "") == "debug" then "  \u001b[90m[DBG]\u001b[0m  \($t)  \($msg)"
        else                                "  \u001b[34m[INF]\u001b[0m  \($t)  \($msg)"
        end' "${WINDOW_LOGS}" 2>/dev/null | head -60
    echo ""

    # ── Step 5: Extract correlation identifiers from the window ─────────────
    echo -e "${BLUE}🔑 Extracting correlation identifiers from window logs...${NC}"

    # AAdvantage numbers: look for patterns like "aadvantage-number: 4R3TD94" or "aa# 4R3TD94"
    local AA_NUMBERS
    AA_NUMBERS=$(jq -rs '[.[] | ._line // "" |
        scan("aadvantage.?number[: ]+([A-Z0-9]{5,8})") | .[0]] | unique | .[]' \
        "${WINDOW_LOGS}" 2>/dev/null || true)

    # Transaction IDs from metadata or inline
    local TRANSACTION_IDS
    TRANSACTION_IDS=$(jq -rs '[.[] |
        (."transaction-id" // ._meta."transaction-id" //
         (._line // "" | capture("transaction.?id[: \"]+(?P<id>[a-zA-Z0-9_\\-]{8,})").id) //
         empty) | select(. != "" and . != null)] | unique | .[]' \
        "${WINDOW_LOGS}" 2>/dev/null || true)

    # Correlation IDs
    local CORRELATION_IDS
    CORRELATION_IDS=$(jq -rs '[.[] |
        (."correlation-id" // ._meta."correlation-id" //
         (._line // "" | capture("correlation.?id[: \"]+(?P<id>[a-zA-Z0-9_\\-]{8,})").id) //
         empty) | select(. != "" and . != null)] | unique | .[]' \
        "${WINDOW_LOGS}" 2>/dev/null || true)

    # Session IDs
    local SESSION_IDS
    SESSION_IDS=$(jq -rs '[.[] |
        (._meta.sessionId // ._meta."session-id" // empty) |
        select(. != "" and . != null)] | unique | .[]' \
        "${WINDOW_LOGS}" 2>/dev/null || true)

    local HAS_ID=false
    local CROSS_QUERY="" CROSS_LABEL=""

    if [ -n "$AA_NUMBERS" ]; then
        HAS_ID=true
        local AA_FIRST; AA_FIRST=$(echo "$AA_NUMBERS" | head -1)
        CROSS_QUERY="aadvantage-number:${AA_FIRST}"
        CROSS_LABEL="AAdvantage# ${AA_FIRST}"
        echo -e "  ${GREEN}✔ AAdvantage# : $(echo "$AA_NUMBERS" | tr '\n' '  ')${NC}"
    fi
    if [ -n "$TRANSACTION_IDS" ]; then
        HAS_ID=true
        local TXN_FIRST; TXN_FIRST=$(echo "$TRANSACTION_IDS" | head -1)
        [ -z "$CROSS_QUERY" ] && { CROSS_QUERY="transaction-id:${TXN_FIRST}"; CROSS_LABEL="transaction-id ${TXN_FIRST}"; }
        echo -e "  ${GREEN}✔ Transaction IDs : $(echo "$TRANSACTION_IDS" | tr '\n' '  ')${NC}"
    fi
    if [ -n "$CORRELATION_IDS" ]; then
        HAS_ID=true
        local CORR_FIRST; CORR_FIRST=$(echo "$CORRELATION_IDS" | head -1)
        [ -z "$CROSS_QUERY" ] && { CROSS_QUERY="correlation-id:${CORR_FIRST}"; CROSS_LABEL="correlation-id ${CORR_FIRST}"; }
        echo -e "  ${GREEN}✔ Correlation IDs : $(echo "$CORRELATION_IDS" | tr '\n' '  ')${NC}"
    fi
    if [ -n "$SESSION_IDS" ]; then
        HAS_ID=true
        local SES_FIRST; SES_FIRST=$(echo "$SESSION_IDS" | head -1)
        [ -z "$CROSS_QUERY" ] && { CROSS_QUERY="sessionId:${SES_FIRST}"; CROSS_LABEL="sessionId ${SES_FIRST}"; }
        echo -e "  ${GREEN}✔ Session IDs : $(echo "$SESSION_IDS" | head -3 | tr '\n' '  ')${NC}"
    fi
    echo ""

    # ── Step 6: Cross-service fan-out ────────────────────────────────────────
    if [ "$HAS_ID" = true ]; then
        echo -e "${BLUE}━━━ Phase 3 · Cross-Service Trace (identifier: ${CROSS_LABEL}) ━━━${NC}"
        echo -e "${BLUE}   Window: ${T_MINUS_ISO}  →  ${T_PLUS_ISO}${NC}"
        echo ""

        local ALL_SERVICES_RAW
        ALL_SERVICES_RAW=$(discover_services "${DEFAULT_TIME_RANGE}") || exit 1

        local CROSS_OUTDIR="/tmp/mzm-cross-$(date +%s)"
        mkdir -p "${CROSS_OUTDIR}"

        echo "$ALL_SERVICES_RAW" | while read -r SERVICE; do
            # Skip the primary service we already analysed in detail
            [ "$SERVICE" = "$TARGET_SERVICE" ] && continue

            local XFILE="${CROSS_OUTDIR}/${SERVICE}.json"
            mzm log search "${CROSS_QUERY}" \
                --app "${SERVICE}" \
                --from "${T_MINUS_ISO}" \
                --to "${T_PLUS_ISO}" \
                --limit 100 \
                --output json 2>/dev/null > "${XFILE}" || true

            local XCOUNT XERR
            XCOUNT=$(jq -s 'length' "${XFILE}" 2>/dev/null || echo 0)
            XERR=$(jq -s '[.[] | select(.level == "error")] | length' "${XFILE}" 2>/dev/null || echo 0)

            if [ "${XCOUNT:-0}" -gt 0 ]; then
                echo -e "${BLUE}  ┌── ${SERVICE}  (${XCOUNT} entries, ${RED}${XERR} error(s)${BLUE})${NC}"
                jq -rs 'sort_by(._ts) | .[] |
                    (._ts / 1000 | floor | strftime("%H:%M:%S")) as $t |
                    (._line // "" | .[0:150]) as $msg |
                    if (.level // "") == "error" then "  │  \u001b[31m[ERR]\u001b[0m  \($t)  \($msg)"
                    elif (.level // "") == "warn"  then "  │  \u001b[33m[WRN]\u001b[0m  \($t)  \($msg)"
                    else                                "  │  \u001b[34m[INF]\u001b[0m  \($t)  \($msg)"
                    end' "${XFILE}" 2>/dev/null
                echo -e "  └────"
                echo ""
            else
                echo -e "  ${YELLOW}·  ${SERVICE}  — no matching logs in window${NC}"
            fi
        done
        echo ""
    else
        echo -e "${YELLOW}⚠️  No AAdvantage#, transaction-id, correlation-id, or session-id found in window.${NC}"
        echo -e "${YELLOW}   Cross-service trace skipped. Run a broader time query to look for adjacent errors:${NC}"
        echo -e "${YELLOW}   mzm log search \"level:error\" --from \"${T_MINUS_ISO}\" --to \"${T_PLUS_ISO}\" --output json${NC}"
        echo ""
    fi

    # ── Step 7: Analysis summary ─────────────────────────────────────────────
    local ERR_BREAKDOWN
    ERR_BREAKDOWN=$(jq -rs 'group_by(._line) | sort_by(-length) | .[0:5] | .[] |
        "\(length)x  \(.[0]._line // "" | .[0:120])"' "${WINDOW_LOGS}" 2>/dev/null || true)

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📊  Analysis Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Primary service  : ${TARGET_SERVICE}"
    echo -e "  Error query      : ${ERROR_PATTERN}"
    echo -e "  Matching entries : ${ERROR_COUNT}"
    echo -e "  First error (T0) : ${T0_ISO}"
    echo -e "  Analysis window  : ${T_MINUS_ISO}  →  ${T_PLUS_ISO}"
    echo -e "  Window log count : ${WINDOW_COUNT}"
    [ -n "$AA_NUMBERS" ]       && echo -e "  AAdvantage#      : $(echo "$AA_NUMBERS" | tr '\n' '  ')"
    [ -n "$TRANSACTION_IDS" ]  && echo -e "  Transaction IDs  : $(echo "$TRANSACTION_IDS" | head -3 | tr '\n' '  ')"
    [ -n "$CORRELATION_IDS" ]  && echo -e "  Correlation IDs  : $(echo "$CORRELATION_IDS" | head -3 | tr '\n' '  ')"
    echo ""
    if [ -n "$ERR_BREAKDOWN" ]; then
        echo -e "${RED}  Top errors in window:${NC}"
        echo "$ERR_BREAKDOWN" | sed 's/^/    /'
    fi
    echo ""
    echo -e "${GREEN}  💾 Service errors    : ${SERVICE_ERRORS}${NC}"
    echo -e "${GREEN}  💾 Window logs       : ${WINDOW_LOGS}${NC}"
    echo ""
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────
OPTION="${1:-tail}"
shift || true

case "$OPTION" in
    tail)     cmd_tail ;;
    search)   cmd_search "$@" ;;
    critical) cmd_critical "$@" ;;
    trace)    cmd_trace "$@" ;;
    chain)    cmd_chain "$@" ;;
    analyze)  cmd_analyze "$@" ;;
    *)
        echo "Usage: $0 {tail|search|critical|trace|chain|analyze} [options]"
        echo ""
        echo "  tail                              Real-time errors/warnings"
        echo "  search [\"Nh ago\"]                 Historical error search (default: 1h ago)"
        echo "  critical [\"Nh ago\"]               5xx / exception / fatal errors"
        echo "  trace <correlation-id>            Full request trace by correlation ID"
        echo "  chain aa-number      <value>      Cross-service trace by AAdvantage number"
        echo "  chain session        <value>      Cross-service trace by session ID"
        echo "  chain correlation-id <value>      Cross-service trace by correlation ID"
        echo "  chain transaction-id <value>      Cross-service trace by transaction ID"
        echo "  analyze \"<pattern>\" [service]     Deep analysis: single service → T0 anchor"
        echo "                                    → ±10 min chain of events → cross-service trace"
        echo ""
        echo "Environment variables:"
        echo "  MZM_ACCESS_KEY   Required. Your Mezmo access key."
        echo "  MZM_APP          App label to filter logs (default: my-service)"
        echo "  MZM_ENV          Environment label (default: production)"
        echo "  MZM_FROM         Default time range (default: 1h ago)"
        exit 1
        ;;
esac
