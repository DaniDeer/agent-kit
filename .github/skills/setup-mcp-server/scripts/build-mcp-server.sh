#!/usr/bin/env bash
# build-mcp-server.sh
# Builds the Docker image for a previously-cloned MCP server.
# The repository must already exist in mcp-servers/ (use clone-mcp-server.sh).
#
# Patched Dockerfile lookup (in priority order):
#   1. .mcp-dockerfiles/<server-name>/Dockerfile  (version-controlled, preferred)
#   2. <build-context>/Dockerfile                 (original, fallback)
#
# If a patched Dockerfile exists at .mcp-dockerfiles/<server-name>/Dockerfile, it is
# used with --file while the build context remains the original source directory.
# This keeps the patched file in version control without modifying the upstream clone.
#
# Supports the same two URL forms as clone-mcp-server.sh — the URL is used
# only to derive the clone directory name and image tag.
#
# Usage:
#   bash build-mcp-server.sh <GITHUB_URL> [--force] [--dry-run] [IMAGE_TAG_OVERRIDE]
#
# Flags:
#   --force    Rebuild even if the image at :<git-sha> already exists in Docker
#   --dry-run  Print what would be built but do not run docker build
#
# Examples:
#   bash build-mcp-server.sh https://github.com/org/mcp-filesystem
#   bash build-mcp-server.sh https://github.com/modelcontextprotocol/servers/tree/main/src/git
#   bash build-mcp-server.sh https://github.com/org/mcp-filesystem --force

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
MCP_SERVERS_DIR="$ROOT_DIR/mcp-servers"
MCP_DOCKERFILES_DIR="$ROOT_DIR/.mcp-dockerfiles"
VSCODE_DIR="$ROOT_DIR/.vscode"
CLINE_DIR="$ROOT_DIR/.cline"
MCP_CONFIG_VSCODE="$VSCODE_DIR/mcp.json"
MCP_CONFIG_CLINE="$CLINE_DIR/mcp.json"

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { echo "[build-mcp-server] $*"; }
warn() { echo "[build-mcp-server] WARN: $*" >&2; }
die()  { echo "[build-mcp-server] ERROR: $*" >&2; exit 1; }

require_cmd() { command -v "$1" &>/dev/null || die "'$1' is required but not installed."; }
normalise_name() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g'; }

# ── Input validation ──────────────────────────────────────────────────────────
[[ $# -lt 1 ]] && die "Usage: $0 <GITHUB_URL> [--force] [--dry-run] [IMAGE_TAG_OVERRIDE]"

# ── Parse flags ───────────────────────────────────────────────────────────────
GITHUB_URL=""
IMAGE_TAG_OVERRIDE=""
FORCE=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --force)    FORCE=true ;;
    --dry-run)  DRY_RUN=true ;;
    http*)      GITHUB_URL="$arg" ;;
    *)          IMAGE_TAG_OVERRIDE="$arg" ;;
  esac
done

[[ -z "$GITHUB_URL" ]] && die "Usage: $0 <GITHUB_URL> [--force] [--dry-run] [IMAGE_TAG_OVERRIDE]"

INPUT_URL="${GITHUB_URL%.git}"
require_cmd docker
require_cmd git

# ── Parse URL ─────────────────────────────────────────────────────────────────
SUBPATH=""
CLONE_BRANCH=""

