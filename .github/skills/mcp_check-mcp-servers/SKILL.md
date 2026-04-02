---
name: check-mcp-servers
description: "Read-only health check of all MCP servers. Use when: auditing server status, troubleshooting a misbehaving server, checking after a git pull, or invoke with /check-mcp-servers."
---

# Skill: check-mcp-servers

Read-only status audit of all MCP servers registered in `mcp-catalog.yaml`.
Reports whether each server's clone, patched Dockerfile, and Docker image are
present, and whether the image is current with the local git HEAD.

No network calls, no side effects — purely inspects local state.

---

## When to run

- When you want a quick health check after adding/updating servers
- Before running `bootstrap.sh` on a new machine (to see what's missing)
- When troubleshooting — a server behaving oddly may have a stale image
- After a `git pull` that might have changed the catalog

---

## Usage

```bash
bash .github/skills/check-mcp-servers/scripts/check-mcp-servers.sh
```

Optional flag:

```bash
bash check-mcp-servers.sh --root /path/to/repo   # if not called from repo root
```

---

## Output

A status table — one row per server:

```
════════════════════════════════════════════════════════════════
  MCP SERVER STATUS
════════════════════════════════════════════════════════════════
  SERVER                    CLONE    PATCH    IMAGE    SHA OK   STATUS
  ────────────────────────  ───────  ───────  ───────  ───────  ──────────
  servers-git               ✓        ✓        ✓        ✓        ✅ ready
  servers-sequentialthink   ✓        ✓        ✓        ✓        ✅ ready
════════════════════════════════════════════════════════════════
```

| Column   | What it checks                                                                       |
| -------- | ------------------------------------------------------------------------------------ |
| `CLONE`  | `mcp-servers/<name>/` directory present                                              |
| `PATCH`  | `.mcp-dockerfiles/<name>/Dockerfile` present (from `patched_dockerfile:` in catalog) |
| `IMAGE`  | Docker image `mcp-<name>:latest` exists locally                                      |
| `SHA OK` | Docker image `mcp-<name>:<git-sha>` tag exists (image is current with local HEAD)    |
| `STATUS` | `✅ ready` / `⚠️ incomplete` / `❌ not installed`                                    |

---

## Exit codes

| Code | Meaning                                        |
| ---- | ---------------------------------------------- |
| `0`  | All servers are fully ready                    |
| `1`  | One or more servers are missing or out of date |

---

## What to do when a server shows incomplete

| Symptom    | Remedy                                                              |
| ---------- | ------------------------------------------------------------------- |
| `CLONE ✗`  | Run `bootstrap.sh` or `clone-mcp-server.sh <url>`                   |
| `PATCH ✗`  | Run the `fix-docker-perms` skill to create the patched Dockerfile   |
| `IMAGE ✗`  | Run `bootstrap.sh` or `build-mcp-server.sh <url>`                   |
| `SHA OK ✗` | Image exists but is stale — run `build-mcp-server.sh <url> --force` |
