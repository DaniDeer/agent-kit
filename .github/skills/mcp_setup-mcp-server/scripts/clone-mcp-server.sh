#!/usr/bin/env bash
# clone-mcp-server.sh
# Clones (or pulls) a GitHub MCP server repo into mcp-servers/<name>/ and
# prints the clone directory, Dockerfile location, and image tag so the caller
# can patch the Dockerfile (fix-docker-perms) before running build-mcp-server.sh.
#
# Supports two URL forms:
#   Full repo   : https://github.com/org/repo
#   Subdirectory: https://github.com/org/repo/tree/<branch>/path/to/server
#
# Usage:
#   bash clone-mcp-server.sh <GITHUB_URL> [IMAGE_TAG_OVERRIDE]
#
# Examples:
#   bash clone-mcp-server.sh https://github.com/org/mcp-filesystem
#   bash clone-mcp-server.sh https://github.com/modelcontextprotocol/servers/tree/main/src/git

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
MCP_SERVERS_DIR="$ROOT_DIR/mcp-servers"

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { echo "[clone-mcp-server] $*"; }
warn() { echo "[clone-mcp-server] WARN: $*" >&2; }
die()  { echo "[clone-mcp-server] ERROR: $*" >&2; exit 1; }

require_cmd() { command -v "$1" &>/dev/null || die "'$1' is required but not installed."; }
normalise_name() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g'; }

# ── Input validation ──────────────────────────────────────────────────────────
[[ $# -lt 1 ]] && die "Usage: $0 <GITHUB_URL> [IMAGE_TAG_OVERRIDE]"

INPUT_URL="${1%.git}"
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

IMAGE_TAG="${2:-mcp-$REPO_NAME}"
CLONE_DIR="$MCP_SERVERS_DIR/$REPO_NAME"

log "Repo URL    : $REPO_URL"
[[ -n "$SUBPATH"      ]] && log "Sub-path    : $SUBPATH"
[[ -n "$CLONE_BRANCH" ]] && log "Branch      : $CLONE_BRANCH"
log "Clone dir   : $CLONE_DIR"
log "Image tag   : $IMAGE_TAG"

# ── Clone or update ───────────────────────────────────────────────────────────
mkdir -p "$MCP_SERVERS_DIR"

if [[ -d "$CLONE_DIR/.git" ]]; then
  log "Repository already cloned — pulling latest changes..."
  # Use fetch + reset instead of pull --ff-only: works correctly on shallow clones
  # even after upstream force-pushes or divergence.
  git -C "$CLONE_DIR" fetch --depth=1 origin
  git -C "$CLONE_DIR" reset --hard FETCH_HEAD
  # Re-apply sparse-checkout so the subpath files are present after the pull.
  if [[ -n "$SUBPATH" ]]; then
    git -C "$CLONE_DIR" sparse-checkout reapply
  fi
else
  log "Cloning repository..."
  if [[ -n "$CLONE_BRANCH" ]]; then
    git clone --depth=1 --branch "$CLONE_BRANCH" "$REPO_URL" "$CLONE_DIR"
    git -C "$CLONE_DIR" sparse-checkout init --cone
    git -C "$CLONE_DIR" sparse-checkout set "$SUBPATH"
  else
    git clone --depth=1 "$REPO_URL" "$CLONE_DIR"
  fi
fi

# ── Determine build context and locate Dockerfile ─────────────────────────────
BUILD_CTX="$CLONE_DIR"
[[ -n "$SUBPATH" ]] && BUILD_CTX="$CLONE_DIR/$SUBPATH"
[[ -d "$BUILD_CTX" ]] || die "Expected build context directory not found: $BUILD_CTX"

DOCKERFILE=""
for candidate in Dockerfile Dockerfile.mcp dockerfile; do
  if [[ -f "$BUILD_CTX/$candidate" ]]; then
    DOCKERFILE="$candidate"
    break
  fi
done

if [[ -z "$DOCKERFILE" ]]; then
  warn "No Dockerfile found in $BUILD_CTX"
  warn "Checked: Dockerfile, Dockerfile.mcp, dockerfile"
  warn "If the repo uses docker-compose or a custom build, configure the image manually."
  exit 2
fi

GIT_SHA="$(git -C "$CLONE_DIR" rev-parse --short HEAD)"
IMAGE_TAG_LATEST="${IMAGE_TAG}:latest"
IMAGE_TAG_SHA="${IMAGE_TAG}:${GIT_SHA}"

log "Dockerfile  : $BUILD_CTX/$DOCKERFILE"
log "Git SHA     : $GIT_SHA"

# ── Print summary with next-step instructions ─────────────────────────────────
echo ""
echo "─────────────────────────────────────────────────────"
echo "  MCP SERVER CLONED"
echo "  Repo name    : $REPO_NAME"
echo "  Git SHA      : $GIT_SHA"
echo "  Clone dir    : $CLONE_DIR"
echo "  Dockerfile   : $BUILD_CTX/$DOCKERFILE"
echo "  Image tag    : $IMAGE_TAG_LATEST"
echo ""
echo "  Next steps:"
echo "  1. Patch Dockerfile for non-root use (fix-docker-perms skill):"
echo "       bash $ROOT_DIR/.github/skills/fix-docker-perms/scripts/fix-docker-perms.sh"
echo "       # Create patched copy at:"
echo "       #   $ROOT_DIR/.mcp-dockerfiles/$REPO_NAME/Dockerfile"
echo "       # Do NOT modify the original: $BUILD_CTX/$DOCKERFILE"
echo "  2. Build the Docker image:"
echo "       bash $SCRIPT_DIR/build-mcp-server.sh '$1' ${2:-}"
echo "─────────────────────────────────────────────────────"
