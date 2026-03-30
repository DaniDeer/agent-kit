#!/usr/bin/env bash
# update-mcp-servers.sh
# Pulls upstream changes for each cloned MCP server and rebuilds the Docker
# image when new commits are detected.
#
# Usage:
#   bash update-mcp-servers.sh [--force] [--dry-run] [server-name ...]
#
# Flags:
#   --force     Rebuild every image even when no new commits were pulled
#   --dry-run   Pull updates but skip Docker build; only report what would change
#
# Examples:
#   bash update-mcp-servers.sh                    # update all servers
#   bash update-mcp-servers.sh servers-git        # update one server
#   bash update-mcp-servers.sh --force            # force rebuild of all
#   bash update-mcp-servers.sh --dry-run          # check for updates only

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
MCP_SERVERS_DIR="$ROOT_DIR/mcp-servers"
MCP_DOCKERFILES_DIR="$ROOT_DIR/.mcp-dockerfiles"

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo "[update-mcp-servers] $*"; }
warn()    { echo "[update-mcp-servers] WARN: $*" >&2; }
success() { echo "[update-mcp-servers] OK  : $*"; }
fail()    { echo "[update-mcp-servers] FAIL: $*" >&2; }

require_cmd() {
  command -v "$1" &>/dev/null || { fail "'$1' is required but not installed."; exit 1; }
}

# ── Parse flags and positional args ──────────────────────────────────────────
FORCE=false
DRY_RUN=false
TARGET_SERVERS=()

for arg in "$@"; do
  case "$arg" in
    --force)    FORCE=true ;;
    --dry-run)  DRY_RUN=true ;;
    *)          TARGET_SERVERS+=("$arg") ;;
  esac
done

require_cmd git
require_cmd docker

# ── Verify mcp-servers directory ─────────────────────────────────────────────
if [[ ! -d "$MCP_SERVERS_DIR" ]]; then
  fail "No mcp-servers/ directory found at $MCP_SERVERS_DIR"
  fail "Add servers first with the setup-mcp-server skill."
  exit 1
fi

