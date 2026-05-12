#!/usr/bin/env bash
# Copilot JUnit Writer — Main Script
#
# Artifact: workflow-java-spring-0001-copilot-junit-writer (companion script)
# Called by workflow-java-spring-0001-copilot-junit-writer.yml
# Detects Java source files in a PR that lack corresponding JUnit test classes,
# creates a GitHub Issue listing the untested files, and assigns it to the
# copilot-swe-agent bot.
#
# Required env vars:
#   REPO             — owner/repo (e.g., AAInternal/my-service)
#   GH_TOKEN         — GITHUB_TOKEN for issue creation and PR API
#   DEPENDABOT_PAT   — PAT for Copilot agent assignment via GraphQL
#   PR_NUM           — Pull request number
#   PR_AUTHOR        — PR author login
#   PR_HEAD_REF      — PR head branch name (for Copilot to target)
#   DRY_RUN          — "true" to skip issue creation
#   GITHUB_STEP_SUMMARY — path to step summary file (set by Actions)

set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"
ISSUES_CREATED=0
TODAY=$(date -u +%Y-%m-%d)

# ── Detect default branch dynamically ──
# Supports repos using either 'main' or 'master' as the default branch.
# Can be overridden via DEFAULT_BRANCH env var if needed.
DEFAULT_BRANCH="${DEFAULT_BRANCH:-$(gh repo view "$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "main")}"

echo "🧪 Checking PR #${PR_NUM} for Java files missing JUnit tests..."
echo "   Default branch: $DEFAULT_BRANCH"
echo "   Dry run: $DRY_RUN"
echo ""

# ── Helper: find an existing test file for a Java source class ──
# Detection order (first match wins):
#   1. Standard mirror:        src/test/java/<pkg>/<Class>Test.java
#   2. Common naming variants: <Class>Tests.java, <Class>IT.java,
#                              <Class>UnitTest.java, <Class>Spec.java
#   3. Import-based fallback:  any *.java file under src/test/java that
#                              has "import <fully.qualified.Class>;"
# Echoes the test file path if found, else empty.
find_existing_test_file() {
  local src_file="$1"
  local class_name pkg_path fqcn test_dir candidate hit

  class_name=$(basename "$src_file" .java)
  # src/main/java/com/aa/.../Foo.java -> com/aa/.../Foo.java -> com/aa/...
  pkg_path=$(echo "$src_file" | sed 's|^src/main/java/||' | sed 's|/[^/]*\.java$||')
  fqcn=$(echo "$pkg_path" | tr '/' '.').${class_name}
  test_dir="src/test/java/${pkg_path}"

  # 1. Standard mirror
  candidate="${test_dir}/${class_name}Test.java"
  if [ -f "$candidate" ]; then echo "$candidate"; return 0; fi

  # 2. Common naming variants in the mirror package
  for suffix in Tests IT UnitTest Spec; do
    candidate="${test_dir}/${class_name}${suffix}.java"
    if [ -f "$candidate" ]; then echo "$candidate"; return 0; fi
  done

  # 3. Import-based fallback — any test file that imports this class.
  #    Limit to src/test/java to avoid matching production code.
  #    To reduce false positives (e.g. a test for ClassB that just uses ClassA as
  #    a dependency), prefer hits whose filename contains the source class name.
  if [ -d "src/test/java" ]; then
    local all_hits best_hit
    all_hits=$(grep -rl --include='*.java' -F "import ${fqcn};" src/test/java 2>/dev/null || true)
    if [ -n "$all_hits" ]; then
      # Prefer a file whose basename contains the source class name (e.g. FooServiceTest for FooService)
      best_hit=$(echo "$all_hits" | while IFS= read -r h; do
        hbase=$(basename "$h" .java)
        case "$hbase" in *"${class_name}"*) echo "$h"; break;; esac
      done)
      if [ -n "$best_hit" ]; then echo "$best_hit"; return 0; fi
      # Fallback: only use the import hit if it's the SOLE importer (avoids misattribution)
      local hit_count
      hit_count=$(echo "$all_hits" | wc -l | tr -d ' ')
      if [ "$hit_count" -eq 1 ]; then
        echo "$all_hits"
        return 0
      fi
      # Multiple importers with no name match — too ambiguous, skip
    fi
  fi

  return 1
}

