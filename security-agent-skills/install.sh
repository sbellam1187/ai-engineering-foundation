#!/usr/bin/env bash
# =============================================================================
# install.sh — GitHub Copilot Skills Installer
# Installs skills from this repo into ~/.copilot/skills/
#
# USAGE:
#   ./install.sh                              # Interactive: choose which skills
#   ./install.sh --all                        # Install all skills, no prompts
#   ./install.sh security-codeql-fix          # Install specific skill by name
#   ./install.sh security-vulnerability-fix   # Install specific skill by name
#   git clone --depth 1 <repo-url> /tmp/aa-security-agent-skills \
#     && /tmp/aa-security-agent-skills/install.sh security-codeql-fix \
#     && rm -rf /tmp/aa-security-agent-skills
#
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/skills" 2>/dev/null && pwd || echo "")"
DEST_DIR="${HOME}/.copilot/skills"
TEMP_DIR=""

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}ℹ${RESET}  $*"; }
success() { echo -e "${GREEN}✅${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠️ ${RESET} $*"; }
error()   { echo -e "${RED}❌${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}$*${RESET}"; }

# ---------------------------------------------------------------------------
# Cleanup temp dir on exit
# ---------------------------------------------------------------------------
cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Detect if running interactively
# ---------------------------------------------------------------------------
is_interactive() {
  [[ -t 0 && -t 1 ]]
}

# ---------------------------------------------------------------------------
# If script was piped (curl | bash), re-download and run from a temp dir
# ---------------------------------------------------------------------------
if [[ -z "$SKILLS_DIR" || ! -d "$SKILLS_DIR" ]]; then
  info "Running in remote mode — downloading repo..."
  TEMP_DIR=$(mktemp -d)
  if command -v git &>/dev/null; then
    git clone --quiet --depth=1 "https://github.com/AAInternal/aa-security-agent-skills.git" "$TEMP_DIR/repo"
  else
    error "git is required to install remotely. Please install git and try again."
    exit 1
  fi
  SKILLS_DIR="$TEMP_DIR/repo/skills"
fi

# ---------------------------------------------------------------------------
# Discover available skills
# ---------------------------------------------------------------------------
ALL_SKILLS=()
while IFS= read -r skill; do
  ALL_SKILLS+=("$skill")
done < <(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '.DS_Store' -exec basename {} \; | sort)

if [[ ${#ALL_SKILLS[@]} -eq 0 ]]; then
  error "No skills found in $SKILLS_DIR"
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
INSTALL_ALL=false
SELECTED_SKILLS=()

for arg in "$@"; do
  case "$arg" in
    --all) INSTALL_ALL=true ;;
    --help|-h)
      echo "Usage: $0 [--all] [skill-name ...]"
      echo ""
      echo "  --all          Install all available skills without prompting"
      echo "  skill-name     One or more skill names to install"
      echo ""
      echo "Available skills:"
      for s in "${ALL_SKILLS[@]}"; do echo "  - $s"; done
      exit 0
      ;;
    --*)
      skill_name="${arg#--}"
      found=false
      for s in "${ALL_SKILLS[@]}"; do
        [[ "$s" == "$skill_name" ]] && found=true && break
      done
      if $found; then
        SELECTED_SKILLS+=("$skill_name")
      else
        error "Unknown option: $arg"
        exit 1
      fi
      ;;
    -*)
      error "Unknown option: $arg"
      exit 1
      ;;
    *)
      found=false
      for s in "${ALL_SKILLS[@]}"; do
        [[ "$s" == "$arg" ]] && found=true && break
      done
      if $found; then
        SELECTED_SKILLS+=("$arg")
      else
        error "Unknown skill: '$arg'. Available: ${ALL_SKILLS[*]}"
        exit 1
      fi
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Skill selection
# ---------------------------------------------------------------------------
if [[ ${#SELECTED_SKILLS[@]} -gt 0 ]]; then
  : # Skills specified via args

elif $INSTALL_ALL || ! is_interactive; then
  SELECTED_SKILLS=("${ALL_SKILLS[@]}")

else
  header "🛠  GitHub Copilot Security Skills Installer"
  echo ""
  echo "Select skills to install (toggle with number, press ENTER when done):"
  echo "──────────────────────────────────────────────────────────────────────"

  declare -A SKILL_SELECTED
  for s in "${ALL_SKILLS[@]}"; do
    SKILL_SELECTED["$s"]=true
  done

  while true; do
    echo ""
    i=1
    for s in "${ALL_SKILLS[@]}"; do
      if ${SKILL_SELECTED[$s]}; then
        echo -e "  ${GREEN}[✓]${RESET} $i) $s"
      else
        echo -e "  [ ] $i) $s"
      fi
      ((i++))
    done
    echo ""
    echo -e "  ${BOLD}a)${RESET} Toggle all  |  ${BOLD}ENTER)${RESET} Install selected  |  ${BOLD}q)${RESET} Quit"
    echo ""
    read -rp "Choice: " choice

    case "$choice" in
      q|Q) echo "Aborted."; exit 0 ;;
      "")  break ;;
      a|A)
        all_on=true
        for s in "${ALL_SKILLS[@]}"; do
          ${SKILL_SELECTED[$s]} || { all_on=false; break; }
        done
        for s in "${ALL_SKILLS[@]}"; do
          $all_on && SKILL_SELECTED[$s]=false || SKILL_SELECTED[$s]=true
        done
        ;;
      [0-9]*)
        idx=$((choice - 1))
        if [[ $idx -ge 0 && $idx -lt ${#ALL_SKILLS[@]} ]]; then
          s="${ALL_SKILLS[$idx]}"
          ${SKILL_SELECTED[$s]} && SKILL_SELECTED[$s]=false || SKILL_SELECTED[$s]=true
        else
          warn "Invalid number. Enter 1–${#ALL_SKILLS[@]}."
        fi
        ;;
      *) warn "Invalid input." ;;
    esac
  done

  for s in "${ALL_SKILLS[@]}"; do
    ${SKILL_SELECTED[$s]} && SELECTED_SKILLS+=("$s")
  done
fi

if [[ ${#SELECTED_SKILLS[@]} -eq 0 ]]; then
  warn "No skills selected. Nothing to install."
  exit 0
fi

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
header "📦 Installing ${#SELECTED_SKILLS[@]} skill(s) to ${DEST_DIR}/"
echo ""
mkdir -p "$DEST_DIR"

installed=()
for skill in "${SELECTED_SKILLS[@]}"; do
  src="$SKILLS_DIR/$skill"
  dst="$DEST_DIR/$skill"

  if [[ -d "$dst" ]]; then
    info "Updating:   $skill"
  else
    info "Installing: $skill"
  fi

  cp -r "$src" "$DEST_DIR/"
  find "$dst" -name "*.sh" -exec chmod +x {} \;
  installed+=("$skill")
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "────────────────────────────────────────────────────────────────────────"
success "Installed ${#installed[@]} skill(s):"
for s in "${installed[@]}"; do
  echo -e "   ${GREEN}•${RESET} $s  →  ${DEST_DIR}/$s"
done

echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo -e "${BOLD}Next steps:${RESET}"
echo "  1. Restart VS Code so GitHub Copilot picks up the new skills"
echo "  2. Skills are automatically installed in Copilot cloud agent"
echo "     via the copilot-setup-steps.yml workflow"
echo ""
success "Done! 🎉"
