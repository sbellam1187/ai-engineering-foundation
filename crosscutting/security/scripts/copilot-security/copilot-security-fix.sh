#!/usr/bin/env bash
# Copilot Agent Security Fix — Main Script
#
# Called by workflow-security-0005-copilot-security-fix.yml
# Deployed to: scripts/copilot-security/copilot-security-fix.sh
# Pre-fetches Dependabot and Code Scanning alerts, creates GitHub Issues,
# and assigns them to the copilot-swe-agent bot.
#
# Features:
#   - One issue per Dependabot alert → one PR per fix (clean rollback)
#   - Dynamic parent BOM detection: groups alerts by Maven groupId automatically —
#     ANY dependency with 2+ alerts sharing a groupId gets an umbrella issue
#     (no hardcoded library lists)
#   - Transitive dependency classification in each issue body
#   - Deduplication: skips alerts that already have an open issue or open PR
#     (closed issues do NOT block re-creation — if a vulnerability still exists,
#     a new issue is created)
#   - Auto-close instruction in each issue for Copilot to close when PR is created
#
# Required env vars:
#   REPO             — owner/repo (e.g., AAInternal/my-service)
#   GH_TOKEN         — GITHUB_TOKEN for issue creation and code scanning API
#   OCTO_STS_TOKEN   — ephemeral token from octo-sts (vulnerability_alerts:read)
#   DEPENDABOT_PAT   — PAT for Copilot agent assignment (bot lookup + mutation require PAT)
#   FIX_TYPE         — "all", "dependabot", or "code-scanning"
#   GITHUB_STEP_SUMMARY — path to step summary file (set by Actions)

set -euo pipefail

FIX_TYPE="${FIX_TYPE:-all}"
ISSUES_CREATED=0
TODAY=$(date -u +%Y-%m-%d)

# ── Detect default branch dynamically ──
# Supports repos using either 'main' or 'master' as the default branch.
# Can be overridden via DEFAULT_BRANCH env var if needed.
DEFAULT_BRANCH="${DEFAULT_BRANCH:-$(gh repo view "$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "main")}"

echo "🔍 Creating security fix issues for Copilot cloud agent..."
echo "   Fix type:      $FIX_TYPE"
echo "   Default branch: $DEFAULT_BRANCH"
echo ""

# ── Helper: check if a similar issue already exists (open) ──
issue_exists() {
  local search_term="$1"
  local count
  count=$(gh issue list \
    --repo "$REPO" \
    --label "copilot-security-fix" \
    --search "$search_term in:title" \
    --state open \
    --json number --jq 'length' 2>/dev/null || echo "0")
  [ "$count" != "0" ]
}

# ── Helper: check if an open PR already exists for this fix ──
# Prevents creating duplicate issues when Copilot already opened a PR
# from a previous run and the team hasn't merged/closed it yet.
pr_exists() {
  local search_term="$1"
  local count
  count=$(gh pr list \
    --repo "$REPO" \
    --search "$search_term" \
    --state open \
    --json number --jq 'length' 2>/dev/null || echo "0")
  [ "$count" != "0" ]
}

# ── Helper: combined duplicate check (open issue or open PR) ──
# NOTE: Closed issues do NOT block re-creation. If a vulnerability still exists
# in Dependabot, we create a fresh issue — the old fix may have been incomplete.
already_being_handled() {
  local search_term="$1"
  if issue_exists "$search_term"; then
    echo "open issue"
    return 0
  fi
  if pr_exists "$search_term"; then
    echo "open PR"
    return 0
  fi
  return 1
}

# ── Helper: normalize a Maven groupId to a canonical group key ──
# Strips sub-packages to produce a stable grouping key.
# e.g., "org.springframework.boot" and "org.springframework.security" → "org.springframework"
#       "com.fasterxml.jackson.core" and "com.fasterxml.jackson.datatype" → "com.fasterxml.jackson"
#       "io.netty" → "io.netty"
normalize_group_id() {
  local group_id="$1"
  # Keep first 2–3 segments depending on depth:
  #   org.springframework.* → org.springframework
  #   com.fasterxml.jackson.* → com.fasterxml.jackson
  #   io.netty.* → io.netty
  #   tools.jackson.* → tools.jackson
  local segments
  segments=$(echo "$group_id" | tr '.' '\n' | wc -l | tr -d ' ')
  if [ "$segments" -le 2 ]; then
    echo "$group_id"
  elif [ "$segments" -eq 3 ]; then
    # For 3-segment groupIds, use all 3 (e.g., io.netty, org.yaml)
    # unless the first segment is com/org and third is a broad domain
    echo "$group_id" | cut -d. -f1-3
  else
    # For 4+ segments, use first 3 (e.g., com.fasterxml.jackson)
    echo "$group_id" | cut -d. -f1-3
  fi
}

