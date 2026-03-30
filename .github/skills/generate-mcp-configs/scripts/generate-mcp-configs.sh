#!/usr/bin/env bash
# generate-mcp-configs.sh
# Generates .vscode/mcp.json and .cline/mcp.json from their .example templates
# by substituting <HOST_*> placeholders with the current host's actual values.
#
# The .example files are checked into git (no secrets).
# The generated .json files are git-ignored (contain host-specific paths/UIDs).
#
# Placeholder substitution:
#   <HOST_UID>   →  $(id -u)      e.g. 1000
#   <HOST_GID>   →  $(id -g)      e.g. 1000
#   <HOST_USER>  →  $(id -un)     e.g. alice
#   <HOST_HOME>  →  $HOME         e.g. /home/alice
#
# JSON // comments are stripped in the output file.
#
# Usage:
#   bash generate-mcp-configs.sh [--root <dir>]
#
# Flags:
#   --root <dir>   Repo root directory (default: auto-detected from script location)
#
# Examples:
#   bash .github/skills/generate-mcp-configs/scripts/generate-mcp-configs.sh
#   bash generate-mcp-configs.sh --root /path/to/repo

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { echo "[generate-mcp-configs] $*"; }
warn() { echo "[generate-mcp-configs] WARN: $*" >&2; }

# ── Parse flags ───────────────────────────────────────────────────────────────
ROOT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT_DIR="$2"; shift 2 ;;
    *) warn "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# Auto-detect repo root from script location if not given
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

# ── Template substitution ─────────────────────────────────────────────────────
generate_config() {
  local example="$1"
  local output="$2"
  if [[ ! -f "$example" ]]; then
    warn "Template not found: $example — skipping"
    return
  fi
  mkdir -p "$(dirname "$output")"
  sed \
    -e "s|<HOST_UID>|$(id -u)|g" \
    -e "s|<HOST_GID>|$(id -g)|g" \
    -e "s|<HOST_USER>|$(id -un)|g" \
    -e "s|<HOST_HOME>|$HOME|g" \
    -e "s|<WORKSPACE>|$ROOT_DIR|g" \
    -e '/^\s*\/\//d' \
    "$example" > "$output"
  log "Generated  : $output  (from $(basename "$example"))"
}

log "Generating MCP config files from templates..."
generate_config "$ROOT_DIR/.vscode/mcp.example.json" "$ROOT_DIR/.vscode/mcp.json"
generate_config "$ROOT_DIR/.cline/mcp.example.json"  "$ROOT_DIR/.cline/mcp.json"
log "Done."
