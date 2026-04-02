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
#   --root <dir>         Agent framework root (where mcp-catalog.yaml and .example files live)
#                        Default: auto-detected from script location
#   --output-root <dir>  Where to write mcp.json files (default: same as --root)
#                        Use when the agent framework is a submodule and configs
#                        should be written to the project root instead.
#
# Examples:
#   bash .github/skills/mcp_generate-mcp-configs/scripts/generate-mcp-configs.sh
#   bash generate-mcp-configs.sh --root /path/to/repo
#   bash generate-mcp-configs.sh --root .agent --output-root .

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { echo "[generate-mcp-configs] $*"; }
warn() { echo "[generate-mcp-configs] WARN: $*" >&2; }

# ── Parse flags ───────────────────────────────────────────────────────────────
ROOT_DIR=""
OUTPUT_ROOT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)        ROOT_DIR="$2";        shift 2 ;;
    --output-root) OUTPUT_ROOT_DIR="$2"; shift 2 ;;
    *) warn "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# Auto-detect repo root from script location if not given
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

# Output root defaults to the framework root (standalone mode)
# Override with --output-root when the framework is a submodule
if [[ -z "$OUTPUT_ROOT_DIR" ]]; then
  OUTPUT_ROOT_DIR="$ROOT_DIR"
fi

# ── Host identity resolution ──────────────────────────────────────────────────
# Prefer env var overrides so the script produces correct host paths when run
# inside a devcontainer (where $HOME and id -un reflect the container user).
# Set these in devcontainer.json containerEnv:
#   "HOST_HOME": "${localEnv:HOME}", "HOST_USER": "${localEnv:USER}"
_HOST_UID="${HOST_UID:-$(id -u)}"
_HOST_GID="${HOST_GID:-$(id -g)}"
_HOST_USER="${HOST_USER:-$(id -un)}"
_HOST_HOME="${HOST_HOME:-$HOME}"

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
    -e "s|<HOST_UID>|$_HOST_UID|g" \
    -e "s|<HOST_GID>|$_HOST_GID|g" \
    -e "s|<HOST_USER>|$_HOST_USER|g" \
    -e "s|<HOST_HOME>|$_HOST_HOME|g" \
    -e "s|<WORKSPACE>|$ROOT_DIR|g" \
    -e '/^\s*\/\//d' \
    "$example" > "$output"
  log "Generated  : $output  (from $(basename "$example"))"
}

log "Generating MCP config files from templates..."
log "  Framework root : $ROOT_DIR"
log "  Output root    : $OUTPUT_ROOT_DIR"
generate_config "$ROOT_DIR/.vscode/mcp.example.json" "$OUTPUT_ROOT_DIR/.vscode/mcp.json"
generate_config "$ROOT_DIR/.cline/mcp.example.json"  "$OUTPUT_ROOT_DIR/.cline/mcp.json"
log "Done."