# ── Helper: list NEW or MODIFIED method signatures in a source file ──
# Compares the file vs the PR base ref and prints one method signature per line
# (best-effort — rely on '+' diff lines that look like Java method declarations).
# Used to give Copilot a precise list of methods needing new tests.
list_changed_methods() {
  local src_file="$1"
  local base_ref="${PR_BASE_REF:-${DEFAULT_BRANCH}}"
  local diff_out

  diff_out=$(git diff "origin/${base_ref}...HEAD" -- "$src_file" 2>/dev/null \
            || git diff "${base_ref}...HEAD" -- "$src_file" 2>/dev/null \
            || true)
  [ -z "$diff_out" ] && return 0

  # Match added lines that look like a method declaration.
  # Covers: public/protected/private/package-private, static, final, synchronized,
  # abstract, default, generic (<T>), and @Override on the same line.
  # Requires: at least one word before '(' that is NOT a control keyword.
  echo "$diff_out" \
    | grep -E '^\+[[:space:]]*(@[A-Za-z]+[[:space:]]+)*(public|protected|private|static|final|synchronized|abstract|default|<[^>]+>|void|int|long|boolean|double|float|char|byte|short|[A-Z][A-Za-z0-9<>,? ]*)[[:space:]].*\(' \
    | grep -vE '^\+\+\+ ' \
    | grep -vE '^\+[[:space:]]*(if|else|for|while|switch|catch|return|throw|new|super|this)\b' \
    | sed -E 's/^\+[[:space:]]*//; s/[[:space:]]*\{?[[:space:]]*$//' \
    | sort -u \
    || true
}

# ── Helper: find an existing issue (any state) for this source PR ──
# Echoes "<number> <state>" if found, else empty.
find_existing_issue() {
  local search_term="$1"
  gh issue list \
    --repo "$REPO" \
    --label "copilot-junit-writer" \
    --search "$search_term in:title" \
    --state all \
    --limit 5 \
    --json number,state,title \
    --jq "[.[] | select(.title | startswith(\"$search_term\"))] | sort_by(.number) | reverse | .[0] | if . then \"\(.number) \(.state)\" else \"\" end" 2>/dev/null || echo ""
}

# ── Helper: find an existing open Copilot PR targeting our source PR branch ──
# Copilot agent opens its PR with base = PR_HEAD_REF (passed via agentAssignment).
# Matches by author login (all known Copilot actor names) OR copilot/* head branch.
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
    --jq "[.[] | select(.author.login == \"copilot-swe-agent\" or .author.login == \"app/copilot-swe-agent\" or .author.login == \"Copilot\" or (.headRefName | test(\"copilot/\"; \"i\")))] | sort_by(.number) | reverse | .[0].number // empty" 2>/dev/null || echo ""
}