if [[ "$INPUT_URL" =~ ^(https://github\.com/[^/]+/[^/]+)/tree/([^/]+)/(.+)$ ]]; then
  REPO_URL="${BASH_REMATCH[1]}"
  CLONE_BRANCH="${BASH_REMATCH[2]}"
  SUBPATH="${BASH_REMATCH[3]}"
  REPO_SLUG="$(basename "$REPO_URL")"
  SERVER_LEAF="$(basename "$SUBPATH")"
  REPO_NAME="$(normalise_name "${REPO_SLUG}-${SERVER_LEAF}")"
else
  REPO_URL="$INPUT_URL"
  REPO_NAME="$(normalise_name "$(basename "$REPO_URL")")"
fi

IMAGE_TAG="${IMAGE_TAG_OVERRIDE:-mcp-$REPO_NAME}"
CLONE_DIR="$MCP_SERVERS_DIR/$REPO_NAME"

log "Repo name   : $REPO_NAME"
log "Clone dir   : $CLONE_DIR"
log "Image tag   : $IMAGE_TAG"
$FORCE   && log "Mode        : --force (rebuild even if image exists)"
$DRY_RUN && log "Mode        : --dry-run (no docker build)"

# ── Verify clone exists ───────────────────────────────────────────────────────
[[ -d "$CLONE_DIR" ]] || die "Clone directory not found: $CLONE_DIR — run clone-mcp-server.sh first."

# ── Determine build context ───────────────────────────────────────────────────
BUILD_CTX="$CLONE_DIR"
[[ -n "$SUBPATH" ]] && BUILD_CTX="$CLONE_DIR/$SUBPATH"
[[ -d "$BUILD_CTX" ]] || die "Expected build context directory not found: $BUILD_CTX"

# ── Locate Dockerfile — patched copy takes priority ──────────────────────────
PATCHED_DOCKERFILE="$MCP_DOCKERFILES_DIR/$REPO_NAME/Dockerfile"
ORIGINAL_DOCKERFILE=""

for candidate in Dockerfile Dockerfile.mcp dockerfile; do
  if [[ -f "$BUILD_CTX/$candidate" ]]; then
    ORIGINAL_DOCKERFILE="$BUILD_CTX/$candidate"
    break
  fi
done

if [[ -f "$PATCHED_DOCKERFILE" ]]; then
  USE_DOCKERFILE="$PATCHED_DOCKERFILE"
  log "Dockerfile  : $USE_DOCKERFILE (patched, from .mcp-dockerfiles/)"
elif [[ -n "$ORIGINAL_DOCKERFILE" ]]; then
  USE_DOCKERFILE="$ORIGINAL_DOCKERFILE"
  log "Dockerfile  : $USE_DOCKERFILE (original — no patched copy found)"
  warn "No patched Dockerfile at $PATCHED_DOCKERFILE"
  warn "Consider running the fix-docker-perms skill to create a patched copy."
else
  warn "No Dockerfile found in $BUILD_CTX"
  warn "Checked: Dockerfile, Dockerfile.mcp, dockerfile"
  warn "If the repo uses docker-compose or a custom build, configure the image manually."
  exit 2
fi

# ── Derive version tag from git SHA ──────────────────────────────────────────
GIT_SHA="$(git -C "$CLONE_DIR" rev-parse --short HEAD)"
IMAGE_TAG_SHA="${IMAGE_TAG}:${GIT_SHA}"
IMAGE_TAG_LATEST="${IMAGE_TAG}:latest"

log "Git SHA     : $GIT_SHA"
log "Image (sha) : $IMAGE_TAG_SHA"

# ── Skip build if image already exists (unless --force) ──────────────────────
if ! $FORCE && docker image inspect "$IMAGE_TAG_SHA" &>/dev/null; then
  log "Image $IMAGE_TAG_SHA already exists — skipping build (use --force to rebuild)"
else
  if $DRY_RUN; then
    log "[dry-run] Would run:"
    log "  docker build --file $USE_DOCKERFILE --build-arg HOST_UID=$(id -u) --build-arg HOST_GID=$(id -g) --build-arg HOST_USER=$(id -un) --tag $IMAGE_TAG_SHA --tag $IMAGE_TAG_LATEST $BUILD_CTX"
  else
    log "Building Docker image '$IMAGE_TAG_SHA' (also tagging ':latest') ..."
    docker build \
      --file "$USE_DOCKERFILE" \
      --build-arg "HOST_UID=$(id -u)" \
      --build-arg "HOST_GID=$(id -g)" \
      --build-arg "HOST_USER=$(id -un)" \
      --tag  "$IMAGE_TAG_SHA" \
      --tag  "$IMAGE_TAG_LATEST" \
      "$BUILD_CTX"
    log "Docker image built successfully: $IMAGE_TAG_SHA  ($IMAGE_TAG_LATEST)"
  fi
fi

# ── Ensure config directories exist ──────────────────────────────────────────
mkdir -p "$VSCODE_DIR" "$CLINE_DIR"
if [[ ! -f "$MCP_CONFIG_VSCODE" ]]; then
  log "Creating $MCP_CONFIG_VSCODE"
  printf '{\n  "servers": {}\n}\n' > "$MCP_CONFIG_VSCODE"
fi
if [[ ! -f "$MCP_CONFIG_CLINE" ]]; then
  log "Creating $MCP_CONFIG_CLINE"
  printf '{\n  "mcpServers": {}\n}\n' > "$MCP_CONFIG_CLINE"
fi

# ── Print summary ─────────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────────────────────────"
echo "  MCP SERVER BUILT SUCCESSFULLY"
echo "  Repo name    : $REPO_NAME"
echo "  Git SHA      : $GIT_SHA"
if $DRY_RUN; then
  echo "  Image        : (dry-run — not built)"
else
  echo "  Image (sha)  : $IMAGE_TAG_SHA"
  echo "  Image (alias): $IMAGE_TAG_LATEST"
fi
echo "  Clone dir    : $CLONE_DIR"
echo "  Dockerfile   : $USE_DOCKERFILE"
echo ""
echo "  Suggested .vscode/mcp.json entry (VS Code / Copilot):"
echo ""
cat <<JSON
  "$REPO_NAME": {
    "type": "stdio",
    "command": "docker",
    "args": ["run", "--rm", "-i", "$IMAGE_TAG_LATEST"],
    "env": {}
  }
JSON
echo ""
echo "  Suggested .cline/mcp.json entry (Cline):"
echo ""
cat <<JSON
  "$REPO_NAME": {
    "command": "docker",
    "args": ["run", "--rm", "-i", "$IMAGE_TAG_LATEST"],
    "disabled": false,
    "alwaysAllow": []
  }
JSON
echo "─────────────────────────────────────────────────────"
