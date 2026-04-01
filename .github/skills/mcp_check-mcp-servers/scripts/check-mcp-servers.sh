#!/usr/bin/env bash
# check-mcp-servers.sh
# Read-only status check for all MCP servers registered in mcp-catalog.yaml.
# Reports whether each server's clone, patched Dockerfile, and Docker image
# are present and whether the image is current with the local git HEAD.
#
# No network calls, no side effects — purely inspects local state.
#
# Usage:
#   bash check-mcp-servers.sh [--root <dir>]
#
# Flags:
#   --root <dir>   Repo root directory (default: auto-detected from script location)
#
# Exit codes:
#   0   All servers are fully ready
#   1   One or more servers are missing or out of date

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { echo "[check-mcp-servers] $*"; }
warn() { echo "[check-mcp-servers] WARN: $*" >&2; }
die()  { echo "[check-mcp-servers] ERROR: $*" >&2; exit 1; }

# ── Parse flags ───────────────────────────────────────────────────────────────
ROOT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT_DIR="$2"; shift 2 ;;
    *) die "Unknown flag: $1" ;;
  esac
done

[[ -z "$ROOT_DIR" ]] && ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

CATALOG="$ROOT_DIR/mcp-catalog.yaml"
MCP_SERVERS_DIR="$ROOT_DIR/mcp-servers"
MCP_DOCKERFILES_DIR="$ROOT_DIR/.mcp-dockerfiles"

[[ -f "$CATALOG" ]] || die "Catalog not found: $CATALOG"

# ── Helpers ───────────────────────────────────────────────────────────────────
normalise_name() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g'; }

