#!/usr/bin/env bash
# start-http-mcp-servers.sh
# Manage the lifecycle of HTTP-transport MCP servers registered in mcp-catalog.yaml.
#
# HTTP-transport servers run as long-lived Docker daemon containers
# (not one-shot --rm -i stdio containers). They must be running before the
# MCP client connects via a URL such as http://localhost:8000/sse.
#
# Usage:
#   bash start-http-mcp-servers.sh [options]
#
# Options:
#   (no args)          Start all transport:http servers in the catalog
#   --server <key>     Start one specific server by catalog key  (e.g. --server browser)
#   --stop             Stop all transport:http servers
#   --stop --server <key>   Stop a specific server
#   --status           Print running/healthy status and exit (no state changes)
#   --root <dir>       Repo root directory (default: auto-detected)
#   --wait             Wait for all started servers to be healthy before exiting (default: true)
#   --no-wait          Start containers and return immediately without health-polling
#
# Environment / secrets:
#   Vars listed in the catalog's  docker.environment  list are passed to the
#   container as  -e KEY=VALUE  flags.  Bare names inherit from the host env;
#   KEY=value entries are passed literally.
#   Put secrets in a  .env  file at the repo root (git-ignored) — auto-sourced:
#
#     echo "OPENAI_API_KEY=sk-..." >> .env
#
# Container naming convention:
#   mcp-<catalog-key>  (e.g. key: browser → container: mcp-browser)
#
# Requires: docker, curl

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
READY_TIMEOUT=90   # seconds to wait for HTTP endpoint

log()  { echo "[start-http-mcp-servers] $*"; }
warn() { echo "[start-http-mcp-servers] WARN: $*" >&2; }
die()  { echo "[start-http-mcp-servers] ERROR: $*" >&2; exit 1; }

# ── Parse flags ───────────────────────────────────────────────────────────────
ROOT_DIR=""
TARGET_KEY=""
ACTION="start"    # start | stop | status
DO_WAIT=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)     ROOT_DIR="$2"; shift 2 ;;
    --server)   TARGET_KEY="$2"; shift 2 ;;
    --stop)     ACTION="stop"; shift ;;
    --status)   ACTION="status"; shift ;;
    --wait)     DO_WAIT=true; shift ;;
    --no-wait)  DO_WAIT=false; shift ;;
    *) die "Unknown flag: $1" ;;
  esac
done

[[ -z "$ROOT_DIR" ]] && ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

CATALOG="$ROOT_DIR/mcp-catalog.yaml"
[[ -f "$CATALOG" ]] || die "Catalog not found: $CATALOG"

# ── Source optional .env file for secrets ─────────────────────────────────────
if [[ -f "$ROOT_DIR/.env" ]]; then
  log "Sourcing secrets from $ROOT_DIR/.env"
  set -a; source "$ROOT_DIR/.env"; set +a
fi

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

container_is_running() {
  local name="$1"
  docker inspect --format '{{.State.Running}}' "$name" 2>/dev/null | grep -q '^true$'
}

wait_for_http() {
  local url="$1"
  local label="$2"
  local deadline=$(( $(date +%s) + READY_TIMEOUT ))
  log "Waiting for ${label} at ${url} ..."
  while true; do
    # SSE endpoints keep the connection open — use -w to capture the HTTP status
    # code rather than relying on curl's exit code (which is 28/timeout for SSE).
    local http_code
    http_code=$(curl -s -m 2 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || true)
    if [[ "$http_code" == "200" ]]; then
      log "${label}: ready ✓"
      return 0
    fi
    if [[ $(date +%s) -ge $deadline ]]; then
      warn "${label}: timed out after ${READY_TIMEOUT}s"
      warn "Check container logs: docker logs ${label}"
      return 1
    fi
    sleep 1
  done
}