# ── Helper: derive a human-readable display name from a normalized group key ──
# e.g., "org.springframework" → "Spring Framework"
#       "com.fasterxml.jackson" → "Jackson"
#       "io.netty" → "Netty"
get_group_display_name() {
  local norm_key="$1"
  # Well-known display names (best-effort; falls back to the groupId itself)
  case "$norm_key" in
    org.springframework*)  echo "Spring Framework" ;;
    com.fasterxml.jackson*|tools.jackson*) echo "Jackson" ;;
    io.netty*)             echo "Netty" ;;
    org.apache.tomcat*)    echo "Tomcat" ;;
    org.yaml*)             echo "SnakeYAML" ;;
    org.apache.logging*)   echo "Log4j" ;;
    org.eclipse.jetty*)    echo "Jetty" ;;
    org.bouncycastle*)     echo "Bouncy Castle" ;;
    commons-*|org.apache.commons*) echo "Apache Commons" ;;
    *)                     echo "$norm_key" ;;
  esac
}

# ── Helper: derive a likely Maven property name for a group ──
# e.g., "org.springframework" → "spring-boot-starter-parent"
#       "com.fasterxml.jackson" → "jackson-bom.version"
get_group_property() {
  local norm_key="$1"
  case "$norm_key" in
    org.springframework*)  echo "spring-boot-starter-parent" ;;
    com.fasterxml.jackson*|tools.jackson*) echo "jackson-bom.version" ;;
    io.netty*)             echo "netty.version" ;;
    org.apache.tomcat*)    echo "tomcat.version" ;;
    org.yaml*)             echo "snakeyaml.version" ;;
    *)
      # Derive from the last segment of the groupId: "com.foo.bar" → "bar.version"
      local last_seg
      last_seg=$(echo "$norm_key" | rev | cut -d. -f1 | rev)
      echo "${last_seg}.version"
      ;;
  esac
}

