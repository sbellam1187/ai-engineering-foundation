#!/usr/bin/env bash
# Copilot SonarQube Fix — Main Script
#
# Artifact: workflow-quality-0001-copilot-sonar-fix (companion script)
# Called by workflow-quality-0001-copilot-sonar-fix.yml
# Fetches *new-code* SonarQube issues for a PR, then either:
#   1) Comments on an already-open Copilot Sonar fix PR for this source branch
#   2) Skips if an open sonar-fix issue already exists (agent still working)
#   3) Reopens the previous closed sonar-fix issue with a refreshed body
#   4) Otherwise creates a fresh issue
# In every case where the agent is (re)engaged the issue is closed after a short
# pickup window so future `synchronize` events can reopen the same issue rather
# than spawning duplicates.
#
# Reuse model:
#   - baseRef passed to agentAssignment = PR_HEAD_REF (the source PR feature branch)
#   - Copilot pushes its fix branch (default copilot/…) and opens its PR with
#     base = ${PR_HEAD_REF}.  At most ONE such Copilot Sonar PR exists per
#     source branch — re-runs of this workflow update that PR via comment
#     instead of creating a sibling.
#
# Required env vars:
#   REPO              — owner/repo
#   GH_TOKEN          — GITHUB_TOKEN for issue + PR APIs
#   DEPENDABOT_PAT    — PAT for Copilot agent assignment (GraphQL)
#   SONAR_TOKEN       — SonarQube token with Browse permission
#   SONAR_HOST_URL    — e.g. https://sonarqube.tools.aa.com
#   SONAR_PROJECT_KEY — Sonar project key
#   PR_NUM            — Source pull request number
#   PR_HEAD_REF       — Source PR head branch (Copilot's PR will base off this)
#   PR_HEAD_SHA       — Source PR head commit SHA (used so we wait for SonarQube
#                        to analyse THIS commit, not a stale earlier one)
#   PR_BASE_REF       — Source PR base branch (informational)
#   PR_AUTHOR         — Source PR author login
#   WAIT_MODE         — "strict" (default) waits for Sonar analysis matching
#                        PR_HEAD_SHA, up to 20 min. "loose" accepts any existing
#                        PR analysis with a 2-min cap (use for manual reruns).
#   DRY_RUN           — "true" to skip mutations
#   GITHUB_STEP_SUMMARY — set by Actions

set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"
TODAY=$(date -u +%Y-%m-%d)
LABEL="copilot-sonar-fix"
ISSUES_CREATED=0

SONAR_HOST_URL="${SONAR_HOST_URL%/}"

# ── Detect default branch dynamically ──
# Supports repos using either 'main' or 'master' as the default branch.
# Can be overridden via DEFAULT_BRANCH env var if needed.
DEFAULT_BRANCH="${DEFAULT_BRANCH:-$(gh repo view "$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "main")}"

echo "🛡️ Copilot SonarQube Fix"
echo "   Repo:           $REPO"
echo "   PR:             #$PR_NUM ($PR_HEAD_REF @ ${PR_HEAD_SHA:0:7} → $PR_BASE_REF)"
echo "   Sonar project:  $SONAR_PROJECT_KEY"
echo "   Sonar host:     $SONAR_HOST_URL"
echo "   Default branch: $DEFAULT_BRANCH"
echo "   Dry run:        $DRY_RUN"
echo ""

# ─────────────────────────────────────────────────────────────
# Reuse helpers (mirrors copilot-junit-writer.sh — see runtimes/java-spring/scripts/)
# ─────────────────────────────────────────────────────────────

# Find an existing sonar-fix issue (any state) for this source PR.
# Echoes "<number> <state>" if found, else empty.
find_existing_issue() {
  local search_term="$1"
  gh issue list \
    --repo "$REPO" \
    --label "$LABEL" \
    --search "$search_term in:title" \
    --state all \
    --limit 5 \
    --json number,state,title \
    --jq "[.[] | select(.title | startswith(\"$search_term\"))] | sort_by(.number) | reverse | .[0] | if . then \"\(.number) \(.state)\" else \"\" end" 2>/dev/null || echo ""
}

# Find an open Copilot Sonar fix PR whose base = our source PR branch.
# Echoes the PR number if found, else empty.
find_existing_copilot_pr() {
  local base_ref="$1"
  [ -z "$base_ref" ] && return 0
  gh pr list \
    --repo "$REPO" \
    --state open \
    --base "$base_ref" \
    --limit 20 \
    --json number,author,headRefName,title \
    --jq "[.[] | select(.author.login == \"copilot-swe-agent\" or .author.login == \"app/copilot-swe-agent\" or (.headRefName | test(\"copilot/\"; \"i\")))] | sort_by(.number) | reverse | .[0].number // empty" 2>/dev/null || echo ""
}

# ─────────────────────────────────────────────────────────────
# Sonar API
# ─────────────────────────────────────────────────────────────

