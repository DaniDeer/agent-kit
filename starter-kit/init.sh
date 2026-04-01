#!/usr/bin/env bash
# init.sh — Bootstrap the agent framework into a project repo.
#
# Run this from your project root BEFORE opening the project in VS Code.
# After this script finishes, open the project and tell the agent:
#   "Run the agent_setup-in-project skill"
#
# Usage:
#   bash path/to/agent/starter-kit/init.sh [--agent-url <url>]
#
# Options:
#   --agent-url <url>   GitHub URL of the agent framework repo.
#                       Default: auto-detected from this script's own git remote.
#
# Examples:
#   # If you cloned the agent framework already:
#   bash ~/prj/agent/starter-kit/init.sh
#
#   # Explicit agent URL:
#   bash ~/prj/agent/starter-kit/init.sh --agent-url https://github.com/you/agent
#
#   # From a fresh download (curl):
#   curl -fsSL https://raw.githubusercontent.com/you/agent/main/starter-kit/init.sh \
#     | bash -s -- --agent-url https://github.com/you/agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { echo "[agent-init] $*"; }
err()  { echo "[agent-init] ERROR: $*" >&2; exit 1; }

# ── Parse flags ───────────────────────────────────────────────────────────────
AGENT_URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-url) AGENT_URL="$2"; shift 2 ;;
    *) err "Unknown flag: $1" ;;
  esac
done

# ── Auto-detect agent URL from this script's repo remote ─────────────────────
if [[ -z "$AGENT_URL" ]]; then
  AGENT_URL="$(cd "$SCRIPT_DIR" && git remote get-url origin 2>/dev/null || true)"
  if [[ -z "$AGENT_URL" ]]; then
    err "Could not auto-detect agent URL. Pass --agent-url <url> explicitly."
  fi
  log "Auto-detected agent URL: $AGENT_URL"
fi

# ── Verify we're in a git repo ────────────────────────────────────────────────
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  err "Not in a git repository. Run 'git init' first or cd to your project root."
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
log "Project root : $PROJECT_ROOT"
log "Project name : $PROJECT_NAME"

# ── Add agent framework as submodule ─────────────────────────────────────────
if [[ -d "$PROJECT_ROOT/.agent" ]]; then
  log ".agent/ already exists — skipping submodule add"
else
  log "Adding agent framework as submodule at .agent/ ..."
  git -C "$PROJECT_ROOT" submodule add "$AGENT_URL" .agent
  git -C "$PROJECT_ROOT" submodule update --init --recursive
  log "Submodule added."
fi

# ── Copy starter-kit template files ──────────────────────────────────────────
copy_template() {
  local src="$1"
  local dst="$PROJECT_ROOT/$2"
  if [[ -f "$dst" ]]; then
    log "  $2 already exists — skipping"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  sed "s/<project-name>/$PROJECT_NAME/g" "$src" > "$dst"
  log "  Created: $2"
}

log "Copying starter-kit template files..."
copy_template "$SCRIPT_DIR/.clinerules"                      ".clinerules"
copy_template "$SCRIPT_DIR/.github/copilot-instructions.md"  ".github/copilot-instructions.md"

# ── Update .gitignore ─────────────────────────────────────────────────────────
GITIGNORE="$PROJECT_ROOT/.gitignore"
GITIGNORE_FRAGMENT="# Agent framework — generated MCP configs (host-specific, never commit)
.vscode/mcp.json
.cline/mcp.json"

if ! grep -q ".vscode/mcp.json" "$GITIGNORE" 2>/dev/null; then
  echo "" >> "$GITIGNORE"
  echo "$GITIGNORE_FRAGMENT" >> "$GITIGNORE"
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
echo "  Next steps:"
echo "  1. Open this project in VS Code"
echo "  2. Tell the agent: 'Run the agent_setup-in-project skill'"
echo "     The agent will complete the devcontainer setup, generate"
echo "     MCP configs, and commit everything."
echo ""
echo "  Files created:"
echo "    .agent/                  ← agent framework submodule"
echo "    .clinerules              ← thin wrapper (agent reads .agent/.clinerules)"
echo "    .github/copilot-instructions.md"
echo ""