url_to_repo_name() {
  local url="${1%.git}"
  if [[ "$url" =~ ^https://github\.com/[^/]+/([^/]+)/tree/[^/]+/(.+)$ ]]; then
    local slug="${BASH_REMATCH[1]}"
    local leaf; leaf="$(basename "${BASH_REMATCH[2]}")"
    normalise_name "${slug}-${leaf}"
  else
    normalise_name "$(basename "$url")"
  fi
}

tick()  { echo "✓"; }
cross() { echo "✗"; }
dash()  { echo "-"; }

# ── Parse catalog ─────────────────────────────────────────────────────────────
# Parse all entries as tab-separated records: url  patched_dockerfile  transport  http_port  key
# http_port is derived from docker.ports[0] (first host-side port), e.g. "8000:8000" → "8000"
read_catalog_entries() {
  awk '
    /^  - key:/ {
      if (url != "") {
        printf "%s\t%s\t%s\t%s\t%s\n", url, patched_df, transport, http_port, key
      }
      key = $NF; url = ""; patched_df = ""; transport = "stdio"; http_port = ""
      in_docker = 0; in_ports = 0; first_port_done = 0
    }
    /^    url:/                { url = $NF }
    /^    patched_dockerfile:/ { patched_df = $NF }
    /^    transport:/          { transport = $NF }
    /^    docker:/             { in_docker = 1 }
    # Exit docker block on any entry-level field that is not "docker:"
    /^    [a-z]/ && !/^    docker:/ { if (in_docker) { in_docker = 0; in_ports = 0 } }
    in_docker && /^      ports:/   { in_ports = 1; next }
    in_docker && /^      [a-z]/ && !/^      ports:/ { in_ports = 0 }
    # First port list item: "8000:8000" → host port = "8000"
    in_docker && in_ports && !first_port_done && /^        - / {
      val = $0; gsub(/^        - /, "", val); gsub(/"/, "", val)
      http_port = val; sub(/:.*/, "", http_port)   # "8000:8000" → "8000"
      first_port_done = 1
    }
    END {
      if (url != "") {
        printf "%s\t%s\t%s\t%s\t%s\n", url, patched_df, transport, http_port, key
      }
    }
  ' "$CATALOG"
}

mapfile -t ENTRIES < <(read_catalog_entries)
[[ ${#ENTRIES[@]} -gt 0 ]] || die "No servers found in $CATALOG"

# ── Column widths ─────────────────────────────────────────────────────────────
COL_SERVER=24
COL_CHECK=7

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  MCP SERVER STATUS"
echo "════════════════════════════════════════════════════════════════"
printf "  %-${COL_SERVER}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %s\n" \
  "SERVER" "CLONE" "PATCH" "IMAGE" "SHA OK" "RUNNING" "STATUS"
printf "  %-${COL_SERVER}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %s\n" \
  "────────────────────────" "───────" "───────" "───────" "───────" "───────" "──────────"

# ── Check each server ─────────────────────────────────────────────────────────
PROBLEMS=0

for entry in "${ENTRIES[@]}"; do
  IFS=$'\t' read -r URL PATCHED_DF TRANSPORT HTTP_PORT KEY <<< "$entry"

  REPO_NAME="$(url_to_repo_name "$URL")"
  IMAGE_BASE="mcp-$REPO_NAME"
  CLONE_DIR="$MCP_SERVERS_DIR/$REPO_NAME"

  # Clone present?
  if [[ -d "$CLONE_DIR" ]]; then
    CLONE_OK="$(tick)"
  else
    CLONE_OK="$(cross)"
  fi

  # Patched Dockerfile present?
  PATCHED_PATH=""
  if [[ -n "$PATCHED_DF" ]]; then
    PATCHED_PATH="$ROOT_DIR/$PATCHED_DF"
  else
    PATCHED_PATH="$MCP_DOCKERFILES_DIR/$REPO_NAME/Dockerfile"
  fi
  if [[ -f "$PATCHED_PATH" ]]; then
    PATCH_OK="$(tick)"
  else
    PATCH_OK="$(cross)"
  fi

  # Docker image :latest present?
  if docker image inspect "${IMAGE_BASE}:latest" &>/dev/null; then
    IMAGE_OK="$(tick)"
  else
    IMAGE_OK="$(cross)"
  fi

  # SHA current? (check if :<git-sha> tag exists)
  SHA_OK="$(dash)"
  if [[ -d "$CLONE_DIR" ]] && [[ "$IMAGE_OK" == "$(tick)" ]]; then
    GIT_SHA="$(git -C "$CLONE_DIR" rev-parse --short HEAD 2>/dev/null || true)"
    if [[ -n "$GIT_SHA" ]] && docker image inspect "${IMAGE_BASE}:${GIT_SHA}" &>/dev/null; then
      SHA_OK="$(tick)"
    else
      SHA_OK="$(cross)"
    fi
  fi

  # RUNNING: only meaningful for HTTP-transport servers
  if [[ "$TRANSPORT" == "http" ]]; then
    CONTAINER_NAME="mcp-${KEY}"
    if docker inspect --format '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q '^true$'; then
      RUNNING_OK="$(tick)"
    else
      RUNNING_OK="$(cross)"
    fi
  else
    RUNNING_OK="$(dash)"   # stdio servers are ephemeral — not applicable
  fi

  # Overall status
  if [[ "$CLONE_OK" == "$(tick)" && "$PATCH_OK" == "$(tick)" && \
        "$IMAGE_OK" == "$(tick)" && "$SHA_OK" == "$(tick)" ]]; then
    STATUS="✅ ready"
    # Warn if HTTP server is not currently running
    if [[ "$TRANSPORT" == "http" && "$RUNNING_OK" == "$(cross)" ]]; then
      STATUS="✅ ready (not running)"
    fi
  elif [[ "$IMAGE_OK" == "$(cross)" && "$CLONE_OK" == "$(cross)" ]]; then
    STATUS="❌ not installed"
    (( PROBLEMS++ )) || true
  else
    STATUS="⚠️  incomplete"
    (( PROBLEMS++ )) || true
  fi

  printf "  %-${COL_SERVER}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %-${COL_CHECK}s  %s\n" \
    "$REPO_NAME" "$CLONE_OK" "$PATCH_OK" "$IMAGE_OK" "$SHA_OK" "$RUNNING_OK" "$STATUS"
done

echo "════════════════════════════════════════════════════════════════"
echo ""

if [[ $PROBLEMS -gt 0 ]]; then
  log "$PROBLEMS server(s) need attention — run bootstrap.sh to fix."
  exit 1
else
  log "All ${#ENTRIES[@]} server(s) are ready."
fi
