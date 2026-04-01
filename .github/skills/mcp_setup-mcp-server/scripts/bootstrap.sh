#!/usr/bin/env bash
# bootstrap.sh
# Reads mcp-catalog.yaml and runs setup-mcp-server.sh for every server entry.
# Use this on a fresh clone to rebuild all Docker images without needing to
# remember individual GitHub URLs.
#
# Patched Dockerfiles are already committed to .mcp-dockerfiles/ — build-mcp-server.sh
# picks them up automatically so no patching step is needed during bootstrap.
#
# Usage:
#   bash bootstrap.sh [--force] [--dry-run]
#
# Flags:
#   --force    Re-clone and rebuild even if images already exist
#   --dry-run  Clone only — skip docker build (forwarded to setup-mcp-server.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup-mcp-server.sh"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CATALOG="$ROOT_DIR/mcp-catalog.yaml"

log()  { echo "[bootstrap] $*"; }
warn() { echo "[bootstrap] WARN: $*" >&2; }
die()  { echo "[bootstrap] ERROR: $*" >&2; exit 1; }

[[ -f "$CATALOG" ]] || die "Catalog not found: $CATALOG"
[[ -f "$SETUP_SCRIPT" ]] || die "Setup script not found: $SETUP_SCRIPT"

# ── Parse flags ───────────────────────────────────────────────────────────────
FORCE=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --force)    FORCE=true ;;
    --dry-run)  DRY_RUN=true ;;
    *) die "Unknown flag: $arg" ;;
  esac
done

# ── Build flag array to forward to setup-mcp-server.sh ───────────────────────
FORWARD_FLAGS=()
$FORCE   && FORWARD_FLAGS+=(--force)
$DRY_RUN && FORWARD_FLAGS+=(--dry-run)

# ── Extract URLs from catalog using only grep + sed (no extra deps) ───────────
# Reads lines of the form:   url: <value>
mapfile -t URLS < <(grep -E '^\s*url:' "$CATALOG" | sed 's/.*url:[[:space:]]*//' | tr -d '\r')

[[ ${#URLS[@]} -gt 0 ]] || die "No servers found in $CATALOG"

log "Found ${#URLS[@]} server(s) in $CATALOG"
$FORCE   && log "Mode: --force (rebuild even if already built)"
$DRY_RUN && log "Mode: --dry-run (clone only, no docker build)"
echo ""

# ── Track results ─────────────────────────────────────────────────────────────
declare -a OK=()
declare -a SKIPPED=()
declare -a FAILED=()

for URL in "${URLS[@]}"; do
  log "Setting up: $URL"
  EXIT_CODE=0
  bash "$SETUP_SCRIPT" "$URL" "${FORWARD_FLAGS[@]}" || EXIT_CODE=$?

  case "$EXIT_CODE" in
    0) OK+=("$URL") ;;
    2) SKIPPED+=("$URL (no Dockerfile)") ;;
    *) FAILED+=("$URL (exit $EXIT_CODE)") ;;
  esac
  echo ""
done

# ── Generate mcp.json files from .example templates ──────────────────────────
bash "$ROOT_DIR/.github/skills/generate-mcp-configs/scripts/generate-mcp-configs.sh" --root "$ROOT_DIR"
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "════════════════════════════════════════"
echo "  BOOTSTRAP SUMMARY"
echo "════════════════════════════════════════"
echo "  Built   : ${#OK[@]}"
echo "  Skipped : ${#SKIPPED[@]}"
echo "  Failed  : ${#FAILED[@]}"
echo "  Configs  : .vscode/mcp.json, .cline/mcp.json (generated from .example)"

for s in "${SKIPPED[@]}"; do echo "    skip  $s"; done
for f in "${FAILED[@]}"; do echo "    FAIL  $f"; done

echo "════════════════════════════════════════"

[[ ${#FAILED[@]} -eq 0 ]] || exit 1