sonar_wait_for_pr_analysis() {
  local mode="${WAIT_MODE:-strict}"
  local target_sha="${PR_HEAD_SHA:-}"
  local target_short="${target_sha:0:7}"
  local attempts=0
  local max_attempts
  local last_resp=""

  # Mode selection
  #   strict — require Sonar's latest analysis revision to match PR_HEAD_SHA.
  #            Used for pull_request / workflow_run, where Sonarscan is racing
  #            and we MUST avoid acting on stale findings. Wait up to 20 min.
  #   loose  — accept any existing PR analysis (used for manual workflow_dispatch
  #            re-runs where Sonarscan already finished). Wait up to 2 min.
  if [ "$mode" = "loose" ]; then
    max_attempts=12   # 12 × 10s = 2 min
    echo "🪶 Wait mode: LOOSE (manual run) — accepting any existing Sonar analysis for PR #${PR_NUM}"
  else
    max_attempts=120  # 120 × 10s = 20 min
    if [ -z "$target_sha" ]; then
      echo "::warning::PR_HEAD_SHA not provided — degrading STRICT mode to LOOSE"
      mode="loose"; max_attempts=12
    else
      echo "🎯 Wait mode: STRICT — waiting for Sonar to analyse commit ${target_short} (PR #${PR_NUM})"
    fi
  fi

  # Track how often the SHA endpoint returned an empty revision. Some Sonar
  # versions don't expose .analyses[].revision; after 6 empty responses (~1 min)
  # we degrade STRICT → LOOSE rather than loop forever.
  local empty_revision_streak=0

  while [ "$attempts" -lt "$max_attempts" ]; do
    local latest_sha=""
    local latest_date=""

    # Always probe project_analyses first (gives us SHA + date)
    last_resp=$(curl -sS -u "${SONAR_TOKEN}:" --get \
      --data-urlencode "project=${SONAR_PROJECT_KEY}" \
      --data-urlencode "pullRequest=${PR_NUM}" \
      --data-urlencode "ps=1" \
      "${SONAR_HOST_URL}/api/project_analyses/search" || echo '{}')
    latest_sha=$(echo "$last_resp" | jq -r '.analyses[0].revision // empty' 2>/dev/null)
    latest_date=$(echo "$last_resp" | jq -r '.analyses[0].date // empty' 2>/dev/null)

    # STRICT: succeed only on SHA match
    if [ "$mode" = "strict" ]; then
      if [ -n "$latest_sha" ] && [ "${latest_sha:0:7}" = "$target_short" ]; then
        echo "✅ Sonar analysis found for commit ${target_short} (analyzed at ${latest_date})"
        return 0
      fi
      # Detect API not returning revision → switch to LOOSE so we don't loop forever
      if [ -z "$latest_sha" ]; then
        empty_revision_streak=$((empty_revision_streak + 1))
        if [ "$empty_revision_streak" -ge 6 ]; then
          echo "::warning::Sonar /api/project_analyses/search did not return .revision after 6 attempts — degrading to LOOSE mode"
          mode="loose"
          max_attempts=$((attempts + 6))   # give LOOSE another minute
        fi
      else
        empty_revision_streak=0
      fi
    fi

    # LOOSE: succeed if any analysis exists for this PR
    if [ "$mode" = "loose" ]; then
      # If project_analyses already returned a row, accept it
      if [ -n "$latest_date" ]; then
        local short_sha="${latest_sha:0:7}"
        [ -z "$short_sha" ] && short_sha="<unknown>"
        echo "✅ Sonar analysis present for PR #${PR_NUM} (latest commit=${short_sha} analyzed at ${latest_date})"
        return 0
      fi
      # Otherwise fall back to project_pull_requests/list
      local pr_list_resp
      pr_list_resp=$(curl -sS -u "${SONAR_TOKEN}:" \
        "${SONAR_HOST_URL}/api/project_pull_requests/list?project=${SONAR_PROJECT_KEY}" \
        || echo '{}')
      if echo "$pr_list_resp" | jq -e --arg k "$PR_NUM" '.pullRequests[] | select(.key == $k)' >/dev/null 2>&1; then
        echo "✅ Sonar PR analysis present for PR #${PR_NUM} (no SHA verification in LOOSE mode)"
        return 0
      fi
      last_resp="$pr_list_resp"
    fi

    attempts=$((attempts + 1))
    if [ $((attempts % 6)) -eq 0 ]; then
      local known
      known=$(echo "$last_resp" | jq -r '[.pullRequests[]?.key] | join(", ")' 2>/dev/null || echo "")
      echo "  ⏳ Waiting (${mode}) ($attempts/$max_attempts) — target=${target_short:-<none>} latestAnalyzed=${latest_sha:0:7} knownPRs=[${known:-<none>}]"
    else
      echo "  ⏳ Waiting (${mode}) ($attempts/$max_attempts) — target=${target_short:-<none>} latestAnalyzed=${latest_sha:0:7}"
    fi
    sleep 10
  done

  echo "::warning::Sonar analysis (mode=${mode}) for PR #${PR_NUM} (commit ${target_short:-<unknown>}) not available after $((max_attempts * 10))s"
  echo "::warning::Last API response: $(echo "$last_resp" | head -c 500)"
  return 1
}

# pullRequest=$PR_NUM scopes results to the PR's leak period — no pre-existing debt.
sonar_fetch_pr_issues() {
  local out_file="$1"
  echo "[]" > "$out_file"
  local page=1 page_size=500 merged="[]"
  while :; do
    local resp
    if ! resp=$(curl -sS -u "${SONAR_TOKEN}:" --get \
        --data-urlencode "componentKeys=${SONAR_PROJECT_KEY}" \
        --data-urlencode "pullRequest=${PR_NUM}" \
        --data-urlencode "resolved=false" \
        --data-urlencode "types=BUG,VULNERABILITY,CODE_SMELL" \
        --data-urlencode "ps=${page_size}" \
        --data-urlencode "p=${page}" \
        "${SONAR_HOST_URL}/api/issues/search"); then
      echo "::error::Sonar /api/issues/search failed"
      return 1
    fi
    merged=$(jq -s '.[0] + (.[1].issues // [])' \
      <(echo "$merged") <(echo "$resp"))
    local total fetched
    total=$(echo "$resp" | jq -r '.paging.total // 0')
    fetched=$(echo "$merged" | jq 'length')
    if [ "$fetched" -ge "$total" ] || [ "$fetched" -eq 0 ]; then break; fi
    page=$((page + 1))
    [ "$page" -gt 20 ] && break
  done
  echo "$merged" > "$out_file"
}

sonar_fetch_pr_hotspots() {
  local out_file="$1"
  echo "[]" > "$out_file"
  local resp
  if ! resp=$(curl -sS -u "${SONAR_TOKEN}:" --get \
      --data-urlencode "projectKey=${SONAR_PROJECT_KEY}" \
      --data-urlencode "pullRequest=${PR_NUM}" \
      --data-urlencode "status=TO_REVIEW" \
      --data-urlencode "ps=500" \
      "${SONAR_HOST_URL}/api/hotspots/search"); then
    echo "::warning::Sonar /api/hotspots/search failed"
    return 0
  fi
  echo "$resp" | jq '.hotspots // []' > "$out_file"
}

# ─────────────────────────────────────────────────────────────
# Copilot agent assignment (mirrors copilot-junit-writer.sh — see runtimes/java-spring/scripts/)
# ─────────────────────────────────────────────────────────────

