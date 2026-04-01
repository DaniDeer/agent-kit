# Skill: start-http-mcp-servers

Manage the lifecycle of HTTP-transport MCP servers registered in `mcp-catalog.yaml`.

HTTP-transport servers (e.g. `browser`) run as **persistent Docker daemon containers**
rather than the ephemeral `--rm -i` containers used for stdio servers. They expose an
HTTP endpoint (e.g. `http://localhost:8000/sse`) that the MCP client connects to.

Because they are long-lived, they need to be explicitly started before an agent session
and can be stopped when no longer needed.

---

## When to run

Run once before starting an agent session that uses any HTTP-transport server:

```bash
bash .github/skills/start-http-mcp-servers/scripts/start-http-mcp-servers.sh
```

The script is idempotent — if the container is already running it will skip it.

---

## Usage

```bash
# Start all HTTP-transport servers in the catalog
bash .github/skills/start-http-mcp-servers/scripts/start-http-mcp-servers.sh

# Start a specific server by catalog key
bash .github/skills/start-http-mcp-servers/scripts/start-http-mcp-servers.sh --server browser

# Check running / healthy status (no state changes)
bash .github/skills/start-http-mcp-servers/scripts/start-http-mcp-servers.sh --status

# Stop all HTTP-transport servers
bash .github/skills/start-http-mcp-servers/scripts/start-http-mcp-servers.sh --stop

# Stop a specific server
bash .github/skills/start-http-mcp-servers/scripts/start-http-mcp-servers.sh --stop --server browser

# Start without waiting for health check
bash .github/skills/start-http-mcp-servers/scripts/start-http-mcp-servers.sh --no-wait
```

---

## Providing secrets (env vars)

Env vars listed in the catalog's `docker.environment` list (e.g. `OPENAI_API_KEY`) are read
from the current shell environment and passed into the container.

Two ways to supply them:

**Option A — export in shell:**

```bash
export OPENAI_API_KEY=sk-...
bash .github/skills/start-http-mcp-servers/scripts/start-http-mcp-servers.sh
```

**Option B — `.env` file** (git-ignored, auto-sourced by the script):

```bash
# Create once:
echo "OPENAI_API_KEY=sk-..." >> .env

# Then just run normally:
bash .github/skills/start-http-mcp-servers/scripts/start-http-mcp-servers.sh
```

---

## Container naming convention

Containers are named `mcp-<catalog-key>`:

| Catalog key | Container name |
| ----------- | -------------- |
| `browser`   | `mcp-browser`  |

This is consistent and predictable — no `container_name` field needed in the catalog.

---

## How the MCP client connects

HTTP-transport servers are listed in `mcp.json` with a URL (not a command):

```jsonc
// VS Code (.vscode/mcp.json)
"browser": {
  "type": "sse",
  "url": "http://localhost:8000/sse"
}

// Cline (.cline/mcp.json)
"browser": {
  "url": "http://localhost:8000/sse"
}
```

The client connects to the URL directly — no wrapper script, no `npx` needed.

---

## Adding a new HTTP-transport server

When adding a new HTTP server to the catalog, use this schema (mirrors Docker Compose):

```yaml
- key: myserver
  url: https://github.com/org/myserver
  patched_dockerfile: .mcp-dockerfiles/myserver/Dockerfile
  transport: http
  sse_path: /sse # SSE endpoint path (default: /sse)
  docker:
    ports:
      - "9000:9000" # first port = MCP endpoint (host:container)
      - "5900:5900" # additional ports (e.g. VNC)
    environment:
      - API_KEY # bare name → pass value from host env or .env
      - OTHER_KEY=literal # KEY=value → pass literally
    volumes:
      - "<HOST_HOME>/.mydata:/data" # optional bind mounts
  description: ...
```

No script changes are required — the skill reads the catalog dynamically.

---

## Viewing browser session via VNC

For the `browser` server, the container also exposes port 5900 for VNC:

- **Host**: `localhost:5900`
- **Password**: `browser-use`
- Connect with any VNC viewer to watch/interact with the Chromium session.

---

## Troubleshooting

| Symptom                      | Fix                                                               |
| ---------------------------- | ----------------------------------------------------------------- |
| `Image 'mcp-...' not found`  | Run `bootstrap.sh` to build the image first                       |
| Timeout waiting for endpoint | Check container logs: `docker logs mcp-<key>`                     |
| `env var '...' is not set`   | Export the var or add it to `.env`                                |
| Port already in use          | `docker rm -f mcp-<key>` then re-run, or check what owns the port |