# ── Parse catalog: extract http-transport entries ─────────────────────────────
# Output format (tab-separated):
#   key  url  sse_path  ports  environment  volumes
#
# ports / environment / volumes are pipe-delimited lists, e.g.:
#   8000:8000|5900:5900
#   OPENAI_API_KEY|DEBUG=false
#   /host/path:/data
#
# The docker: block uses Docker Compose-style syntax:
#   docker:
#     ports:
#       - "8000:8000"
#     environment:
#       - OPENAI_API_KEY      # bare → inherit from host
#       - DEBUG=false         # literal KEY=value
#     volumes:
#       - "/host/path:/data"
read_http_entries() {
  awk '
    /^  - key:/ {
      if (key != "" && transport == "http") {
        printf "%s\t%s\t%s\t%s\t%s\t%s\n", key, url, sse_path, ports, env, vols
      }
      key = $NF; url = ""; transport = "stdio"; sse_path = "/sse"
      ports = ""; env = ""; vols = ""
      in_docker = 0; in_ports = 0; in_env = 0; in_vols = 0
    }
    /^    url:/        { url = $NF }
    /^    transport:/  { transport = $NF }
    /^    sse_path:/   { sse_path = $NF }
    /^    docker:/     { in_docker = 1 }
    # Any entry-level field (4-space indent) that is not "docker:" exits the block
    /^    [a-z]/ && !/^    docker:/ { if (in_docker) { in_docker = 0; in_ports = 0; in_env = 0; in_vols = 0 } }
    # docker sub-section headers (6-space indent)
    in_docker && /^      ports:/       { in_ports = 1; in_env = 0; in_vols = 0; next }
    in_docker && /^      environment:/ { in_env = 1; in_ports = 0; in_vols = 0; next }
    in_docker && /^      volumes:/     { in_vols = 1; in_ports = 0; in_env = 0; next }
    # Any 6-space field that is not a list item exits the sub-sections
    in_docker && /^      [a-z]/ { in_ports = 0; in_env = 0; in_vols = 0 }
    # List items (8-space indent + "- ")
    in_docker && /^        - / {
      val = $0; gsub(/^        - /, "", val); gsub(/"/, "", val); gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      if (in_ports)  { ports = (ports == "" ? val : ports "|" val) }
      else if (in_env)  { env   = (env   == "" ? val : env   "|" val) }
      else if (in_vols) { vols  = (vols  == "" ? val : vols  "|" val) }
    }
    END {
      if (key != "" && transport == "http") {
        printf "%s\t%s\t%s\t%s\t%s\t%s\n", key, url, sse_path, ports, env, vols
      }
    }
  ' "$CATALOG"
}

# ── Helpers: parse pipe-delimited fields from read_http_entries output ────────

# First host-side port from a pipe-delimited "host:container|..." list
first_host_port() { echo "${1%%:*}"; }   # e.g. "8000:8000|5900:5900" → "8000"

# Build docker -p flags from pipe-delimited port list
build_port_args() {
  local IFS='|'
  local port_args=()
  for p in $1; do
    [[ -n "$p" ]] && port_args+=("-p" "$p")
  done
  printf '%s\n' "${port_args[@]+"${port_args[@]}"}"
}

# ── Status table ──────────────────────────────────────────────────────────────
print_status_table() {
  local entries
  entries="$(read_http_entries)"
  if [[ -z "$entries" ]]; then
    log "No HTTP-transport servers in catalog."
    return
  fi
  printf "\n  %-20s  %-12s  %-10s  %s\n" "SERVER" "CONTAINER" "PORT" "STATUS"
  printf "  %-20s  %-12s  %-10s  %s\n"   "────────────────────" "────────────" "──────────" "──────────"
  while IFS=$'\t' read -r key url sse_path ports env_spec vols; do
    local repo_name; repo_name="$(url_to_repo_name "$url")"
    local container="mcp-${key}"
    local http_port; http_port="$(first_host_port "$ports")"
    local health_url="http://localhost:${http_port}${sse_path}"
    local status
    if container_is_running "$container"; then
      local hc
      hc=$(curl -s -m 2 -o /dev/null -w "%{http_code}" "$health_url" 2>/dev/null || true)
      if [[ "$hc" == "200" ]]; then
        status="✅ running + healthy"
      else
        status="⚠️  running, endpoint not ready (HTTP ${hc})"
      fi
    else
      status="⛔ stopped"
    fi
    printf "  %-20s  %-12s  %-10s  %s\n" "$repo_name" "$container" "$http_port" "$status"
  done <<< "$entries"
  printf "\n"
}

# ── Start a single server ──────────────────────────────────────────────────────
start_server() {
  local key="$1" url="$2" sse_path="$3" ports="$4" env_spec="$5" vols="$6"
  local repo_name; repo_name="$(url_to_repo_name "$url")"
  local image="mcp-${repo_name}:latest"
  local container="mcp-${key}"
  local http_port; http_port="$(first_host_port "$ports")"
  local health_url="http://localhost:${http_port}${sse_path}"

  # Check image exists
  if ! docker image inspect "$image" &>/dev/null; then
    die "Image '$image' not found. Run bootstrap.sh first to build it."
  fi

  # Already running?
  if container_is_running "$container"; then
    log "${key}: container '${container}' already running — skipping start."
    if [[ "$DO_WAIT" == true ]]; then
      wait_for_http "$health_url" "$container" || true
    fi
    return
  fi

  # Remove any stopped container with the same name
  docker rm -f "$container" >/dev/null 2>&1 || true

  # Build -p flags from docker.ports list
  local port_args=()
  while IFS='|' read -ra port_list; do
    for p in "${port_list[@]}"; do
      [[ -n "$p" ]] && port_args+=("-p" "$p")
    done
  done <<< "$ports"

  # Build -e flags from docker.environment list
  # Bare name (e.g. OPENAI_API_KEY) → inherit from host env
  # KEY=value → pass literally
  local env_args=()
  while IFS='|' read -ra env_list; do
    for spec in "${env_list[@]}"; do
      [[ -z "$spec" ]] && continue
      if [[ "$spec" == *=* ]]; then
        env_args+=("-e" "$spec")
      elif [[ -n "${!spec:-}" ]]; then
        env_args+=("-e" "${spec}=${!spec}")
      else
        warn "${key}: env var '${spec}' is not set — container may not function correctly."
      fi
    done
  done <<< "$env_spec"

  # Build -v flags from docker.volumes list
  local vol_args=()
  while IFS='|' read -ra vol_list; do
    for v in "${vol_list[@]}"; do
      [[ -n "$v" ]] && vol_args+=("-v" "$v")
    done
  done <<< "$vols"

  log "Starting container '${container}' from image '${image}' ..."
  log "  ports: ${ports//|/  }"
  docker run -d \
    --name "$container" \
    "${port_args[@]+"${port_args[@]}"}" \
    "${env_args[@]+"${env_args[@]}"}" \
    "${vol_args[@]+"${vol_args[@]}"}" \
    "$image"

  if [[ "$DO_WAIT" == true ]]; then
    wait_for_http "$health_url" "$container"
  fi
}

# ── Stop a single server ──────────────────────────────────────────────────────
stop_server() {
  local key="$1"
  local container="mcp-${key}"
  if docker inspect "$container" &>/dev/null; then
    log "Stopping and removing container '${container}' ..."
    docker rm -f "$container" >/dev/null
    log "${key}: stopped."
  else
    log "${key}: container '${container}' not found — nothing to stop."
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  if [[ "$ACTION" == "status" ]]; then
    print_status_table
    return
  fi

  local entries
  entries="$(read_http_entries)"

  if [[ -z "$entries" ]]; then
    log "No HTTP-transport servers found in catalog."
    return
  fi

  local found_target=false

  while IFS=$'\t' read -r key url sse_path ports env_spec vols; do
    # Filter to target key if specified
    if [[ -n "$TARGET_KEY" && "$key" != "$TARGET_KEY" ]]; then
      continue
    fi
    found_target=true

    if [[ "$ACTION" == "stop" ]]; then
      stop_server "$key"
    else
      start_server "$key" "$url" "$sse_path" "$ports" "$env_spec" "$vols"
    fi
  done <<< "$entries"

  if [[ -n "$TARGET_KEY" && "$found_target" == false ]]; then
    die "No HTTP-transport server with key '${TARGET_KEY}' found in catalog."
  fi

  if [[ "$ACTION" == "start" ]]; then
    log "Done. Use --status to check health, or --stop to shut down."
  fi
}

main "$@"