# Remove copilot-swe-agent from an issue's assignees so the next add fires a
# fresh assignment event. Re-assigning a bot that's already an assignee is a
# no-op for the Copilot Coding Agent — it won't start a new session.
# Always returns 0: this is best-effort and must NEVER fail the script.
unassign_copilot_from_issue() {
  local issue_num="$1"

  if [ -z "${DEPENDABOT_PAT:-}" ]; then
    echo "  ℹ️  DEPENDABOT_PAT not set — skipping unassign step"
    return 0
  fi

  local repo_owner repo_name
  repo_owner=$(echo "$REPO" | cut -d'/' -f1)
  repo_name=$(echo "$REPO" | cut -d'/' -f2)

  # Step 1: ask the issue ONLY for assignee logins. The `assignees` connection
  # returns the `User` type (Copilot included — its bot identity surfaces as a
  # User in this connection), so we MUST NOT spread `... on Bot { id }` here —
  # that produces `cannotSpreadFragment` errors.
  local lookup
  if ! lookup=$(GH_TOKEN="$DEPENDABOT_PAT" gh api graphql -f query="
    query {
      repository(owner: \"${repo_owner}\", name: \"${repo_name}\") {
        issue(number: ${issue_num}) {
          id
          assignees(first: 20) { nodes { login } }
        }
      }
    }
  " 2>&1); then
    echo "  ⚠️  Unassign lookup failed (continuing): $(echo "$lookup" | head -c 200)"
    return 0
  fi

  local issue_gql_id has_copilot
  issue_gql_id=$(echo "$lookup" | jq -r '.data.repository.issue.id // empty' 2>/dev/null || echo "")
  has_copilot=$(echo "$lookup" | jq -r '[.data.repository.issue.assignees.nodes[] | select(.login == "copilot-swe-agent" or .login == "Copilot")] | length' 2>/dev/null || echo "0")

  if [ -z "$issue_gql_id" ] || [ "$has_copilot" = "0" ]; then
    echo "  ℹ️  copilot-swe-agent not currently assigned to issue #${issue_num} — nothing to remove"
    return 0
  fi

  # Step 2: resolve the Copilot bot's GraphQL node ID via suggestedActors —
  # the same proven pattern used by assign_to_copilot_agent below. Here `Bot`
  # IS in the union (suggestedActors returns Actor), so spreading is legal.
  local bot_lookup bot_id
  if ! bot_lookup=$(GH_TOKEN="$DEPENDABOT_PAT" gh api graphql -f query="
    query {
      repository(owner: \"${repo_owner}\", name: \"${repo_name}\") {
        suggestedActors(capabilities: [CAN_BE_ASSIGNED], first: 100) {
          nodes { login ... on Bot { id } ... on User { id } }
        }
      }
    }
  " 2>&1); then
    echo "  ⚠️  Bot id lookup failed (continuing): $(echo "$bot_lookup" | head -c 200)"
    return 0
  fi
  bot_id=$(echo "$bot_lookup" | jq -r '[.data.repository.suggestedActors.nodes[] | select(.login == "copilot-swe-agent")] | first | .id // empty' 2>/dev/null || echo "")

  if [ -z "$bot_id" ]; then
    echo "  ℹ️  Could not resolve copilot-swe-agent bot id — skipping unassign"
    return 0
  fi

  echo "  ↩️  Removing copilot-swe-agent from issue #${issue_num} so re-add fires a fresh assignment event"
  GH_TOKEN="$DEPENDABOT_PAT" gh api graphql -f query="
    mutation {
      removeAssigneesFromAssignable(input: {
        assignableId: \"${issue_gql_id}\",
        assigneeIds: [\"${bot_id}\"]
      }) { clientMutationId }
    }
  " >/dev/null 2>&1 || echo "  ⚠️  removeAssigneesFromAssignable mutation failed (continuing)"
  # Small pause so GitHub registers the removal before we re-add
  sleep 3
  return 0
}

assign_to_copilot_agent() {
  local issue_num="$1"
  local base_ref="${PR_HEAD_REF:-${DEFAULT_BRANCH}}"

  if [ -z "${DEPENDABOT_PAT:-}" ]; then
    echo "  ⚠️  DEPENDABOT_PAT not set — cannot assign to Copilot agent"
    return 1
  fi

  echo "  🤖 Assigning issue #${issue_num} to Copilot coding agent (baseRef=$base_ref)..."

  local repo_owner repo_name
  repo_owner=$(echo "$REPO" | cut -d'/' -f1)
  repo_name=$(echo "$REPO" | cut -d'/' -f2)

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
            ... on User { id }
          }
        }
      }
    }
  " 2>&1); then
    echo "  ⚠️  GraphQL suggestedActors query failed: $(echo "$gql_result" | head -c 200)"
    return 1
  fi

  local bot_id repo_gql_id
  bot_id=$(echo "$gql_result" | jq -r '[.data.repository.suggestedActors.nodes[] | select(.login == "copilot-swe-agent")] | first | .id // empty')
  repo_gql_id=$(echo "$gql_result" | jq -r '.data.repository.id // empty')

  if [ -z "$bot_id" ]; then
    echo "  ⚠️  copilot-swe-agent not found — enable Copilot coding agent in repo settings"
    return 1
  fi

  local issue_gql_id
  issue_gql_id=$(GH_TOKEN="$DEPENDABOT_PAT" gh api graphql -f query="
    query {
      repository(owner: \"${repo_owner}\", name: \"${repo_name}\") {
        issue(number: ${issue_num}) { id }
      }
    }
  " --jq '.data.repository.issue.id' 2>/dev/null || echo "")

  [ -z "$issue_gql_id" ] && { echo "  ⚠️  Could not get issue GraphQL ID"; return 1; }

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
            baseRef: \"${base_ref}\",
            customInstructions: \"\",
            customAgent: \"\",
            model: \"\"
          }
        }) {
          assignable { ... on Issue { assignees(first: 10) { nodes { login } } } }
        }
      }
    " 2>&1); then
    local assigned
    assigned=$(echo "$assign_result" | jq -r '[.data.addAssigneesToAssignable.assignable.assignees.nodes[].login] | join(", ")')
    echo "  ✅ Copilot agent assigned — assignees: ${assigned}"
    return 0
  fi
  echo "  ⚠️  GraphQL assignment failed: $(echo "$assign_result" | head -c 300)"
  return 1
}

# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

for v in SONAR_TOKEN SONAR_HOST_URL SONAR_PROJECT_KEY; do
  if [ -z "${!v:-}" ]; then
    echo "::error::Required secret $v is not set"
    exit 1
  fi
