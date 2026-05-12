#!/usr/bin/env bash
# =============================================================================
# sabre-execute.sh
# Execute one or more Sabre cryptic commands via the internal API.
#
# USAGE:
#   ./sabre-execute.sh "CMD1" "CMD2" "CMD3" ...
#   echo -e "CMD1\nCMD2" | ./sabre-execute.sh
#
# REQUIRED ENV VARS:
#   SABRE_USER_ID     - Sabre agent user ID
#   SABRE_PASSCODE    - Sabre agent passcode
#
# OPTIONAL ENV VARS:
#   SABRE_ENVIRONMENT - CERT (default)
#   SABRE_SUFFIX      - Agency suffix (default: AAO)
#   SABRE_DUTY_CODE   - Duty code (default: 5)
#
# DEPENDENCIES: curl, jq
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
if ! command -v jq &>/dev/null; then
  echo "❌ ERROR: 'jq' is required but not installed." >&2
  echo "   Install via: brew install jq" >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "❌ ERROR: 'curl' is required but not installed." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Credentials & config
# ---------------------------------------------------------------------------
SABRE_USER_ID="${SABRE_USER_ID:?❌ ERROR: SABRE_USER_ID env var is not set}"
SABRE_PASSCODE="${SABRE_PASSCODE:?❌ ERROR: SABRE_PASSCODE env var is not set}"
SABRE_ENVIRONMENT="${SABRE_ENVIRONMENT:-CERT}"
SABRE_SUFFIX="${SABRE_SUFFIX:-AAO}"
SABRE_DUTY_CODE="${SABRE_DUTY_CODE:-5}"

API_ENDPOINT="https://tapi.adt.aa.com/api/ExecuteScript"

# ---------------------------------------------------------------------------
# Collect commands — from args or stdin
# ---------------------------------------------------------------------------
declare -a COMMANDS=()

if [[ $# -gt 0 ]]; then
  for cmd in "$@"; do
    COMMANDS+=("$cmd")
  done
else
  while IFS= read -r line; do
    [[ -n "$line" ]] && COMMANDS+=("$line")
  done
fi

if [[ ${#COMMANDS[@]} -eq 0 ]]; then
  echo "❌ ERROR: No commands provided." >&2
  echo "   Usage: $0 \"CMD1\" \"CMD2\" ..." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Build JSON payload
# ---------------------------------------------------------------------------
build_payload() {
  local commands_json="[]"
  for cmd in "${COMMANDS[@]}"; do
    commands_json=$(echo "$commands_json" | jq --arg c "$cmd" \
      '. += [{"name": "Command", "value": $c}]')
  done

  jq -n \
    --arg env   "$SABRE_ENVIRONMENT" \
    --arg sfx   "$SABRE_SUFFIX" \
    --arg duty  "$SABRE_DUTY_CODE" \
    --arg uid   "$SABRE_USER_ID" \
    --arg pwd   "$SABRE_PASSCODE" \
    --argjson opts "$commands_json" \
    '{
      "Parameters": {
        "group": [
          {
            "name": "Connection",
            "property": [
              {"name": "Environment",     "value": $env},
              {"name": "Suffix",          "value": $sfx},
              {"name": "DutyCode",        "value": $duty},
              {"name": "Id",              "value": $uid},
              {"name": "CurrentPasscode", "value": $pwd}
            ]
          },
          {
            "name": "Options",
            "property": $opts
          },
          {
            "name": "@@(includeCollection)",
            "property": [
              {"name": "actionAdapterLog",          "value": "true"},
              {"name": "variables",                 "value": "true"},
              {"name": "engineLog",                 "value": "true"},
              {"name": "actionAdapterLogSerialized","value": "true"},
              {"name": "engineLogSerialized",       "value": "true"},
              {"name": "systemVariables",           "value": "false"}
            ]
          },
          {
            "name": "@@(exception)",
            "property": [
              {"name": "stackTraceIsEnabled",     "value": "true"},
              {"name": "innerExceptionIsEnabled", "value": "true"}
            ]
          }
        ]
      },
      "ScriptName": "PSS.ExecuteCommands"
    }'
}

# ---------------------------------------------------------------------------
# Call the API
# ---------------------------------------------------------------------------
call_api() {
  local payload="$1"
  curl --silent --show-error --fail \
    --max-time 30 \
    -X POST "$API_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$payload"
}

# ---------------------------------------------------------------------------
# Parse response — print each command's output in order
# Exits non-zero if Success != "true" or any response starts with ‡
# ---------------------------------------------------------------------------
parse_response() {
  local response="$1"
  local has_error=0

  # Check top-level success
  local success
  success=$(echo "$response" | jq -r '
    .ExecuteScriptResult.group[]
    | select(.name == "Response")
    | .property[]
    | select(.name == "Success")
    | .value' 2>/dev/null || true)

  if [[ "$success" != "true" ]]; then
    echo "❌ API call failed. Raw response:" >&2
    echo "$response" | jq '.' 2>/dev/null || echo "$response" >&2
    return 1
  fi

  # Extract and print each Command_* output in order
  local outputs
  outputs=$(echo "$response" | jq -r '
    .ExecuteScriptResult.group[]
    | select(.name == "Response")
    | .property[]
    | select(.name | startswith("Command_"))
    | .value' 2>/dev/null)

  while IFS= read -r line; do
    echo "$line"
    # Detect Sabre error indicator
    if [[ "$line" == ‡* ]]; then
      has_error=1
    fi
  done <<< "$outputs"

  return $has_error
}

# ---------------------------------------------------------------------------
# Auto-recovery: if ‡FINISH OR IGNORE PNR, run IGD then retry once
# ---------------------------------------------------------------------------
execute_with_recovery() {
  local payload="$1"
  local response

  response=$(call_api "$payload") || {
    echo "❌ HTTP request failed." >&2
    exit 1
  }

  # Check for FINISH OR IGNORE PNR error
  local raw_outputs
  raw_outputs=$(echo "$response" | jq -r '
    .ExecuteScriptResult.group[]
    | select(.name == "Response")
    | .property[]
    | select(.name | startswith("Command_"))
    | .value' 2>/dev/null || true)

  if echo "$raw_outputs" | grep -q "‡FINISH OR IGNORE PNR"; then
    echo "⚠️  Open transaction detected — running IGD to clear, then retrying..." >&2

    # Build and send IGD recovery call
    local igd_payload
    igd_payload=$(COMMANDS=("IGD") build_payload_array)
    call_api "$igd_payload" > /dev/null 2>&1 || true

    # Retry original
    response=$(call_api "$payload") || {
      echo "❌ HTTP request failed on retry." >&2
      exit 1
    }
  fi

  parse_response "$response"
}

# Helper needed by recovery block — rebuild payload with overridden COMMANDS array
build_payload_array() {
  local tmp_cmds=("${COMMANDS[@]}")
  COMMANDS=("IGD")
  build_payload
  COMMANDS=("${tmp_cmds[@]}")
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "🛫 Executing ${#COMMANDS[@]} Sabre command(s) [env: $SABRE_ENVIRONMENT]..." >&2

PAYLOAD=$(build_payload)
execute_with_recovery "$PAYLOAD"
