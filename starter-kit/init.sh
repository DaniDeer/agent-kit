#!/usr/bin/env bash
# init.sh — Bootstrap the agent framework into a project repo.
#
# Run this from your project root BEFORE opening the project in VS Code.
# After this script finishes, open the project and tell the agent:
#   "Run the agent_setup-in-project skill"
#
# ── Usage ─────────────────────────────────────────────────────────────────────
#
# Option A — Devcontainer feature (recommended, fully automatic):
#   Add to devcontainer.json:
#     "features": {
#       "ghcr.io/danideer/agent-kit/agent-kit:1": {}
#     }
#   The feature installs agent-kit-init and runs it at postCreateCommand.
#
# Option B — curl (no clone required):
#   curl -fsSL https://raw.githubusercontent.com/DaniDeer/agent-kit/main/starter-kit/init.sh | bash
#
#   With a forked agent-kit:
#   curl -fsSL https://raw.githubusercontent.com/DaniDeer/agent-kit/main/starter-kit/init.sh \
#     | bash -s -- --agent-url https://github.com/you/your-agent-fork
#
#   In devcontainer.json postCreateCommand:
#   "postCreateCommand": "curl -fsSL https://raw.githubusercontent.com/DaniDeer/agent-kit/main/starter-kit/init.sh | bash"
#
# Option C — local clone:
#   bash ~/prj/agent-kit/starter-kit/init.sh
#
# ── Options ───────────────────────────────────────────────────────────────────
#   --agent-url <url>   GitHub URL of the agent framework repo.
#                       Default: https://github.com/DaniDeer/agent-kit

set -euo pipefail

# ── Default agent framework URL ───────────────────────────────────────────────
DEFAULT_AGENT_URL="https://github.com/DaniDeer/agent-kit"
TEMPLATE_RAW_BASE="https://raw.githubusercontent.com/DaniDeer/agent-kit/main/starter-kit"

log()  { echo "[agent-init] $*"; }
err()  { echo "[agent-init] ERROR: $*" >&2; exit 1; }

# ── Detect execution mode ─────────────────────────────────────────────────────
# When piped via curl, BASH_SOURCE[0] is empty or /dev/stdin
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != "/dev/stdin" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PIPE_MODE=false
else
  SCRIPT_DIR=""
  PIPE_MODE=true
fi

# ── Parse flags ───────────────────────────────────────────────────────────────
AGENT_URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-url) AGENT_URL="$2"; shift 2 ;;
    *) err "Unknown flag: $1" ;;
  esac
done

# ── Resolve agent URL ─────────────────────────────────────────────────────────
if [[ -z "$AGENT_URL" ]]; then
  if [[ "$PIPE_MODE" == false ]] && cd "$SCRIPT_DIR" && git remote get-url origin > /dev/null 2>&1; then
    # Running as a local file: auto-detect from the script's own git remote
    AGENT_URL="$(cd "$SCRIPT_DIR" && git remote get-url origin)"
    log "Auto-detected agent URL: $AGENT_URL"
  else
    # Piped or no remote: use the hardcoded default
    AGENT_URL="$DEFAULT_AGENT_URL"
    log "Using default agent URL: $AGENT_URL"
  fi
fi

# ── Verify we're in a git repo ────────────────────────────────────────────────
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  err "Not in a git repository. Run 'git init' first or cd to your project root."
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
log "Project root : $PROJECT_ROOT"
log "Project name : $PROJECT_NAME"

# ── Git safe directory ────────────────────────────────────────────────────────
# In devcontainers and CI, the workspace is a bind mount owned by the host user.
# Git ≥ 2.35.2 refuses to operate on repos owned by a different user unless
# the directory is explicitly trusted. This prevents the misleading error:
#   "fatal: please make sure that the .gitmodules file is in the working tree"
git config --global --add safe.directory "$PROJECT_ROOT" 2>/dev/null || true

# ── Add agent framework as submodule ─────────────────────────────────────────
# Check for stale submodule registration (e.g. from a previous interrupted run):
# remove any leftover .git/config entry and .git/modules/ so git submodule add
# starts from a clean state.
_submodule_url="$(git -C "$PROJECT_ROOT" config --get submodule..agent.url 2>/dev/null || true)"
if [[ -n "$_submodule_url" ]] && [[ ! -d "$PROJECT_ROOT/.agent/.git" ]]; then
  log "Stale submodule registration detected — cleaning up before re-adding..."
  git -C "$PROJECT_ROOT" config --remove-section submodule..agent 2>/dev/null || true
  rm -rf "$PROJECT_ROOT/.git/modules/.agent" "$PROJECT_ROOT/.agent"
  git -C "$PROJECT_ROOT" rm --cached .agent .gitmodules 2>/dev/null || true
fi

if [[ -d "$PROJECT_ROOT/.agent/.git" ]] || [[ -f "$PROJECT_ROOT/.agent/.git" ]]; then
  log ".agent/ already exists — skipping submodule add"
else
  log "Adding agent framework as submodule at .agent/ ..."
  git -C "$PROJECT_ROOT" submodule add "$AGENT_URL" .agent
  git -C "$PROJECT_ROOT" submodule update --init --recursive
  log "Submodule added."
fi

# ── Copy or download template files ──────────────────────────────────────────
write_template() {
  local dst="$PROJECT_ROOT/$1"
  local src_rel="$2"  # relative path within starter-kit/

  if [[ -f "$dst" ]]; then
    log "  $1 already exists — skipping"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ "$PIPE_MODE" == false ]] && [[ -f "$SCRIPT_DIR/$src_rel" ]]; then
    # Local mode: copy from filesystem and substitute project name
    sed "s/<project-name>/$PROJECT_NAME/g" "$SCRIPT_DIR/$src_rel" > "$dst"
  else
    # Pipe mode: download from GitHub and substitute project name
    curl -fsSL "$TEMPLATE_RAW_BASE/$src_rel" \
      | sed "s/<project-name>/$PROJECT_NAME/g" > "$dst"
  fi

  log "  Created: $1"
}

log "Writing project files..."
write_template ".clinerules"                      ".clinerules"
write_template ".github/copilot-instructions.md"  ".github/copilot-instructions.md"

# ── Update .gitignore ─────────────────────────────────────────────────────────
GITIGNORE="$PROJECT_ROOT/.gitignore"
if ! grep -q ".vscode/mcp.json" "$GITIGNORE" 2>/dev/null; then
  {
    echo ""
    echo "# Agent framework — generated MCP configs (host-specific, never commit)"
    echo ".vscode/mcp.json"
    echo ".cline/mcp.json"
  } >> "$GITIGNORE"
  log "  Updated: .gitignore"
else
  log "  .gitignore already has mcp.json entries — skipping"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Agent framework bootstrapped for: $PROJECT_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Files created:"
echo "    .agent/                  ← agent framework submodule"
echo "    .clinerules              ← Cline reads .agent/.clinerules"
echo "    .github/copilot-instructions.md"
echo "    .gitignore               ← updated (excludes mcp.json)"
echo ""
echo "  Next step:"
echo "    Open in VS Code and tell the agent:"
echo "    \"Run the agent_setup-in-project skill\""
echo ""