done

sonar_wait_for_pr_analysis || true

ISSUES_FILE=$(mktemp)
HOTSPOTS_FILE=$(mktemp)
sonar_fetch_pr_issues "$ISSUES_FILE"
sonar_fetch_pr_hotspots "$HOTSPOTS_FILE"

ISSUE_COUNT=$(jq 'length' "$ISSUES_FILE")
HOTSPOT_COUNT=$(jq 'length' "$HOTSPOTS_FILE")
TOTAL=$((ISSUE_COUNT + HOTSPOT_COUNT))
BUG_COUNT=$(jq '[.[] | select(.type == "BUG")] | length' "$ISSUES_FILE")
VULN_COUNT=$(jq '[.[] | select(.type == "VULNERABILITY")] | length' "$ISSUES_FILE")
SMELL_COUNT=$(jq '[.[] | select(.type == "CODE_SMELL")] | length' "$ISSUES_FILE")
BLOCKER_COUNT=$(jq '[.[] | select(.severity == "BLOCKER")] | length' "$ISSUES_FILE")
CRIT_COUNT=$(jq '[.[] | select(.severity == "CRITICAL")] | length' "$ISSUES_FILE")

echo "📊 Sonar findings on new code in PR #$PR_NUM:"
echo "   Bugs=$BUG_COUNT  Vulns=$VULN_COUNT  Smells=$SMELL_COUNT  Hotspots=$HOTSPOT_COUNT"
echo "   Total=$TOTAL  (BLOCKER=$BLOCKER_COUNT CRITICAL=$CRIT_COUNT)"
echo ""

if [ "$TOTAL" -eq 0 ]; then
  echo "✅ No new-code Sonar findings — nothing to do"
  cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🛡️ Copilot SonarQube Fix — PR #${PR_NUM}