# ── Helper: count open Code Scanning alerts ──
count_code_scanning_alerts() {
  local raw
  if ! raw=$(gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$REPO/code-scanning/alerts?state=open&per_page=100" 2>/dev/null); then
    echo "0"; return
  fi
  if [ -z "$raw" ]; then echo "0"; return; fi
  local msg
  msg=$(echo "$raw" | jq -r '.message // empty' 2>/dev/null)
  if [ -n "$msg" ]; then echo "0"; return; fi
  echo "$raw" | jq 'if type == "array" then length else 0 end' 2>/dev/null | tr -cd '0-9'
}

# ── Helper: fetch Code Scanning alert details as markdown ──
fetch_code_scanning_details() {
  local raw
  if ! raw=$(gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$REPO/code-scanning/alerts?state=open&per_page=100" 2>/dev/null); then
    echo ""; return
  fi
  if [ -z "$raw" ]; then echo ""; return; fi
  local msg
  msg=$(echo "$raw" | jq -r '.message // empty' 2>/dev/null)
  if [ -n "$msg" ]; then echo ""; return; fi

  local table="| # | Rule | Severity | Tool | File | Description |"
  table="${table}
|---|------|----------|------|------|-------------|"

  local details=""
  while IFS= read -r alert_line; do
    local cs_num cs_rule cs_sev cs_tool cs_file cs_desc cs_url
    cs_num=$(echo "$alert_line" | jq -r '.number')
    cs_rule=$(echo "$alert_line" | jq -r '.rule.id // "N/A"')
    cs_sev=$(echo "$alert_line" | jq -r '.rule.security_severity_level // .rule.severity // "N/A"')
    cs_tool=$(echo "$alert_line" | jq -r '.tool.name // "N/A"')
    cs_file=$(echo "$alert_line" | jq -r '.most_recent_instance.location.path // "N/A"')
    cs_desc=$(echo "$alert_line" | jq -r '.rule.description // "N/A"' | head -c 200)
    cs_url=$(echo "$alert_line" | jq -r '.html_url // "N/A"')

    table="${table}
| [#${cs_num}](${cs_url}) | \`${cs_rule}\` | **${cs_sev}** | ${cs_tool} | \`${cs_file}\` | ${cs_desc} |"

    details="${details}

#### Alert #${cs_num}: \`${cs_rule}\` (${cs_sev})
- **Tool**: ${cs_tool}
- **File**: \`${cs_file}\`
- **Description**: ${cs_desc}
- **Link**: ${cs_url}
"
  done < <(echo "$raw" | jq -c '.[]')

  echo "${table}

### Alert Details
${details}"
}

# ── Helper: assign issue to Copilot coding agent ──
# Docs: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-a-pr#assigning-an-issue-to-copilot
# Uses GraphQL addAssigneesToAssignable mutation with agentAssignment input.
# The REST API silently ignores copilot-swe-agent, so GraphQL is required.
# NOTE: Requires DEPENDABOT_PAT — GITHUB_TOKEN and octo-sts tokens cannot
#       see copilot-swe-agent or execute the agentAssignment mutation.
assign_to_copilot_agent() {
  local issue_num="$1"

  if [ -z "${DEPENDABOT_PAT:-}" ]; then
    echo "  ⚠️  DEPENDABOT_PAT not set — cannot assign to Copilot agent"
    echo "  ℹ️  Add DEPENDABOT_PAT secret with a PAT that has repo scope"
    return 1
  fi

  echo "  🤖 Assigning issue #${issue_num} to Copilot coding agent..."

  local repo_owner repo_name
  repo_owner=$(echo "$REPO" | cut -d'/' -f1)
  repo_name=$(echo "$REPO" | cut -d'/' -f2)

  # Step 1: Get copilot-swe-agent bot ID and repo GraphQL ID
  local gql_result
  if ! gql_result=$(GH_TOKEN="$DEPENDABOT_PAT" gh api graphql -f query="
    query {
      repository(owner: \"${repo_owner}\", name: \"${repo_name}\") {
        id
        suggestedActors(capabilities: [CAN_BE_ASSIGNED], first: 100) {
          nodes {
            login
            __typename
            ... on Bot { id }
          }
        }
      }
    }
  " 2>&1); then
    echo "  ⚠️  GraphQL suggestedActors query failed: $(echo "$gql_result" | head -c 200)"
    return 1
  fi

  local bot_id repo_gql_id
  bot_id=$(echo "$gql_result" | jq -r '[.data.repository.suggestedActors.nodes[] | select(.login == "copilot-swe-agent")] | first | .id // empty' 2>/dev/null)
  repo_gql_id=$(echo "$gql_result" | jq -r '.data.repository.id // empty' 2>/dev/null)

  if [ -z "$bot_id" ]; then
    echo "  ⚠️  copilot-swe-agent not found in suggestedActors"
    echo "  📋 Check: Settings → Copilot → Coding agent → Enable"
    return 1
  fi
  echo "  ✅ Found copilot-swe-agent bot"

  # Step 2: Get issue GraphQL global ID
  local issue_gql_id
  if ! issue_gql_id=$(GH_TOKEN="$DEPENDABOT_PAT" gh api graphql -f query="
    query {
      repository(owner: \"${repo_owner}\", name: \"${repo_name}\") {
        issue(number: ${issue_num}) { id }
      }
    }
  " --jq '.data.repository.issue.id' 2>&1); then
    echo "  ⚠️  Failed to get issue GraphQL ID: $(echo "$issue_gql_id" | head -c 200)"
    return 1
  fi

  if [ -z "$issue_gql_id" ]; then
    echo "  ⚠️  Issue GraphQL ID is empty"
    return 1
  fi

  # Step 3: Assign via addAssigneesToAssignable mutation with agentAssignment
  local assign_result
  if assign_result=$(GH_TOKEN="$DEPENDABOT_PAT" gh api graphql \
    -H 'GraphQL-Features: issues_copilot_assignment_api_support,coding_agent_model_selection' \
    -f query="
      mutation {
        addAssigneesToAssignable(input: {
          assignableId: \"${issue_gql_id}\",
          assigneeIds: [\"${bot_id}\"],
          agentAssignment: {
            targetRepositoryId: \"${repo_gql_id}\",
            baseRef: \"${DEFAULT_BRANCH}\",
            customInstructions: \"\",
            customAgent: \"\",
            model: \"\"
          }
        }) {
          assignable {
            ... on Issue {
              id
              title
              assignees(first: 10) {
                nodes { login }
              }
            }
          }
        }
      }
    " 2>&1); then
    local assigned_logins
    assigned_logins=$(echo "$assign_result" | jq -r '[.data.addAssigneesToAssignable.assignable.assignees.nodes[].login] | join(", ")' 2>/dev/null)
    echo "  ✅ Copilot coding agent assigned — assignees: ${assigned_logins}"
    return 0
  else
    echo "  ⚠️  GraphQL assignment failed: $(echo "$assign_result" | head -c 300)"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════
# Dependabot: One issue per alert + parent BOM upgrade detection
# ═══════════════════════════════════════════════════════════
if [ "$FIX_TYPE" = "all" ] || [ "$FIX_TYPE" = "dependabot" ]; then
  echo "📦 Dependabot vulnerability fix..."

  echo "  📡 Fetching open Dependabot alerts via API..."
  DEP_ALERTS_JSON="[]"
  DEP_API_URL="${GITHUB_API_URL:-https://api.github.com}/repos/$REPO/dependabot/alerts?state=open&per_page=100"
  DEP_RESPONSE_FILE=$(mktemp)
  DEP_FETCH_SUCCESS=false

  # ── Try 1: octo-sts token (requires vulnerability_alerts:read in trust policy + App) ──
  if [ -n "${OCTO_STS_TOKEN:-}" ]; then
    DEP_HTTP_CODE=$(curl -s -o "$DEP_RESPONSE_FILE" -w "%{http_code}" \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $OCTO_STS_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$DEP_API_URL" 2>/dev/null || echo "000")

    if [ "$DEP_HTTP_CODE" = "200" ]; then
      DEP_ALERTS_RAW=$(cat "$DEP_RESPONSE_FILE")
      if echo "$DEP_ALERTS_RAW" | jq -e 'type == "array"' >/dev/null 2>&1; then
        DEP_ALERTS_JSON="$DEP_ALERTS_RAW"
        DEP_FETCH_SUCCESS=true
        echo "  ✅ Dependabot API call succeeded (via octo-sts token)"
      else
        DEP_MSG=$(echo "$DEP_ALERTS_RAW" | jq -r '.message // "unknown error"' 2>/dev/null || echo "unknown")
        echo "  ⚠️  Dependabot API returned non-array response: $DEP_MSG"
      fi
    else
      DEP_MSG=$(jq -r '.message // "unknown error"' "$DEP_RESPONSE_FILE" 2>/dev/null || echo "unknown")
      echo "  ⚠️  Dependabot API returned HTTP $DEP_HTTP_CODE with octo-sts token"
      echo "  ℹ️  Response: $DEP_MSG"
    fi
  else
    echo "  ⚠️  OCTO_STS_TOKEN not set — skipping octo-sts attempt"
    echo "  ℹ️  Ensure the octo-sts step succeeded"
  fi


  rm -f "$DEP_RESPONSE_FILE"

  # ── Actionable guidance if both tokens failed ──
  if [ "$DEP_FETCH_SUCCESS" = "false" ]; then
    echo "  ❌ Could not fetch Dependabot alerts — octo-sts token lacks vulnerability_alerts permission"
    echo "  📋 Action required:"
    echo "     1. Ensure .github/chainguard/copilot-security-fix.sts.yaml includes 'vulnerability_alerts: read'"
    echo "     2. The octo-sts GitHub App must have 'Dependabot alerts: Read' at the App level"
    echo "     3. Request the octo-sts team to add this permission: https://github.com/octo-sts/app/issues"
    echo "     4. Verify in repo Settings → Code security → Dependabot alerts is enabled"
  fi

  DEP_ALERT_COUNT=$(echo "$DEP_ALERTS_JSON" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo "0")
  DEP_ALERT_COUNT=${DEP_ALERT_COUNT:-0}
  echo "  📊 Open Dependabot alerts: $DEP_ALERT_COUNT"

  if [ "$DEP_ALERT_COUNT" -eq 0 ]; then
    echo "  ✅ No open Dependabot alerts — skipping issue creation"
  else
    # ── Step 1: Dynamically group alerts by normalized Maven groupId ──
    # ANY groupId with 2+ alerts gets an umbrella issue — no hardcoded library lists.
    echo "  🔍 Dynamically grouping alerts by Maven groupId..."

    GROUP_MAP_FILE=$(mktemp)
    # Format: one line per alert → "normalized_group_key alert_number"

    while IFS= read -r alert_line; do
      a_num=$(echo "$alert_line" | jq -r '.number')
      a_pkg=$(echo "$alert_line" | jq -r '.security_vulnerability.package.name')
      a_group_id=$(echo "$a_pkg" | cut -d: -f1)
      norm_key=$(normalize_group_id "$a_group_id")

      echo "${norm_key} ${a_num}" >> "$GROUP_MAP_FILE"
    done < <(echo "$DEP_ALERTS_JSON" | jq -c '.[]')

    # Track which alerts are covered by a parent upgrade issue
    PARENT_COVERED=""

    # ── Step 2: Create parent upgrade issues for groups with 2+ alerts ──
    # For each normalized groupId that has 2 or more alerts, create one
    # umbrella issue suggesting a parent/BOM version upgrade.
    create_parent_upgrade_issue() {
      local group_name="$1"
      local group_display="$2"
      local group_property="$3"
      local alert_nums_csv="$4"

      # Skip empty groups
      if [ -z "$alert_nums_csv" ]; then
        return
      fi

      local alert_count
      alert_count=$(echo "$alert_nums_csv" | tr ',' '\n' | wc -l | tr -d ' ')

      if [ "$alert_count" -lt 2 ]; then
        return
      fi

      echo "  📦 Parent group '${group_display}' has ${alert_count} alerts — creating umbrella issue"

      local search_key="parent-upgrade: ${group_display}"
      local handled_by
      if handled_by=$(already_being_handled "$search_key"); then
        echo "  ⏭️  Parent upgrade for ${group_display} already has ${handled_by} — skipping"
        return
      fi

      # Build alert table for this group
      local group_table
      group_table="| # | Package | CVE | Severity | Vulnerable Range | Patched Version |
|---|---------|-----|----------|-----------------|-----------------|"

      local group_details=""
      for a_num_iter in $(echo "$alert_nums_csv" | tr ',' ' '); do
        local alert_data g_pkg g_cve g_sev g_range g_patched g_url g_summary
        alert_data=$(echo "$DEP_ALERTS_JSON" | jq -c ".[] | select(.number == $a_num_iter)")
        g_pkg=$(echo "$alert_data" | jq -r '.security_vulnerability.package.name')
        g_cve=$(echo "$alert_data" | jq -r '.security_advisory.cve_id // "N/A"')
        g_sev=$(echo "$alert_data" | jq -r '.security_vulnerability.severity')
        g_range=$(echo "$alert_data" | jq -r '.security_vulnerability.vulnerable_version_range')
        g_patched=$(echo "$alert_data" | jq -r '.security_vulnerability.first_patched_version.identifier // "none"')
        g_url=$(echo "$alert_data" | jq -r '.html_url // "N/A"')
        g_summary=$(echo "$alert_data" | jq -r '.security_advisory.summary // "N/A"' | head -c 200)

        group_table="${group_table}
| [#${a_num_iter}](${g_url}) | \`${g_pkg}\` | ${g_cve} | **${g_sev}** | \`${g_range}\` | ${g_patched} |"

        group_details="${group_details}

#### Alert #${a_num_iter}: \`${g_pkg}\` — ${g_cve}
- **Severity**: ${g_sev}
- **Vulnerable range**: \`${g_range}\`
- **First patched version**: \`${g_patched}\`
- **Summary**: ${g_summary}
- **Link**: ${g_url}
"
      done

      local parent_title="fix(deps): ${search_key} to resolve ${alert_count} CVEs [$TODAY]"


      local parent_body_file
      parent_body_file=$(mktemp)
      cat > "$parent_body_file" <<PARENT_EOF
## 🔒 Parent Upgrade: \`${group_display}\` — Resolve ${alert_count} CVEs

### Why a Parent Upgrade?

Multiple Dependabot alerts (**${alert_count} total**) trace back to transitive dependencies managed by **${group_display}**. Instead of overriding each transitive dependency individually, upgrading the parent BOM or framework version resolves them all at once.

### Affected Alerts

${group_table}

### Alert Details
${group_details}

---

### Task

Investigate whether upgrading the **${group_display}** version (or its BOM property \`${group_property}\`) to the latest stable release resolves all ${alert_count} alerts listed above.

⚠️ **IMPORTANT**: Use ONLY the alert data above. Do NOT guess or hallucinate CVE IDs or patched versions.

### Transitive Dependency Analysis

All ${alert_count} alerts above are suspected to be transitive dependencies managed by **${group_display}**. You MUST verify this:

1. Run \`mvn dependency:tree\` to confirm each vulnerable package is pulled in via ${group_display}
2. If a package is NOT managed by ${group_display}, it needs its own individual fix issue — note this in the PR description
3. Run \`mvn dependency:tree -Dincludes=<groupId>:<artifactId>\` for each alert to trace the dependency chain

### How to fix

1. Read \`pom.xml\` to find the current \`${group_property}\` version or parent BOM version
2. Check the latest stable release of ${group_display}
3. Run \`mvn dependency:tree\` BEFORE the upgrade to capture current transitive versions
4. Update \`${group_property}\` (or parent version) in \`pom.xml\`
5. Run \`mvn dependency:tree\` AFTER the upgrade to confirm all ${alert_count} vulnerable transitive deps are now at patched versions
6. Run \`mvn clean compile -DskipTests\` to verify compilation
7. Run \`mvn test\` to verify no regressions
8. If the major version upgrade causes build failures, document the breaking changes and revert — create individual override issues instead

⚠️ **PARENT UPGRADE NOTE**: If the parent upgrade resolves all alerts, this single PR replaces ${alert_count} individual fixes. If it only partially resolves them, document which alerts remain in the PR description.

#### Agents & Skills:
- **\`@github-vulnerability-fixer\`** — fix strategies, pom.xml conventions, MANDATORY constraints
- **\`dependency-upgrade-scanner\`** skill — Maven dependency classification, BOM rules

#### Auto-close
When creating the PR, include \`Closes #<this-issue-number>\` in the PR description so this issue is automatically closed.

### References
- [Dependabot Alerts](https://github.com/${REPO}/security/dependabot)
- [pom.xml](https://github.com/${REPO}/blob/${DEFAULT_BRANCH}/pom.xml)

*Created by [Copilot Security Fix Automation](https://github.com/${REPO}/actions/workflows/workflow-security-0005-copilot-security-fix.yml) on ${TODAY}*
PARENT_EOF

      echo "  📝 Parent issue body written to temp file ($(wc -c < "$parent_body_file") bytes)"

      if ISSUE_URL=$(gh issue create \
        --repo "$REPO" \
        --title "$parent_title" \
        --body-file "$parent_body_file" \
        --label "security,dependencies,copilot-security-fix" 2>&1); then
          echo "  ✅ Parent upgrade issue created: $ISSUE_URL"
          local issue_num
          issue_num=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')


          if ! assign_to_copilot_agent "$issue_num"; then
            echo "  ℹ️  Manually click 'Assign to Agent' on: $ISSUE_URL"
          fi

          ISSUES_CREATED=$((ISSUES_CREATED + 1))
          PARENT_COVERED="${PARENT_COVERED:+$PARENT_COVERED,}${alert_nums_csv}"
      else
        echo "  ❌ Parent upgrade issue creation failed: $ISSUE_URL"
      fi
      rm -f "$parent_body_file"
    }

    # Dynamically iterate over all groups with 2+ alerts
    while IFS= read -r group_key; do
      # Collect alert numbers for this group
      alert_nums_csv=$(grep "^${group_key} " "$GROUP_MAP_FILE" | awk '{print $2}' | paste -sd ',' -)
      group_display=$(get_group_display_name "$group_key")
      group_property=$(get_group_property "$group_key")
      create_parent_upgrade_issue "$group_key" "$group_display" "$group_property" "$alert_nums_csv"
    done < <(awk '{print $1}' "$GROUP_MAP_FILE" | sort | uniq -c | awk '$1 >= 2 {print $2}')

    rm -f "$GROUP_MAP_FILE"

    # ── Step 3: Create individual issues for remaining (ungrouped) alerts ──
    echo "  📝 Creating individual issues for remaining alerts..."

    while IFS= read -r alert_line; do
      a_num=$(echo "$alert_line" | jq -r '.number')
      a_pkg=$(echo "$alert_line" | jq -r '.security_vulnerability.package.name')
      a_eco=$(echo "$alert_line" | jq -r '.security_vulnerability.package.ecosystem')
      a_sev=$(echo "$alert_line" | jq -r '.security_vulnerability.severity')
      a_range=$(echo "$alert_line" | jq -r '.security_vulnerability.vulnerable_version_range')
      a_patched=$(echo "$alert_line" | jq -r '.security_vulnerability.first_patched_version.identifier // "none"')
      a_cve=$(echo "$alert_line" | jq -r '.security_advisory.cve_id // "N/A"')
      a_ghsa=$(echo "$alert_line" | jq -r '.security_advisory.ghsa_id // "N/A"')
      a_summary=$(echo "$alert_line" | jq -r '.security_advisory.summary // "N/A"')
      a_url=$(echo "$alert_line" | jq -r '.html_url // "N/A"')

      # Skip if covered by a parent upgrade issue
      if echo ",$PARENT_COVERED," | grep -q ",$a_num,"; then
        echo "  ⏭️  Alert #${a_num} (${a_pkg}) covered by parent upgrade — skipping"
        continue
      fi

      search_key="Dependabot alert #${a_num}"
      handled_by=""
      if handled_by=$(already_being_handled "$search_key"); then
        echo "  ⏭️  Alert #${a_num} (${a_pkg}) already has ${handled_by} — skipping"
        continue
      fi


      DEP_TITLE="fix(deps): ${search_key} — ${a_cve} in \`${a_pkg}\` [$TODAY]"

      DEP_BODY_FILE=$(mktemp)
      cat > "$DEP_BODY_FILE" <<ALERT_EOF
## 🔒 Fix ${search_key}: \`${a_pkg}\`

### Alert Details

| Field | Value |
|-------|-------|
| **Alert** | [#${a_num}](${a_url}) |
| **Package** | \`${a_pkg}\` |
| **Ecosystem** | ${a_eco} |
| **CVE** | ${a_cve} |
| **GHSA** | ${a_ghsa} |
| **Severity** | **${a_sev}** |
| **Vulnerable range** | \`${a_range}\` |
| **First patched version** | \`${a_patched}\` |
| **Summary** | ${a_summary} |

---

### Task

Fix **Dependabot alert #${a_num}** for \`${a_pkg}\`. The CVE ID, package name, vulnerable range, and patched version above are authoritative — they were fetched directly from the Dependabot API by this workflow.

⚠️ **IMPORTANT**: Use ONLY the alert data above. Do NOT guess or hallucinate CVE IDs or patched versions. If the patched version is listed as \`none\`, document the alert in the PR description but do not attempt a fix.

### Transitive Dependency Analysis

Before applying a fix, you MUST classify this dependency:

1. **Run** \`mvn dependency:tree -Dincludes=${a_pkg}\` to find where \`${a_pkg}\` comes from
2. **Classify** the dependency as one of:
   - **Direct with version property** → Update the property in \`<properties>\`
   - **Direct with inline version** → Update the \`<version>\` tag
   - **Transitive from Spring Boot BOM** (e.g., jackson, netty, snakeyaml, tomcat) → Add a property override (e.g., \`<jackson-bom.version>\`) — **MUST FIX**
   - **Transitive from non-BOM library** → Do NOT add a direct \`<dependency>\` override; report which parent pulls it in and recommend upgrading the parent
   - **BOM-managed (no version tag)** → Add a property override or upgrade the parent BOM
   - **Plugin dependency** → Add a \`<dependencies>\` block inside the \`<plugin>\`

⚠️ **TRANSITIVE DEPENDENCIES**: If this vulnerability is in a transitive dependency (pulled in by another dependency or BOM, not directly declared in \`pom.xml\`), do NOT add a direct \`<dependency>\` override unless it comes from Spring Boot BOM. Instead:
- If it comes from **Spring Boot BOM**: add a property override (e.g., \`<jackson-bom.version>\`)
- If it comes from **another library**: report it in the PR description, note which parent pulls it in, and recommend upgrading the parent

### How to fix

You MUST follow the **\`@github-vulnerability-fixer\`** agent. That agent has the complete fix workflow, strategy table, pom.xml conventions, and mandatory constraints.

#### ⛔ MANDATORY — Read the agent constraints first:
- Read the \`@github-vulnerability-fixer\` agent (agent-security-0002) — especially the **MANDATORY CONSTRAINTS** section
- Follow the **MUST DO** list (12 items) and **MUST NOT** list (9 items) exactly
- Complete the **PRE-COMMIT VERIFICATION CHECKLIST** before creating the PR

#### Step-by-step:
1. Read \`pom.xml\` to understand the current dependency structure
2. Run \`mvn dependency:tree -Dincludes=${a_pkg}\` to find where it comes from
3. Classify the dependency (direct-property, transitive-BOM, transitive-library, plugin)
4. Apply the matching fix strategy from the agent's strategy table
5. Add a CVE comment next to the change
6. Run \`mvn clean compile -DskipTests\` to verify the fix compiles
7. Run \`mvn dependency:tree\` to confirm patched version is resolved
8. Run \`mvn test\` to ensure nothing is broken

#### Auto-close
When creating the PR, include \`Closes #<this-issue-number>\` in the PR description so this issue is automatically closed.

#### Agents & Skills:
- **\`@github-vulnerability-fixer\`** — fix strategies, pom.xml conventions, MANDATORY constraints
- **\`dependency-upgrade-scanner\`** skill — Maven dependency classification, BOM rules

### References
- [Dependabot Alert #${a_num}](${a_url})
- [pom.xml](https://github.com/${REPO}/blob/${DEFAULT_BRANCH}/pom.xml)

*Created by [Copilot Security Fix Automation](https://github.com/${REPO}/actions/workflows/workflow-security-0005-copilot-security-fix.yml) on ${TODAY}*
ALERT_EOF

      echo "  📝 Issue body for alert #${a_num} written to temp file ($(wc -c < "$DEP_BODY_FILE") bytes)"

      if ISSUE_URL=$(gh issue create \
        --repo "$REPO" \
        --title "$DEP_TITLE" \
        --body-file "$DEP_BODY_FILE" \
        --label "security,dependencies,copilot-security-fix" 2>&1); then
          echo "  ✅ Issue created for alert #${a_num}: $ISSUE_URL"
          ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')


          if ! assign_to_copilot_agent "$ISSUE_NUM"; then
            echo "  ℹ️  Manually click 'Assign to Agent' on: $ISSUE_URL"
          fi

          ISSUES_CREATED=$((ISSUES_CREATED + 1))
      else
        echo "  ❌ Issue creation failed for alert #${a_num}: $ISSUE_URL"
      fi
      rm -f "$DEP_BODY_FILE"
    done < <(echo "$DEP_ALERTS_JSON" | jq -c '.[]')
  fi
fi

# ═══════════════════════════════════════════════════════════
# Code Scanning: Tell Copilot to check and fix CodeQL alerts
# ═══════════════════════════════════════════════════════════
if [ "$FIX_TYPE" = "all" ] || [ "$FIX_TYPE" = "code-scanning" ]; then
  echo ""
  echo "🔍 Code Scanning fix..."

  CS_COUNT=$(count_code_scanning_alerts)
  CS_COUNT=${CS_COUNT:-0}
  echo "  📊 Open Code Scanning alerts: $CS_COUNT"

  if [ "$CS_COUNT" -eq 0 ]; then
    echo "  ✅ No open Code Scanning alerts — skipping issue creation"
  else
    CS_ALERT_DATA=$(fetch_code_scanning_details)
    CS_TITLE="fix(security): remediate Code Scanning alerts [$TODAY]"

    if handled_by=$(already_being_handled "remediate Code Scanning alerts"); then
      echo "  ⏭️  Code Scanning fix already has ${handled_by} — skipping"
    else
      CS_BODY="## 🔍 Fix Code Scanning Security Alerts

### Open Alerts (${CS_COUNT} total — pre-fetched from Code Scanning API)

${CS_ALERT_DATA}

---

### Task

Fix the **${CS_COUNT} open alert(s) listed above**. The rule IDs, severities, file locations, and descriptions above are authoritative — they were fetched directly from the Code Scanning API by this workflow.

⚠️ **IMPORTANT**: Use ONLY the alert data above. Do NOT guess or hallucinate alert details.

### How to fix

For each open Code Scanning alert listed above:
1. Read the affected source file and understand the security issue
2. Apply the minimal fix that resolves the vulnerability without changing behavior
3. Follow project coding standards from \`.github/copilot-instructions.md\`:
   - Java 21 patterns, Spring Boot conventions
   - PMD and Checkstyle compliance (\`exclude-pmd.properties\` for approved suppressions)
   - SonarQube rules from the \`sonarqube-review\` skill (cognitive complexity ≤ 15, no star imports, etc.)
4. Verify: \`mvn clean compile -DskipTests\`
5. Ensure tests pass: \`mvn test\`

#### Agents & Skills:
- **\`@security-scanner\`** — security vulnerability analysis
- **\`sonarqube-review\`** skill — code quality rules, PMD/Checkstyle compliance
- **Standards:** \`.github/copilot-instructions.md\` — project coding standards

### References
- [Code Scanning Alerts](https://github.com/${REPO}/security/code-scanning)

*Created by [Copilot Security Fix Automation](https://github.com/${REPO}/actions/workflows/workflow-security-0005-copilot-security-fix.yml) on ${TODAY}*"

      CS_BODY_FILE=$(mktemp)
      printf '%s' "$CS_BODY" > "$CS_BODY_FILE"
      if ISSUE_URL=$(gh issue create \
        --repo "$REPO" \
        --title "$CS_TITLE" \
        --body-file "$CS_BODY_FILE" \
        --label "security,code-scanning,copilot-security-fix" 2>&1); then
          echo "  ✅ Issue created: $ISSUE_URL"
          ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')

          if ! assign_to_copilot_agent "$ISSUE_NUM"; then
            echo "  ℹ️  Manually click 'Assign to Agent' on: $ISSUE_URL"
          fi

          ISSUES_CREATED=$((ISSUES_CREATED + 1))
      else
        echo "  ❌ Issue creation failed: $ISSUE_URL"
      fi
      rm -f "$CS_BODY_FILE"
    fi
  fi
fi

# ── Summary ──
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo "   Issues created:  $ISSUES_CREATED"
echo "   Fix type:        $FIX_TYPE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Step summary ──
{
  echo "## 🔒 Copilot Security Fix Automation"
  echo ""
  echo "**Issues created:** $ISSUES_CREATED"
  echo "**Fix type:** $FIX_TYPE"
  echo ""
  echo "### How It Works"
  echo "1. This workflow **pre-fetches** Dependabot and Code Scanning alert details via the GitHub API"
  echo "2. **One issue per Dependabot alert** — each alert gets its own issue and PR for clean rollback"
  echo "3. **Dynamic parent BOM detection** — alerts are grouped by Maven \`groupId\` automatically;"
  echo "   ANY dependency family with 2+ open alerts gets an umbrella issue suggesting a parent version"
  echo "   upgrade. No hardcoded library lists — works for Spring Boot, Jackson, Netty, or any groupId."
  echo "4. **Deduplication** — before creating an issue, checks for an existing open issue or open PR"
  echo "   to avoid duplicates. Closed issues do NOT block re-creation — if a vulnerability still"
  echo "   exists in Dependabot, a new issue is created (the previous fix may have been incomplete)."
  echo "5. **Transitive dependency classification** — each issue body includes steps to classify the"
  echo "   dependency (direct, BOM-managed, transitive) and apply the correct fix strategy"
  echo "6. Assigns the issue to \`copilot-swe-agent\` via GraphQL API"
  echo "7. The agent (Settings → Copilot → Cloud agent) autonomously:"
  echo "   - Uses the pre-fetched alert data (no API access needed at runtime)"
  echo "   - Uses \`@github-vulnerability-fixer\` and \`@security-scanner\` agents"
  echo "   - Runs validation: CodeQL, code review, secret scanning, dependency checks"
  echo "   - Edits \`pom.xml\` or source files, verifies build, opens PRs"
  echo "8. **Auto-close** — issues include \`Closes #N\` instruction; the \`close-linked-issues\` job"
  echo "   in this same workflow closes issues when Copilot opens a PR"
  echo ""
  echo "---"
  echo "*Generated on ${TODAY}*"
} >> "$GITHUB_STEP_SUMMARY"
