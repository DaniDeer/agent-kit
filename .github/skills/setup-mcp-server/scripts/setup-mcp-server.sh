#!/usr/bin/env bash
# setup-mcp-server.sh
# Convenience wrapper: clones AND builds an MCP server in one step by calling
# clone-mcp-server.sh followed by build-mcp-server.sh.
#
# ⚠  This wrapper skips the interactive Dockerfile patching step.
# For the guided agent workflow (new server being added for the first time),
# use the two scripts separately so the Dockerfile can be patched in between:
#
#   1.  bash clone-mcp-server.sh  <URL>   — clone the repo
#   2.  (agent creates patched Dockerfile in .mcp-dockerfiles/<name>/ via fix-docker-perms skill)
#   3.  bash build-mcp-server.sh  <URL>   — build the Docker image
#
# This wrapper is used by bootstrap.sh, where the patched Dockerfiles are already
# committed to .mcp-dockerfiles/ and no further patching is needed.
#
# Usage:
#   bash setup-mcp-server.sh <GITHUB_URL> [--force] [--dry-run] [IMAGE_TAG_OVERRIDE]
#
# Flags:
#   --force    Re-clone and rebuild even if the image already exists
#   --dry-run  Clone only — skip docker build
#
# Examples:
#   bash setup-mcp-server.sh https://github.com/org/mcp-filesystem
#   bash setup-mcp-server.sh https://github.com/modelcontextprotocol/servers/tree/main/src/git
#   bash setup-mcp-server.sh https://github.com/org/mcp-filesystem --force

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ $# -lt 1 ]] && { echo "Usage: $0 <GITHUB_URL> [--force] [--dry-run] [IMAGE_TAG_OVERRIDE]" >&2; exit 1; }

# ── Parse flags ───────────────────────────────────────────────────────────────
GITHUB_URL=""
IMAGE_TAG_OVERRIDE=""
EXTRA_FLAGS=()

for arg in "$@"; do
  case "$arg" in
    --force|--dry-run) EXTRA_FLAGS+=("$arg") ;;
    http*) GITHUB_URL="$arg" ;;
    *) IMAGE_TAG_OVERRIDE="$arg" ;;
  esac
done

[[ -z "$GITHUB_URL" ]] && { echo "Usage: $0 <GITHUB_URL> [--force] [--dry-run] [IMAGE_TAG_OVERRIDE]" >&2; exit 1; }

BUILD_ARGS=("$GITHUB_URL")
[[ -n "$IMAGE_TAG_OVERRIDE" ]] && BUILD_ARGS+=("$IMAGE_TAG_OVERRIDE")

bash "$SCRIPT_DIR/clone-mcp-server.sh" "$GITHUB_URL" ${IMAGE_TAG_OVERRIDE:+"$IMAGE_TAG_OVERRIDE"}
bash "$SCRIPT_DIR/build-mcp-server.sh" "${BUILD_ARGS[@]}" "${EXTRA_FLAGS[@]}"