✅ No new-code Sonar findings on \`${PR_HEAD_REF}\`.
EOF
  rm -f "$ISSUES_FILE" "$HOTSPOTS_FILE"
  exit 0
fi

# Build markdown table
build_table() {
  local heading="$1" jq_expr="$2" source_file="$3"
  local count
  count=$(jq "[$jq_expr] | length" "$source_file")
  [ "$count" -eq 0 ] && return 0
  echo ""
  echo "### $heading ($count)"
  echo ""
  echo "| Severity | Rule | File | Line | Message |"
  echo "|----------|------|------|------|---------|"
  jq -r "[$jq_expr] | .[] |
    \"| \" + (.severity // .vulnerabilityProbability // \"-\") +
    \" | \`\" + (.rule // .ruleKey // \"-\") + \"\`\" +
    \" | \`\" + ((.component // \"\") | sub(\"^[^:]*:\"; \"\")) + \"\`\" +
    \" | \" + ((.line // .textRange.startLine // \"-\") | tostring) +
    \" | \" + ((.message // \"\") | gsub(\"\\\\|\"; \"\\\\|\") | gsub(\"\\n\"; \" \")) +
    \" |\"" "$source_file"
}

TABLE_FILE=$(mktemp)
{
  build_table "🐛 Bugs"             '.[] | select(.type == "BUG")'           "$ISSUES_FILE"
  build_table "🔒 Vulnerabilities"  '.[] | select(.type == "VULNERABILITY")' "$ISSUES_FILE"
  build_table "🧹 Code Smells"      '.[] | select(.type == "CODE_SMELL")'    "$ISSUES_FILE"
  build_table "⚠️ Security Hotspots" '.[]'                                    "$HOTSPOTS_FILE"
} > "$TABLE_FILE"
# Pre-read the table once so heredocs don't run command substitutions under
# `set -euo pipefail` (which can blow up if cat returns non-zero / file empty).
TABLE_CONTENT=""
if [ -s "$TABLE_FILE" ]; then
  TABLE_CONTENT=$(cat "$TABLE_FILE" 2>/dev/null || echo "")
fi

SEARCH_KEY="sonar: fix new-code findings for PR #${PR_NUM}"
SONAR_PR_DASHBOARD="${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}&pullRequest=${PR_NUM}"

# Resolve the tracking issue (any state) up-front so both Tier 1 and Tier 3/4
# can use it. Tier 1 needs it to re-engage Copilot on the existing fix PR.
EXISTING_ISSUE_INFO=$(find_existing_issue "$SEARCH_KEY")
EXISTING_ISSUE_NUM=""
EXISTING_ISSUE_STATE=""
if [ -n "$EXISTING_ISSUE_INFO" ]; then
  EXISTING_ISSUE_NUM=$(echo "$EXISTING_ISSUE_INFO" | awk '{print $1}')
  EXISTING_ISSUE_STATE=$(echo "$EXISTING_ISSUE_INFO" | awk '{print $2}')
fi

# ─────────────────────────────────────────────────────────────
# Tier 1 — REPLACE strategy
#   If an existing Copilot Sonar PR is open against this source branch,
#   close it (and delete its head branch) so we can hand Copilot a clean
#   slate. We then fall through to Tier 3/4 to create a brand-new
#   tracking issue + fresh fix PR containing ALL current Sonar findings.
#   Rationale: re-engaging an existing Copilot session reliably fails
#   (permission / no-op assignment / "awaiting approval"), so it is
#   simpler and more deterministic to start over.
# ─────────────────────────────────────────────────────────────
EXISTING_COPILOT_PR=$(find_existing_copilot_pr "${PR_HEAD_REF:-}")

if [ -n "$EXISTING_COPILOT_PR" ]; then
  echo "🗑️  Found existing Copilot Sonar PR #${EXISTING_COPILOT_PR} targeting '${PR_HEAD_REF}' — closing it so a fresh PR can be created with the latest findings"

  if [ "$DRY_RUN" = "true" ]; then
    echo "  🏃 DRY RUN — would close PR #${EXISTING_COPILOT_PR} (and delete its branch) and create a new fix issue with ${TOTAL} finding(s)"
    cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🛡️ Copilot SonarQube Fix — PR #${PR_NUM} (DRY RUN)
Would close existing Copilot Sonar PR [#${EXISTING_COPILOT_PR}](https://github.com/${REPO}/pull/${EXISTING_COPILOT_PR}) and create a fresh fix PR with **${TOTAL}** finding(s).
EOF
    rm -f "$ISSUES_FILE" "$HOTSPOTS_FILE" "$TABLE_FILE"
    exit 0
  fi

  # Look up the existing PR's head branch BEFORE closing so we can delete it
  # explicitly afterwards (gh's --delete-branch is best-effort and silently
  # skips when it can't run a local checkout, which is the case in CI).
  OLD_HEAD_REF=$(gh pr view "$EXISTING_COPILOT_PR" --repo "$REPO" --json headRefName --jq '.headRefName' 2>/dev/null || echo "")

  # Step 1: close the PR with an explanatory comment. Try with --delete-branch
  # first (works when the branch is in the same repo and not protected); fall
  # back to a plain close if that fails.
  CLOSE_OK=false
  if gh pr close "$EXISTING_COPILOT_PR" --repo "$REPO" --delete-branch \
      --comment "🗑️ Superseded by a fresh Copilot SonarQube fix PR — source PR #${PR_NUM} has new commits and we're starting over with all current Sonar findings (auto-closed by [Copilot SonarQube Fix](https://github.com/${REPO}/actions/workflows/workflow-quality-0001-copilot-sonar-fix.yml))." \
      >/dev/null 2>&1; then
    CLOSE_OK=true
    echo "  ✅ Closed Copilot PR #${EXISTING_COPILOT_PR} (gh requested branch delete)"
  elif gh pr close "$EXISTING_COPILOT_PR" --repo "$REPO" \
      --comment "🗑️ Superseded — see fresh Copilot SonarQube fix PR (auto-closed by Copilot SonarQube Fix workflow)." \
      >/dev/null 2>&1; then
    CLOSE_OK=true
    echo "  ✅ Closed Copilot PR #${EXISTING_COPILOT_PR} (without --delete-branch)"
  else
    echo "  ⚠️  Failed to close Copilot PR #${EXISTING_COPILOT_PR} — continuing anyway"
  fi

  # Step 2: explicitly delete the head branch via the REST API. This runs
  # even when --delete-branch above succeeded (it's idempotent — a missing
  # ref returns 422 which we ignore). Skip protected refs.
  if [ -n "$OLD_HEAD_REF" ] \
      && [ "$OLD_HEAD_REF" != "$PR_HEAD_REF" ] \
      && [ "$OLD_HEAD_REF" != "master" ] \
      && [ "$OLD_HEAD_REF" != "main" ]; then
    DELETE_OUT=$(gh api -X DELETE "repos/${REPO}/git/refs/heads/${OLD_HEAD_REF}" 2>&1) \
      && echo "  🗑️  Deleted branch '${OLD_HEAD_REF}' via REST API" \
      || echo "  ℹ️  Branch '${OLD_HEAD_REF}' not deleted (may already be gone): $(echo "$DELETE_OUT" | head -c 200)"
  else
    echo "  ℹ️  Skipping explicit branch delete (head='${OLD_HEAD_REF:-<unknown>}')"
  fi

  # If the prior tracking issue is still open, close it too so Tier 4
  # creates a brand-new issue (rather than Tier 3 "reopen previous").
  if [ -n "$EXISTING_ISSUE_NUM" ] && [ "$EXISTING_ISSUE_STATE" = "OPEN" ]; then
    gh issue close "$EXISTING_ISSUE_NUM" --repo "$REPO" \
      --comment "🗑️ Superseded — closing so a fresh tracking issue can be created with the latest Sonar findings for PR #${PR_NUM}." \
      >/dev/null 2>&1 \
      && echo "  ✅ Closed prior tracking issue #${EXISTING_ISSUE_NUM}" \
      || echo "  ⚠️  Failed to close prior tracking issue #${EXISTING_ISSUE_NUM}"
    EXISTING_ISSUE_STATE="CLOSED"
  fi

  # Force Tier 4 path (create new issue) by clearing the "previous issue"
  # marker — we do NOT want to reopen the now-stale prior issue.
  EXISTING_ISSUE_NUM=""
  EXISTING_ISSUE_STATE=""

  echo "  ➡️  Falling through to create a fresh tracking issue + Copilot fix PR for ${TOTAL} finding(s)"
  # NOTE: we intentionally do NOT exit here — execution continues into the
  # Tier 4 "build issue body" + "create new issue" block below.
fi

# Legacy Tier 1 reuse logic (commented out — replaced by the close-and-recreate
# strategy above). Kept here for reference in case we want to reintroduce it.
if false; then
  :

  # 1. Comment on the existing Copilot PR with the refreshed findings table
  COMMENT_BODY_FILE=$(mktemp)
  {
    cat <<COMMENT_HEAD
@copilot please push additional fixes to this PR.

🔄 **Updated Sonar findings from PR #${PR_NUM} (commit on ${TODAY})**

The source PR has new commits and SonarQube re-analyzed the new code. **Push the additional fixes onto this PR's existing branch** — do not open a new one.

### Summary
| 🐛 Bugs | 🔒 Vulns | 🧹 Smells | ⚠️ Hotspots | 🚨 Blocker | ❗ Critical | **Total** |
|--------|---------|----------|------------|-----------|------------|-----------|
| ${BUG_COUNT} | ${VULN_COUNT} | ${SMELL_COUNT} | ${HOTSPOT_COUNT} | ${BLOCKER_COUNT} | ${CRIT_COUNT} | **${TOTAL}** |

[Sonar PR dashboard](${SONAR_PR_DASHBOARD})
COMMENT_HEAD
    cat "$TABLE_FILE"
    cat <<COMMENT_TAIL

Continue to follow standards from \`.github/copilot-instructions.md\` and the \`sonarqube-review\` skill (cognitive complexity ≤ 15, no star imports, PMD/Checkstyle clean, SLF4J parameterised logging). Ensure \`mvn clean compile -DskipTests\` and \`mvn test\` still pass.

*Auto-updated by [Copilot SonarQube Fix](https://github.com/${REPO}/actions/workflows/workflow-quality-0001-copilot-sonar-fix.yml)*
COMMENT_TAIL
  } > "$COMMENT_BODY_FILE"

  # IMPORTANT: post this comment as the PAT user (NOT github-actions[bot]).
  # GitHub silently ignores @copilot mentions from bot accounts to prevent
  # infinite loops, so a comment authored by github-actions[bot] would NOT
  # trigger the Copilot Coding Agent. Using DEPENDABOT_PAT makes the comment
  # appear authored by the underlying user, so @copilot fires correctly.
  COMMENT_OK=false
  if [ -n "${DEPENDABOT_PAT:-}" ]; then
    echo "  📝 Posting PR comment using DEPENDABOT_PAT (so @copilot mention fires)..."
    PAT_COMMENT_OUT=$(GH_TOKEN="$DEPENDABOT_PAT" gh pr comment "$EXISTING_COPILOT_PR" --repo "$REPO" --body-file "$COMMENT_BODY_FILE" 2>&1) \
      && COMMENT_OK=true \
      || echo "  ⚠️  PAT comment failed: $(echo "$PAT_COMMENT_OUT" | head -c 400)"
  else
    echo "  ⚠️  DEPENDABOT_PAT not set — will use GITHUB_TOKEN (Copilot will likely ignore the @mention)"
  fi
  if [ "$COMMENT_OK" = "false" ]; then
    echo "  📝 Posting PR comment using GITHUB_TOKEN as fallback..."
    GHA_COMMENT_OUT=$(gh pr comment "$EXISTING_COPILOT_PR" --repo "$REPO" --body-file "$COMMENT_BODY_FILE" 2>&1) \
      && COMMENT_OK=true \
      || echo "  ⚠️  GITHUB_TOKEN comment also failed: $(echo "$GHA_COMMENT_OUT" | head -c 400)"
  fi
  if [ "$COMMENT_OK" = "true" ]; then
    echo "  ✅ Posted update comment on Copilot PR #${EXISTING_COPILOT_PR}"
  else
    echo "  ❌ Failed to post any comment on Copilot PR #${EXISTING_COPILOT_PR}"
  fi
  rm -f "$COMMENT_BODY_FILE"

  # 2. Re-engage the Copilot agent via the tracking issue. The agent detects it
  #    already has an open PR with base=$PR_HEAD_REF and pushes new commits onto
  #    that same branch instead of opening a second PR.
  REENGAGED=false
  if [ -n "$EXISTING_ISSUE_NUM" ]; then
    echo "  🔁 Reopening tracking issue #${EXISTING_ISSUE_NUM} with refreshed Sonar findings to re-engage Copilot"
    REOPEN_BODY_FILE=$(mktemp)
    cat > "$REOPEN_BODY_FILE" <<REOPEN_EOF
## 🛡️ Updated SonarQube New-Code Findings — PR #${PR_NUM}

Source PR \`${PR_HEAD_REF}\` has new commits. SonarQube re-analyzed and now reports **${TOTAL}** new-code finding(s).

> ⚠️ A Copilot fix PR already exists: [#${EXISTING_COPILOT_PR}](https://github.com/${REPO}/pull/${EXISTING_COPILOT_PR}).
> **Push the additional fixes as new commits to that PR's existing branch.** Do not open a new PR.

### Summary
| Category | Count |
|----------|-------|
| 🐛 Bugs | ${BUG_COUNT} |
| 🔒 Vulnerabilities | ${VULN_COUNT} |
| 🧹 Code Smells | ${SMELL_COUNT} |
| ⚠️ Security Hotspots | ${HOTSPOT_COUNT} |
| **Total** | **${TOTAL}** |
| 🚨 Blocker | ${BLOCKER_COUNT} |
| ❗ Critical | ${CRIT_COUNT} |

${TABLE_CONTENT}

### Constraints (unchanged)
- ✅ Push commits to the existing Copilot PR \`#${EXISTING_COPILOT_PR}\` (base = \`${PR_HEAD_REF}\`).
- ❌ Do **not** open a second fix PR.
- ❌ Do **not** branch from the default branch (\`${DEFAULT_BRANCH}\`).
- ❌ Do **not** modify unrelated files.

### Verification
\`\`\`bash
mvn clean compile -DskipTests
mvn test
\`\`\`

Include \`Closes #${EXISTING_ISSUE_NUM}\` in the PR description (if not already).

*Auto-refreshed by [Copilot SonarQube Fix](https://github.com/${REPO}/actions/workflows/workflow-quality-0001-copilot-sonar-fix.yml) on ${TODAY}.*
REOPEN_EOF

    REFRESHED_TITLE="${SEARCH_KEY} [$TODAY]"
    gh issue edit "$EXISTING_ISSUE_NUM" --repo "$REPO" \
      --title "$REFRESHED_TITLE" \
      --body-file "$REOPEN_BODY_FILE" >/dev/null 2>&1 || echo "  ⚠️  Failed to edit issue #${EXISTING_ISSUE_NUM}"
    if [ "$EXISTING_ISSUE_STATE" != "OPEN" ]; then
      gh issue reopen "$EXISTING_ISSUE_NUM" --repo "$REPO" \
        --comment "🔄 Reopened — PR #${PR_NUM} has new commits with additional Sonar findings. Push the new fixes onto the existing Copilot PR #${EXISTING_COPILOT_PR}." >/dev/null 2>&1 || true
    fi
    rm -f "$REOPEN_BODY_FILE"

    # Force a fresh assignment event: remove copilot-swe-agent first, then re-add.
    # Without this, the Copilot Coding Agent treats the re-assignment as a no-op
    # because it already has an open PR for this baseRef.
    # `|| true` so a transient GraphQL error never fails the whole job.
    unassign_copilot_from_issue "$EXISTING_ISSUE_NUM" || true

    if assign_to_copilot_agent "$EXISTING_ISSUE_NUM"; then
      REENGAGED=true
      echo "  ⏳ Waiting 2 minutes for Copilot agent to pick up issue #${EXISTING_ISSUE_NUM}..."
      sleep 120
      echo "  🔒 Closing issue #${EXISTING_ISSUE_NUM} after agent pickup..."
      gh issue close "$EXISTING_ISSUE_NUM" --repo "$REPO" \
        --comment "✅ Closed automatically — issue was reassigned to Copilot coding agent." 2>/dev/null || true
    fi
  fi

  if [ "$REENGAGED" = "false" ]; then
    # No tracking issue exists yet (rare: PR was created manually), so create
    # a fresh issue scoped to "push fixes to existing PR".
    echo "  ℹ️  No tracking issue found — creating a new one to re-engage Copilot on PR #${EXISTING_COPILOT_PR}"
    NEW_ISSUE_BODY_FILE=$(mktemp)
    cat > "$NEW_ISSUE_BODY_FILE" <<NEW_EOF
## 🛡️ Push additional Sonar fixes to existing PR #${EXISTING_COPILOT_PR}

PR #${PR_NUM} (\`${PR_HEAD_REF}\`) has new commits introducing **${TOTAL}** additional Sonar finding(s).
A Copilot fix PR already exists: [#${EXISTING_COPILOT_PR}](https://github.com/${REPO}/pull/${EXISTING_COPILOT_PR}).

**Push the additional fixes as new commits to that PR's existing branch.** Do not open a new PR.

${TABLE_CONTENT}

Verification: \`mvn clean compile -DskipTests\` && \`mvn test\`.

Include \`Closes #<this-issue-number>\` in the PR description.

*Created by [Copilot SonarQube Fix](https://github.com/${REPO}/actions/workflows/workflow-quality-0001-copilot-sonar-fix.yml) on ${TODAY}.*
NEW_EOF
    NEW_ISSUE_TITLE="${SEARCH_KEY} [$TODAY]"
    if NEW_ISSUE_URL=$(gh issue create --repo "$REPO" \
        --title "$NEW_ISSUE_TITLE" \
        --body-file "$NEW_ISSUE_BODY_FILE" \
        --label "sonarqube,code-quality,${LABEL}" 2>&1); then
      NEW_ISSUE_NUM=$(echo "$NEW_ISSUE_URL" | grep -oE '[0-9]+$')
      echo "  ✅ Issue created: $NEW_ISSUE_URL"
      if assign_to_copilot_agent "$NEW_ISSUE_NUM"; then
        sleep 120
        gh issue close "$NEW_ISSUE_NUM" --repo "$REPO" \
          --comment "✅ Closed automatically — assigned to Copilot agent." 2>/dev/null || true
      fi
    else
      echo "  ❌ Failed to create re-engagement issue: $NEW_ISSUE_URL"
    fi
    rm -f "$NEW_ISSUE_BODY_FILE"
  fi

  cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🛡️ Copilot SonarQube Fix — PR #${PR_NUM}
🔁 Re-engaged Copilot on existing Sonar PR [#${EXISTING_COPILOT_PR}](https://github.com/${REPO}/pull/${EXISTING_COPILOT_PR}) with **${TOTAL}** finding(s).
The agent will push new commits onto the existing fix branch.
EOF
  rm -f "$ISSUES_FILE" "$HOTSPOTS_FILE" "$TABLE_FILE"
  exit 0
fi  # end of "if false" wrapper around legacy Tier 1 reuse logic

# ─────────────────────────────────────────────────────────────
# Tier 2/3 — open issue (skip) or closed issue (reopen)
# ─────────────────────────────────────────────────────────────

if [ -n "$EXISTING_ISSUE_NUM" ] && [ "$EXISTING_ISSUE_STATE" = "OPEN" ]; then
  echo "⏭️  Open issue #${EXISTING_ISSUE_NUM} already exists for PR #${PR_NUM} — skipping (Copilot agent still working)"
  cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🛡️ Copilot SonarQube Fix — PR #${PR_NUM}
⏭️ Open issue [#${EXISTING_ISSUE_NUM}](https://github.com/${REPO}/issues/${EXISTING_ISSUE_NUM}) already exists. Skipping.
- **Findings**: ${TOTAL}
EOF
  rm -f "$ISSUES_FILE" "$HOTSPOTS_FILE" "$TABLE_FILE"
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Tier 4 — build issue body (used both for create and reopen)
# ─────────────────────────────────────────────────────────────
ISSUE_TITLE="${SEARCH_KEY} [$TODAY]"
ISSUE_BODY_FILE=$(mktemp)

cat > "$ISSUE_BODY_FILE" <<ISSUE_EOF
## 🛡️ SonarQube New-Code Findings — PR #${PR_NUM}

SonarQube detected **${TOTAL}** new-code issue(s) introduced by PR [#${PR_NUM}](https://github.com/${REPO}/pull/${PR_NUM}) by @${PR_AUTHOR}.

### Summary

| Category | Count |
|----------|-------|
| 🐛 Bugs | ${BUG_COUNT} |
| 🔒 Vulnerabilities | ${VULN_COUNT} |
| 🧹 Code Smells | ${SMELL_COUNT} |
| ⚠️ Security Hotspots | ${HOTSPOT_COUNT} |
| **Total** | **${TOTAL}** |
| 🚨 Blocker | ${BLOCKER_COUNT} |
| ❗ Critical | ${CRIT_COUNT} |

### Branch Plan

| Item | Value |
|------|-------|
| Source PR | #${PR_NUM} |
| Source PR head branch (Copilot baseRef) | \`${PR_HEAD_REF}\` |
| Source PR base branch | \`${PR_BASE_REF}\` |
| Sonar project | \`${SONAR_PROJECT_KEY}\` |
| Sonar PR view | [open](${SONAR_PR_DASHBOARD}) |

> ⚠️ **Important — single-PR-per-branch rule:**
> - Open your fix PR with **base = \`${PR_HEAD_REF}\`** (the source PR's feature branch) — **never** the default branch (\`${DEFAULT_BRANCH}\`).
> - If a Copilot Sonar PR already exists against \`${PR_HEAD_REF}\`, **update it** with new commits — do not open a second one.

${TABLE_CONTENT}

### Task

Fix every finding above on your fix branch and open a single PR into \`${PR_HEAD_REF}\`.
Only change code necessary to clear the listed Sonar issues. Do **not** introduce broad refactors.

### Project Standards (must be respected)

Per \`COPILOT_INSTRUCTIONS.md\` and the \`sonarqube-review\` skill:

- **Cognitive complexity ≤ 15** per method (\`java:S3776\`) — extract helpers if needed.
- **No star imports** — explicit imports only.
- **PMD / Checkstyle compliance** — \`mvn pmd:check\` and \`mvn checkstyle:check\` must pass.
- **Proper logging** — SLF4J only, parameterised messages (\`log.info("x={}", x)\`), no \`System.out\`, no \`printStackTrace\`, correct level.
- **No catching \`Throwable\` / \`NullPointerException\`** — use specific exceptions.
- **Use \`.equals()\`** for String comparison, never \`==\`.
- **Optional over null** for return types where reasonable.
- **Thread safety** — concurrent collections / immutable objects in shared state.
- If a fix changes public behavior, **add or update JUnit 5 + Mockito tests** following the \`java-unit-test-generator\` skill.

### Verification (must pass before pushing)

\`\`\`bash
mvn clean compile -DskipTests
mvn test
\`\`\`

### Constraints

- ✅ Open exactly **one** PR with base = \`${PR_HEAD_REF}\`.
- ❌ Do **not** branch from the default branch (\`${DEFAULT_BRANCH}\`).
- ❌ Do **not** modify unrelated files.
- ❌ Do **not** suppress Sonar issues with \`@SuppressWarnings\` unless absolutely justified — fix the root cause.

### Auto-close

Include in your PR description:

\`\`\`
Closes #<this-issue-number>
\`\`\`

### Agents & Skills
- Skill: \`sonarqube-review\` (skill-quality-0002-sonarqube-review)
- Skill: \`java-unit-test-generator\` (skill-java-spring-0003-java-unit-test-generator)
- Pattern: \`@github-vulnerability-fixer\` (issue → Copilot → fix loop)
- Pattern: \`@junit-writer\` (when fixes need tests)

*Created by [Copilot SonarQube Fix](https://github.com/${REPO}/actions/workflows/workflow-quality-0001-copilot-sonar-fix.yml) on ${TODAY}.*
ISSUE_EOF

if [ "$DRY_RUN" = "true" ]; then
  if [ -n "$EXISTING_ISSUE_NUM" ]; then
    echo "  🏃 DRY RUN — would reopen closed issue #${EXISTING_ISSUE_NUM} with refreshed findings"
  else
    echo "  🏃 DRY RUN — would create new issue: $ISSUE_TITLE"
  fi
  cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🛡️ Copilot SonarQube Fix — PR #${PR_NUM} (DRY RUN)
Findings: **${TOTAL}** (Bugs=${BUG_COUNT} Vulns=${VULN_COUNT} Smells=${SMELL_COUNT} Hotspots=${HOTSPOT_COUNT})
EOF
  rm -f "$ISSUES_FILE" "$HOTSPOTS_FILE" "$TABLE_FILE" "$ISSUE_BODY_FILE"
  exit 0
fi

# Tier 3: reopen previous closed issue
if [ -n "$EXISTING_ISSUE_NUM" ]; then
  echo "🔁 Reopening previous issue #${EXISTING_ISSUE_NUM} with refreshed Sonar findings"
  ISSUE_URL="https://github.com/${REPO}/issues/${EXISTING_ISSUE_NUM}"
  ISSUE_NUM="$EXISTING_ISSUE_NUM"

  gh issue edit "$ISSUE_NUM" --repo "$REPO" \
    --title "$ISSUE_TITLE" \
    --body-file "$ISSUE_BODY_FILE" >/dev/null 2>&1 || echo "  ⚠️  Failed to edit issue #${ISSUE_NUM}"
  gh issue reopen "$ISSUE_NUM" --repo "$REPO" \
    --comment "🔄 Reopened — PR #${PR_NUM} has new commits with Sonar findings on new code. Re-assigning to Copilot agent so it updates the existing fix PR." >/dev/null 2>&1 || true

  echo "  ✅ Issue reopened: $ISSUE_URL"
  if assign_to_copilot_agent "$ISSUE_NUM"; then
    echo "  ⏳ Waiting 2 minutes for Copilot agent to pick up issue #${ISSUE_NUM}..."
    sleep 120
    echo "  🔒 Closing issue #${ISSUE_NUM} after agent pickup..."
    gh issue close "$ISSUE_NUM" --repo "$REPO" \
      --comment "✅ Closed automatically — issue was reassigned to Copilot coding agent." 2>/dev/null || true
  fi
  ISSUES_CREATED=$((ISSUES_CREATED + 1))

# Tier 4: create new issue
elif ISSUE_URL=$(gh issue create \
  --repo "$REPO" \
  --title "$ISSUE_TITLE" \
  --body-file "$ISSUE_BODY_FILE" \
  --label "sonarqube,code-quality,${LABEL}" 2>&1); then
    echo "  ✅ Issue created: $ISSUE_URL"
    ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')

    if assign_to_copilot_agent "$ISSUE_NUM"; then
      echo "  ⏳ Waiting 2 minutes for Copilot agent to pick up issue #${ISSUE_NUM}..."
      sleep 120
      echo "  🔒 Closing issue #${ISSUE_NUM} after agent pickup..."
      gh issue close "$ISSUE_NUM" --repo "$REPO" \
        --comment "✅ Closed automatically — issue was assigned to Copilot coding agent for resolution." 2>/dev/null || true
    else
      echo "  ℹ️  Manually click 'Assign to Agent' on: $ISSUE_URL"
    fi

    # Comment on the source PR linking the issue (only on first create)
    gh pr comment "$PR_NUM" --repo "$REPO" \
      --body "🛡️ Copilot has been asked to fix **${TOTAL}** new-code SonarQube finding(s) on this PR — see ${ISSUE_URL}." 2>/dev/null || true

    ISSUES_CREATED=$((ISSUES_CREATED + 1))
else
  echo "  ❌ Issue creation failed: $ISSUE_URL"
fi

# Step summary
cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🛡️ Copilot SonarQube Fix — PR #${PR_NUM}

| Metric | Value |
|--------|-------|
| Issue | ${ISSUE_URL:-n/a} |
| Source PR head branch (Copilot baseRef) | \`${PR_HEAD_REF}\` |
| 🐛 Bugs | ${BUG_COUNT} |
| 🔒 Vulnerabilities | ${VULN_COUNT} |
| 🧹 Code Smells | ${SMELL_COUNT} |
| ⚠️ Security Hotspots | ${HOTSPOT_COUNT} |
| 🚨 Blocker | ${BLOCKER_COUNT} |
| ❗ Critical | ${CRIT_COUNT} |
| **Total** | **${TOTAL}** |
| Issues created/reopened | ${ISSUES_CREATED} |

The Copilot coding agent will open (or update) a single fix PR with base = \`${PR_HEAD_REF}\`.
Include \`Closes #<issue-number>\` in the fix PR description to auto-close the issue.
EOF

rm -f "$ISSUES_FILE" "$HOTSPOTS_FILE" "$TABLE_FILE" "$ISSUE_BODY_FILE"