# ── Helper: assign issue to Copilot coding agent ──
assign_to_copilot_agent() {
  local issue_num="$1"

  if [ -z "${DEPENDABOT_PAT:-}" ]; then
    echo "  ⚠️  DEPENDABOT_PAT not set — cannot assign to Copilot agent"
    echo "  ℹ️  Ensure the DEPENDABOT_PAT secret is configured with issues:write permission"
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
  bot_id=$(echo "$gql_result" | jq -r '[.data.repository.suggestedActors.nodes[] | select(.login == "copilot-swe-agent")] | first | .id // empty' 2>/dev/null)
  repo_gql_id=$(echo "$gql_result" | jq -r '.data.repository.id // empty' 2>/dev/null)

  if [ -z "$bot_id" ]; then
    echo "  ⚠️  copilot-swe-agent not found in suggestedActors"
    echo "  ℹ️  Available: $(echo "$gql_result" | jq -r '[.data.repository.suggestedActors.nodes[].login] | join(", ")' 2>/dev/null)"
    return 1
  fi
  echo "  ✅ Found copilot-swe-agent bot (GraphQL ID retrieved)"

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
            baseRef: \"${PR_HEAD_REF:-${DEFAULT_BRANCH}}\",
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

# ── Step 1: Get the list of changed Java source files in the PR ──
echo "📂 Fetching changed files from PR #${PR_NUM}..."

CHANGED_FILES=$(gh pr diff "$PR_NUM" --repo "$REPO" --name-only 2>/dev/null || echo "")

if [ -z "$CHANGED_FILES" ]; then
  echo "  ℹ️  No changed files found in PR — exiting"
  echo "### 🧪 JUnit Writer" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
  echo "No changed files detected in PR #${PR_NUM}." >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
  exit 0
fi

# Filter to Java source files under src/main/java (exclude tests, configs, enums, POJOs, deleted files)
JAVA_SOURCE_FILES=""
while IFS= read -r file; do
  # Only process Java files under src/main/java
  if [[ "$file" == src/main/java/*.java ]]; then
    # Skip package-info, module-info
    basename_file=$(basename "$file")
    if [[ "$basename_file" == "package-info.java" ]] || [[ "$basename_file" == "module-info.java" ]]; then
      continue
    fi
    # Skip deleted files — gh pr diff --name-only includes deletions;
    # we can't generate tests for files that no longer exist.
    if [ ! -f "$file" ]; then
      echo "  ⏭️  Skipping $file — deleted in this PR"
      continue
    fi
    JAVA_SOURCE_FILES="${JAVA_SOURCE_FILES}${file}"$'\n'
  fi
done <<< "$CHANGED_FILES"

JAVA_SOURCE_FILES=$(echo "$JAVA_SOURCE_FILES" | sed '/^$/d')

if [ -z "$JAVA_SOURCE_FILES" ]; then
  echo "  ℹ️  No Java source files changed in PR — exiting"
  echo "### 🧪 JUnit Writer" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
  echo "No Java source files changed in PR #${PR_NUM}." >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
  exit 0
fi

TOTAL_SOURCE=$(echo "$JAVA_SOURCE_FILES" | wc -l | tr -d ' ')
echo "  📊 Found $TOTAL_SOURCE Java source file(s) in PR"

# ── Step 2: Check which files lack corresponding test classes ──
echo "🔍 Checking for missing test classes..."

MISSING_TESTS=""          # No test file anywhere — agent must CREATE a new test class
MISSING_COUNT=0
AUGMENT_TESTS=""          # Existing test file found — agent must ADD tests for new methods only
AUGMENT_COUNT=0
# Per-source extra context: "<src>|<existing_test_or_-> |<comma-sep-changed-methods>"
SOURCE_DETAILS_FILE=$(mktemp)

while IFS= read -r src_file; do
  # Default expected test path (for the "create" case)
  default_test_file=$(echo "$src_file" | sed 's|src/main/java|src/test/java|' | sed 's|\.java$|Test.java|')

  # 1. Try to locate an existing test file under any of the supported names/locations
  existing_test=$(find_existing_test_file "$src_file" || true)

  # 2. Compute new/modified method signatures from the PR diff (best-effort)
    changed_methods=$(list_changed_methods "$src_file" | tr '\n' '|' | sed 's/|$//' || true)

  if [ -n "$existing_test" ]; then
    echo "  ✏️  $src_file → augment existing: $existing_test"
    AUGMENT_TESTS="${AUGMENT_TESTS}${src_file}|${existing_test}"$'\n'
    AUGMENT_COUNT=$((AUGMENT_COUNT + 1))
    echo "${src_file}|${existing_test}|${changed_methods}" >> "$SOURCE_DETAILS_FILE"
  elif echo "$CHANGED_FILES" | grep -qF "$default_test_file"; then
    # Test added in the same PR — nothing to do
    echo "  ✅ $src_file → test in same PR: $default_test_file"
  else
    echo "  ❌ $src_file → MISSING: $default_test_file"
    MISSING_TESTS="${MISSING_TESTS}${src_file}"$'\n'
    MISSING_COUNT=$((MISSING_COUNT + 1))
    echo "${src_file}|-|${changed_methods}" >> "$SOURCE_DETAILS_FILE"
  fi
done <<< "$JAVA_SOURCE_FILES"

MISSING_TESTS=$(echo "$MISSING_TESTS" | sed '/^$/d')
AUGMENT_TESTS=$(echo "$AUGMENT_TESTS" | sed '/^$/d')
TOTAL_NEEDS_WORK=$((MISSING_COUNT + AUGMENT_COUNT))

echo ""
echo "📊 Summary: $MISSING_COUNT missing test class(es), $AUGMENT_COUNT existing test(s) need new methods (of $TOTAL_SOURCE source file(s))"

# ── Step 3: If nothing needs work, exit cleanly ──
if [ "$TOTAL_NEEDS_WORK" -eq 0 ]; then
  echo "✅ All Java source files have full test coverage for the changes — no action needed"
  rm -f "$SOURCE_DETAILS_FILE"

  cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🧪 JUnit Writer — PR #${PR_NUM}
✅ All **${TOTAL_SOURCE}** Java source files have corresponding JUnit test coverage.
EOF
  exit 0
fi

# ── Step 4: Build file tables for the issue body ──
echo "📝 Building issue for ${TOTAL_NEEDS_WORK} file(s) needing test work..."

# Table for files that need a brand-new test class (no existing test file detected)
CREATE_TABLE=""
if [ "$MISSING_COUNT" -gt 0 ]; then
  CREATE_TABLE="| # | Source File | Expected Test File | Changed Methods |
|---|------------|-------------------|-----------------|"
  i=0
  while IFS= read -r src_file; do
    [ -z "$src_file" ] && continue
    i=$((i + 1))
    test_file=$(echo "$src_file" | sed 's|src/main/java|src/test/java|' | sed 's|\.java$|Test.java|')
    methods=$(grep -F "${src_file}|-|" "$SOURCE_DETAILS_FILE" | head -n1 | cut -d'|' -f3-)
    if [ -z "$methods" ]; then
      methods_cell="_(see PR diff)_"
    else
      methods_cell=$(echo "$methods" | tr '|' '\n' | sed 's/^/`/;s/$/`/' | paste -sd '<br>' -)
    fi
    CREATE_TABLE="${CREATE_TABLE}
| ${i} | \`${src_file}\` | \`${test_file}\` | ${methods_cell} |"
  done <<< "$MISSING_TESTS"
fi

# Table for files where an existing test file should be EXTENDED with new tests only
AUGMENT_TABLE=""
if [ "$AUGMENT_COUNT" -gt 0 ]; then
  AUGMENT_TABLE="| # | Source File | Existing Test File | New / Modified Methods |
|---|------------|--------------------|------------------------|"
  i=0
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    i=$((i + 1))
    src_file=$(echo "$entry" | cut -d'|' -f1)
    existing_test=$(echo "$entry" | cut -d'|' -f2)
    methods=$(grep -F "${src_file}|${existing_test}|" "$SOURCE_DETAILS_FILE" | head -n1 | cut -d'|' -f3-)
    if [ -z "$methods" ]; then
      methods_cell="_(see PR diff)_"
    else
      # Render each signature in its own backtick-quoted line within the cell
      methods_cell=$(echo "$methods" | tr '|' '\n' | sed 's/^/`/;s/$/`/' | paste -sd '<br>' -)
    fi
    AUGMENT_TABLE="${AUGMENT_TABLE}
| ${i} | \`${src_file}\` | \`${existing_test}\` | ${methods_cell} |"
  done <<< "$AUGMENT_TESTS"
fi

# Combined plain-text bullet list (used in summaries/comments)
FILE_LIST=""
while IFS= read -r src_file; do
  [ -z "$src_file" ] && continue
  test_file=$(echo "$src_file" | sed 's|src/main/java|src/test/java|' | sed 's|\.java$|Test.java|')
  FILE_LIST="${FILE_LIST}
- 🆕 \`${src_file}\` → create \`${test_file}\`"
done <<< "$MISSING_TESTS"
while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  src_file=$(echo "$entry" | cut -d'|' -f1)
  existing_test=$(echo "$entry" | cut -d'|' -f2)
  FILE_LIST="${FILE_LIST}
- ✏️ \`${src_file}\` → augment \`${existing_test}\`"
done <<< "$AUGMENT_TESTS"

# ── Step 5: Reuse an existing Copilot PR or issue if one exists for this PR ──
SEARCH_KEY="test: generate JUnit tests for PR #${PR_NUM}"

# 5a. If a Copilot PR is already open against our source branch, just comment on it.
EXISTING_COPILOT_PR=$(find_existing_copilot_pr "${PR_HEAD_REF:-}")

if [ -n "$EXISTING_COPILOT_PR" ]; then
  echo "  🔁 Found existing Copilot PR #${EXISTING_COPILOT_PR} targeting '${PR_HEAD_REF}' — updating instead of creating new"

  if [ "$DRY_RUN" = "true" ]; then
    echo "  🏃 DRY RUN — would comment on PR #${EXISTING_COPILOT_PR} with ${TOTAL_NEEDS_WORK} updated file(s)"
    cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🧪 JUnit Writer — PR #${PR_NUM} (DRY RUN)
Would update existing Copilot PR [#${EXISTING_COPILOT_PR}](https://github.com/${REPO}/pull/${EXISTING_COPILOT_PR}) with **${TOTAL_NEEDS_WORK}** file(s).
${FILE_LIST}
EOF
    rm -f "$SOURCE_DETAILS_FILE"
    exit 0
  fi

  COMMENT_BODY_FILE=$(mktemp)
  cat > "$COMMENT_BODY_FILE" <<COMMENT_EOF
🔄 **Updated test requirements from PR #${PR_NUM} (commit on ${TODAY})**

The source PR has new or modified Java files. Please update **this PR** (do not open a new one) so it covers the latest list below.

COMMENT_EOF

  if [ "$AUGMENT_COUNT" -gt 0 ]; then
    cat >> "$COMMENT_BODY_FILE" <<COMMENT_EOF

### ✏️ Augment Existing Test Files (${AUGMENT_COUNT})

For each row, **add @Test methods only for the listed New / Modified Methods** to the existing test file. Preserve every existing test and reuse existing fields, mocks, and \`@BeforeEach\` setup. Do **NOT** create a parallel \`*Test.java\` file.

${AUGMENT_TABLE}
COMMENT_EOF
  fi

  if [ "$MISSING_COUNT" -gt 0 ]; then
    cat >> "$COMMENT_BODY_FILE" <<COMMENT_EOF

### 🆕 Create New Test Classes (${MISSING_COUNT})

${CREATE_TABLE}
COMMENT_EOF
  fi

  cat >> "$COMMENT_BODY_FILE" <<COMMENT_EOF

Continue to follow all standards from \`COPILOT_INSTRUCTIONS.md\` and the \`java-unit-test-generator\` skill. Ensure \`mvn clean compile -DskipTests\` and \`mvn test\` still pass.

*Auto-updated by [Copilot JUnit Writer](https://github.com/${REPO}/actions/workflows/workflow-java-spring-0001-copilot-junit-writer.yml)*
COMMENT_EOF

  if gh pr comment "$EXISTING_COPILOT_PR" --repo "$REPO" --body-file "$COMMENT_BODY_FILE" >/dev/null 2>&1; then
    echo "  ✅ Posted update comment on Copilot PR #${EXISTING_COPILOT_PR}"
  else
    echo "  ⚠️  Failed to comment on Copilot PR #${EXISTING_COPILOT_PR}"
  fi
  rm -f "$COMMENT_BODY_FILE"

  cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🧪 JUnit Writer — PR #${PR_NUM}
🔁 Reused existing Copilot PR [#${EXISTING_COPILOT_PR}](https://github.com/${REPO}/pull/${EXISTING_COPILOT_PR}) — posted update comment.
- 🆕 New test classes to create: **${MISSING_COUNT}**
- ✏️ Existing test files to augment: **${AUGMENT_COUNT}**
${FILE_LIST}
EOF
  rm -f "$SOURCE_DETAILS_FILE"
  exit 0
fi

# 5b. No Copilot PR yet — check for an existing issue (any state) for this source PR.
EXISTING_ISSUE_INFO=$(find_existing_issue "$SEARCH_KEY")
EXISTING_ISSUE_NUM=""
EXISTING_ISSUE_STATE=""
if [ -n "$EXISTING_ISSUE_INFO" ]; then
  EXISTING_ISSUE_NUM=$(echo "$EXISTING_ISSUE_INFO" | awk '{print $1}')
  EXISTING_ISSUE_STATE=$(echo "$EXISTING_ISSUE_INFO" | awk '{print $2}')
fi

if [ -n "$EXISTING_ISSUE_NUM" ] && [ "$EXISTING_ISSUE_STATE" = "OPEN" ]; then
  echo "  ⏭️  Open issue #${EXISTING_ISSUE_NUM} already exists for PR #${PR_NUM} — skipping (Copilot agent still working)"

  cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🧪 JUnit Writer — PR #${PR_NUM}
⏭️ Open issue [#${EXISTING_ISSUE_NUM}](https://github.com/${REPO}/issues/${EXISTING_ISSUE_NUM}) already exists. Skipping.
- New test classes to create: **${MISSING_COUNT}**
- Existing test files to augment: **${AUGMENT_COUNT}**
EOF
  rm -f "$SOURCE_DETAILS_FILE"
  exit 0
fi

# ── Step 6: Either reopen the previous closed issue or create a new one ──
if [ "$DRY_RUN" = "true" ]; then
  if [ -n "$EXISTING_ISSUE_NUM" ]; then
    echo "  🏃 DRY RUN — would reopen closed issue #${EXISTING_ISSUE_NUM} (create=${MISSING_COUNT}, augment=${AUGMENT_COUNT})"
  else
    echo "  🏃 DRY RUN — would create new issue: ${SEARCH_KEY} [$TODAY] (create=${MISSING_COUNT}, augment=${AUGMENT_COUNT})"
  fi
  cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🧪 JUnit Writer — PR #${PR_NUM} (DRY RUN)
Would request work on **${TOTAL_NEEDS_WORK}** file(s) — create ${MISSING_COUNT}, augment ${AUGMENT_COUNT}.
${FILE_LIST}
EOF
  rm -f "$SOURCE_DETAILS_FILE"
  exit 0
fi

ISSUE_TITLE="${SEARCH_KEY} [$TODAY]"

ISSUE_BODY_FILE=$(mktemp)
cat > "$ISSUE_BODY_FILE" <<ISSUE_EOF
## 🧪 Generate JUnit Tests — PR #${PR_NUM}

PR [#${PR_NUM}](https://github.com/${REPO}/pull/${PR_NUM}) by @${PR_AUTHOR} introduces or modifies **${TOTAL_NEEDS_WORK}** Java source file(s) needing test work:
- 🆕 **${MISSING_COUNT}** file(s) need a brand-new test class
- ✏️ **${AUGMENT_COUNT}** file(s) have an existing test file that needs to be **extended** with tests for the new/modified methods only

ISSUE_EOF

if [ "$AUGMENT_COUNT" -gt 0 ]; then
  cat >> "$ISSUE_BODY_FILE" <<ISSUE_EOF

### ✏️ Augment Existing Test Files (${AUGMENT_COUNT})

> **DELTA MODE — ADD ONLY, DO NOT REPLACE.** For every row below, open the existing test file and append \`@Test\` methods **only** for the listed New / Modified Methods. Preserve every existing test, field, mock, and \`@BeforeEach\`. Do **NOT** create a parallel \`<Class>Test.java\` file — the existing file is the canonical test class even if its name does not match the standard mirror convention.

${AUGMENT_TABLE}

For each row:
1. Run \`git diff origin/${PR_BASE_REF:-${DEFAULT_BRANCH}}...HEAD -- <source-file>\` to confirm the New / Modified Methods listed.
2. **Check if existing tests are broken by the changes** — if a method's signature, return type, or behavior changed, update the impacted existing tests in place (fix assertions, adjust mocks). Do NOT delete any existing test.
3. **Handle "_(see PR diff)_" entries (Internal Behavior Changes)** — if the New / Modified Methods column says \`_(see PR diff)_\`, no new method signatures were detected but the file body DID change. Run \`git diff\` and look for changes inside method bodies: modified error messages, new conditions/branches, changed constants/thresholds. Then:
   - Update every existing test that asserts on old values (old message strings, old expected results)
   - Add new \`@Test\` methods if a new code branch was introduced
   - Follow the **Step D3-B: Internal Behavior Changes** procedure from the \`java-unit-test-generator\` skill
4. Reuse the existing test file's mocks, builders, and \`@BeforeEach\` setup — do not re-declare them.
5. Add one or more \`@Test\` methods covering happy path / edge cases / exceptions for each new/modified method that has no existing test.
6. Group new tests near related existing tests when reasonable.
ISSUE_EOF
fi

if [ "$MISSING_COUNT" -gt 0 ]; then
  cat >> "$ISSUE_BODY_FILE" <<ISSUE_EOF

### 🆕 Create New Test Classes (${MISSING_COUNT})

> These files have **no detectable existing test file** (checked: standard mirror, common name variants \`Tests/IT/UnitTest/Spec\`, and import-based grep across \`src/test/java\`). Create a new test class at the Expected Test File path, but **only cover the Changed Methods listed** — do NOT generate tests for every method in the class. If the class is brand-new (all methods are new), test all of them.

${CREATE_TABLE}

For each row:
1. Run \`git diff origin/${PR_BASE_REF:-${DEFAULT_BRANCH}}...HEAD -- <source-file>\` to confirm which methods were actually added/modified.
2. Create the test class with necessary setup (mocks, \`@BeforeEach\`), but write \`@Test\` methods **only for the changed methods**.
3. If the entire file is new (100% added lines), then all methods are "changed" — test them all.
ISSUE_EOF
fi

cat >> "$ISSUE_BODY_FILE" <<ISSUE_EOF

### Task

Follow ALL project standards from \`COPILOT_INSTRUCTIONS.md\` and the \`java-unit-test-generator\` skill:

> **Scope rule:** Only generate tests for the methods that were **changed or added in the PR** — not every method in the class. Use \`git diff\` to confirm scope. The only exception is when the entire file is brand-new (100% added lines) — then all methods are "changed" and should be tested.

> **Internal behavior changes:** If the Changed Methods column says \`_(see PR diff)_\`, no new method signatures were detected but the file body changed (modified messages, new conditions, changed constants). You MUST still process the file — run \`git diff\`, update existing tests that assert on old values, and add new tests if new branches were introduced. Follow **Step D3-B** from the \`java-unit-test-generator\` skill.

1. **Read each source file** and run \`git diff origin/${PR_BASE_REF:-${DEFAULT_BRANCH}}...HEAD -- <source-file>\` to identify the changed methods
2. For **🆕 Create**: generate a new test class at the Expected Test File path with \`@Test\` methods **only for the Changed Methods** listed in the table
3. For **✏️ Augment**: add \`@Test\` methods only for the listed New / Modified Methods to the existing test file — do NOT create a duplicate \`*Test.java\`
4. **Follow test standards**:
   - \`@ExtendWith(MockitoExtension.class)\`
   - \`should[Expected]_when[Condition]()\` naming
   - AAR pattern (\`// Arrange\`, \`// Act\`, \`// Assert\`)
   - Deep assertions (validate content, not just existence)
   - Use project builders (test data builders from \`src/test/java\`)
   - Mock only external dependencies — use real domain objects
   - Import statements only — no fully qualified class names
5. **Cover scenarios for each changed method**: happy path, edge cases, exceptions, boundary conditions
6. **Verify**: \`mvn clean compile -DskipTests\` and \`mvn test\` must pass

### File Details
${FILE_LIST}

### Verification Checklist

- [ ] **Only changed methods are tested** — do NOT test methods that were not added/modified in the PR
- [ ] **Internal behavior changes handled** — files with \`_(see PR diff)_\` were NOT skipped; existing tests updated for changed messages/constants/conditions, new tests added for new branches
- [ ] **No duplicate test files were created** — every source file with an existing test (any naming) was augmented in place
- [ ] **Impacted existing tests were updated** — if the PR changes broke existing tests (new signatures, changed behavior), those tests were fixed in place, not deleted
- [ ] **No existing tests were deleted** — impacted tests are updated, unimpacted tests are untouched
- [ ] Every Changed Method listed has at least one new \`@Test\`
- [ ] Test class in correct mirror package under \`src/test/java/\` (for newly created classes)
- [ ] \`@ExtendWith(MockitoExtension.class)\` annotation
- [ ] \`should*_when*\` test method naming
- [ ] AAR pattern with comments
- [ ] Deep assertions validate content
- [ ] Project builders used for domain objects
- [ ] Only external dependencies mocked
- [ ] Happy paths, edge cases, and exceptions covered
- [ ] \`mvn clean compile -DskipTests\` passes
- [ ] \`mvn test\` passes

### Agents & Skills
- **\`@junit-writer\`** agent — test generation specialist (delta-mode aware)
- **\`java-unit-test-generator\`** skill — test patterns, assertions, builders, **Delta Mode**

#### Auto-close
When creating the PR, include \`Closes #<this-issue-number>\` in the PR description.

### References
- [PR #${PR_NUM}](https://github.com/${REPO}/pull/${PR_NUM})
- [COPILOT_INSTRUCTIONS.md](https://github.com/${REPO}/blob/${DEFAULT_BRANCH}/.github/copilot-instructions.md)

*Created by [Copilot JUnit Writer](https://github.com/${REPO}/actions/workflows/workflow-java-spring-0001-copilot-junit-writer.yml) on ${TODAY}*
ISSUE_EOF

echo "  📝 Issue body written to temp file ($(wc -c < "$ISSUE_BODY_FILE") bytes)"

# If a previous issue exists (closed), reopen + update it instead of creating a new one.
if [ -n "$EXISTING_ISSUE_NUM" ]; then
  echo "  🔁 Reopening previous issue #${EXISTING_ISSUE_NUM} with refreshed file list"
  ISSUE_URL="https://github.com/${REPO}/issues/${EXISTING_ISSUE_NUM}"
  ISSUE_NUM="$EXISTING_ISSUE_NUM"

  # Update title (refresh the date), body, and reopen.
  gh issue edit "$ISSUE_NUM" --repo "$REPO" \
    --title "$ISSUE_TITLE" \
    --body-file "$ISSUE_BODY_FILE" >/dev/null 2>&1 || echo "  ⚠️  Failed to edit issue #${ISSUE_NUM}"
  gh issue reopen "$ISSUE_NUM" --repo "$REPO" \
    --comment "🔄 Reopened — PR #${PR_NUM} has new commits with files still missing tests. Re-assigning to Copilot agent so it updates the existing PR." >/dev/null 2>&1 || true

  echo "  ✅ Issue reopened: $ISSUE_URL"
  if assign_to_copilot_agent "$ISSUE_NUM"; then
    echo "  ⏳ Waiting 2 minutes for Copilot agent to pick up issue #${ISSUE_NUM}..."
    sleep 120
    echo "  🔒 Closing issue #${ISSUE_NUM} after agent pickup..."
    gh issue close "$ISSUE_NUM" --repo "$REPO" \
      --comment "✅ Closed automatically — issue was reassigned to Copilot coding agent." 2>/dev/null || true
  fi
  ISSUES_CREATED=$((ISSUES_CREATED + 1))
elif ISSUE_URL=$(gh issue create \
  --repo "$REPO" \
  --title "$ISSUE_TITLE" \
  --body-file "$ISSUE_BODY_FILE" \
  --label "testing,copilot-junit-writer" 2>&1); then
    echo "  ✅ Issue created: $ISSUE_URL"
    ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')

    if assign_to_copilot_agent "$ISSUE_NUM"; then
      # Wait for Copilot agent to pick up the issue, then close it
      echo "  ⏳ Waiting 2 minutes for Copilot agent to pick up issue #${ISSUE_NUM}..."
      sleep 120
      echo "  🔒 Closing issue #${ISSUE_NUM} after agent pickup..."
      gh issue close "$ISSUE_NUM" --repo "$REPO" \
        --comment "✅ Closed automatically — issue was assigned to Copilot coding agent for resolution." 2>/dev/null || true
    else
      echo "  ℹ️  Manually click 'Assign to Agent' on: $ISSUE_URL"
    fi

    ISSUES_CREATED=$((ISSUES_CREATED + 1))
else
  echo "  ❌ Issue creation failed: $ISSUE_URL"
fi

rm -f "$ISSUE_BODY_FILE"
rm -f "$SOURCE_DETAILS_FILE"

# ── Summary ──
echo ""
echo "════════════════════════════════════════════"
echo "📊 JUnit Writer Summary"
echo "   Source files in PR:         $TOTAL_SOURCE"
echo "   New test classes to create: $MISSING_COUNT"
echo "   Existing tests to augment:  $AUGMENT_COUNT"
echo "   Issues created:             $ISSUES_CREATED"
echo "════════════════════════════════════════════"

cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}" <<EOF
### 🧪 JUnit Writer — PR #${PR_NUM}

| Metric | Count |
|--------|-------|
| Java source files in PR | ${TOTAL_SOURCE} |
| 🆕 New test classes to create | ${MISSING_COUNT} |
| ✏️ Existing tests to augment | ${AUGMENT_COUNT} |
| Issues created | ${ISSUES_CREATED} |

**Files needing test work:**
${FILE_LIST}
EOF