# ── Build server list ─────────────────────────────────────────────────────────
if [[ ${#TARGET_SERVERS[@]} -gt 0 ]]; then
  SERVER_DIRS=()
  for name in "${TARGET_SERVERS[@]}"; do
    dir="$MCP_SERVERS_DIR/$name"
    if [[ -d "$dir" ]]; then
      SERVER_DIRS+=("$dir")
    else
      warn "Server directory not found: $dir — skipping"
    fi
  done
else
  mapfile -t SERVER_DIRS < <(find "$MCP_SERVERS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi

if [[ ${#SERVER_DIRS[@]} -eq 0 ]]; then
  fail "No server directories found under $MCP_SERVERS_DIR"
  exit 1
fi

# ── Track results for summary table ──────────────────────────────────────────
declare -a RESULT_NAME=()
declare -a RESULT_OLD_SHA=()
declare -a RESULT_NEW_SHA=()
declare -a RESULT_IMAGE=()
declare -a RESULT_ACTION=()

# ── Process each server ───────────────────────────────────────────────────────
for SERVER_DIR in "${SERVER_DIRS[@]}"; do
  SERVER_NAME="$(basename "$SERVER_DIR")"
  IMAGE_BASE="mcp-$SERVER_NAME"

  echo ""
  log "────────────────────────────────────────"
  log "Server : $SERVER_NAME"

  # Must be a git repo
  if [[ ! -d "$SERVER_DIR/.git" ]]; then
    warn "$SERVER_DIR is not a git repository — skipping"
    RESULT_NAME+=("$SERVER_NAME")
    RESULT_OLD_SHA+=("-")
    RESULT_NEW_SHA+=("-")
    RESULT_IMAGE+=("-")
    RESULT_ACTION+=("skipped (not a git repo)")
    continue
  fi

  # Record current SHA before pull
  OLD_SHA="$(git -C "$SERVER_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  log "Current SHA: $OLD_SHA"

  # Pull upstream changes
  PULL_OUTPUT=""
  if ! PULL_OUTPUT="$(git -C "$SERVER_DIR" pull --ff-only 2>&1)"; then
    warn "git pull failed for $SERVER_NAME:"
    warn "$PULL_OUTPUT"
    RESULT_NAME+=("$SERVER_NAME")
    RESULT_OLD_SHA+=("$OLD_SHA")
    RESULT_NEW_SHA+=("$OLD_SHA")
    RESULT_IMAGE+=("-")
    RESULT_ACTION+=("FAILED (git pull error)")
    continue
  fi

  NEW_SHA="$(git -C "$SERVER_DIR" rev-parse --short HEAD)"
  log "New SHA    : $NEW_SHA"

  UPDATED=false
  UPSTREAM_DOCKERFILE_CHANGED=false
  if [[ "$OLD_SHA" != "$NEW_SHA" ]]; then
    UPDATED=true
    log "New commits pulled."
    # Check if the upstream Dockerfile changed between the two SHAs
    if git -C "$SERVER_DIR" diff --name-only "$OLD_SHA" "$NEW_SHA" 2>/dev/null \
        | grep -qiE '^(.*/)?(Dockerfile|dockerfile)(\..*)?$'; then
      UPSTREAM_DOCKERFILE_CHANGED=true
      warn "Upstream Dockerfile changed between $OLD_SHA and $NEW_SHA."
      warn "Review .mcp-dockerfiles/$SERVER_NAME/Dockerfile — patches may need to be re-applied."
    fi
  else
    log "Already up to date."
  fi

  # Decide whether to rebuild
  if ! $UPDATED && ! $FORCE; then
    RESULT_NAME+=("$SERVER_NAME")
    RESULT_OLD_SHA+=("$OLD_SHA")
    RESULT_NEW_SHA+=("$NEW_SHA")
    RESULT_IMAGE+=("$IMAGE_BASE:$NEW_SHA / :latest")
    RESULT_ACTION+=("up to date")
    continue
  fi

  if $DRY_RUN; then
    log "[dry-run] Would rebuild $IMAGE_BASE:$NEW_SHA"
    RESULT_NAME+=("$SERVER_NAME")
    RESULT_OLD_SHA+=("$OLD_SHA")
    RESULT_NEW_SHA+=("$NEW_SHA")
    RESULT_IMAGE+=("$IMAGE_BASE:$NEW_SHA")
    RESULT_ACTION+=("dry-run (would rebuild)")
    continue
  fi

  # ── Locate the Dockerfile ─────────────────────────────────────────────────
  # Priority: 1) patched copy in .mcp-dockerfiles/<name>/Dockerfile
  #           2) original upstream Dockerfile in the clone directory
  #
  # Servers cloned from a monorepo subdirectory may have the Dockerfile in a
  # subdirectory (sparse checkout root or one level down).
  PATCHED_DOCKERFILE="$MCP_DOCKERFILES_DIR/$SERVER_NAME/Dockerfile"
  ORIGINAL_DOCKERFILE=""
  BUILD_CTX=""

  for candidate_dir in "$SERVER_DIR" "$SERVER_DIR"/src/*; do
    for candidate_file in Dockerfile Dockerfile.mcp dockerfile; do
      if [[ -f "$candidate_dir/$candidate_file" ]]; then
        ORIGINAL_DOCKERFILE="$candidate_dir/$candidate_file"
        BUILD_CTX="$candidate_dir"
        break 2
      fi
    done
  done

  if [[ -f "$PATCHED_DOCKERFILE" ]]; then
    USE_DOCKERFILE="$PATCHED_DOCKERFILE"
    log "Dockerfile : $USE_DOCKERFILE (patched, from .mcp-dockerfiles/)"
    if $UPSTREAM_DOCKERFILE_CHANGED; then
      warn "Upstream Dockerfile changed — re-check $PATCHED_DOCKERFILE for stale patches."
      warn "If patches need updating, re-run the fix-docker-perms skill and commit the result."
    fi
  elif [[ -n "$ORIGINAL_DOCKERFILE" ]]; then
    USE_DOCKERFILE="$ORIGINAL_DOCKERFILE"
    log "Dockerfile : $USE_DOCKERFILE (original — no patched copy in .mcp-dockerfiles/)"
    warn "No patched Dockerfile at $PATCHED_DOCKERFILE"
    warn "Consider running the fix-docker-perms skill to create a patched copy."
  else
    warn "No Dockerfile found for $SERVER_NAME — skipping rebuild"
    RESULT_NAME+=("$SERVER_NAME")
    RESULT_OLD_SHA+=("$OLD_SHA")
    RESULT_NEW_SHA+=("$NEW_SHA")
    RESULT_IMAGE+=("-")
    RESULT_ACTION+=("skipped (no Dockerfile)")
    continue
  fi

  [[ -n "$BUILD_CTX" ]] || BUILD_CTX="$SERVER_DIR"
  log "Building   : $IMAGE_BASE:$NEW_SHA and $IMAGE_BASE:latest ..."

  if docker build \
      --file "$USE_DOCKERFILE" \
      --build-arg "HOST_UID=$(id -u)" \
      --build-arg "HOST_GID=$(id -g)" \
      --build-arg "HOST_USER=$(id -un)" \
      --tag  "$IMAGE_BASE:$NEW_SHA" \
      --tag  "$IMAGE_BASE:latest" \
      "$BUILD_CTX" ; then
    success "Built $IMAGE_BASE:$NEW_SHA  ($IMAGE_BASE:latest updated)"
    RESULT_ACTION_STR="rebuilt"
    if $FORCE && ! $UPDATED; then
      RESULT_ACTION_STR="rebuilt (forced)"
    fi
    RESULT_NAME+=("$SERVER_NAME")
    RESULT_OLD_SHA+=("$OLD_SHA")
    RESULT_NEW_SHA+=("$NEW_SHA")
    RESULT_IMAGE+=("$IMAGE_BASE:$NEW_SHA")
    RESULT_ACTION+=("$RESULT_ACTION_STR")
  else
    fail "Docker build failed for $SERVER_NAME"
    RESULT_NAME+=("$SERVER_NAME")
    RESULT_OLD_SHA+=("$OLD_SHA")
    RESULT_NEW_SHA+=("$NEW_SHA")
    RESULT_IMAGE+=("-")
    RESULT_ACTION+=("FAILED (docker build)")
  fi
done

# ── Summary table ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  UPDATE SUMMARY"
echo "════════════════════════════════════════════════════════════════════"
printf "  %-22s %-10s %-10s %-35s %s\n" "SERVER" "OLD SHA" "NEW SHA" "IMAGE" "ACTION"
printf "  %-22s %-10s %-10s %-35s %s\n" "──────────────────────" "────────" "────────" "──────────────────────────────────" "──────────────────────"
for i in "${!RESULT_NAME[@]}"; do
  printf "  %-22s %-10s %-10s %-35s %s\n" \
    "${RESULT_NAME[$i]}" \
    "${RESULT_OLD_SHA[$i]}" \
    "${RESULT_NEW_SHA[$i]}" \
    "${RESULT_IMAGE[$i]}" \
    "${RESULT_ACTION[$i]}"
done
echo "════════════════════════════════════════════════════════════════════"
