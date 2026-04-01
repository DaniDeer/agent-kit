---
name: update-mcp-servers
description: "Check MCP servers for upstream git updates, rebuild their Docker images with version tags, and update the latest tag. Use when: updating MCP servers, checking for new versions, rebuilding Docker images, tagging Docker images with version, keeping MCP tools up to date."
argument-hint: "Optional: server name(s) to update (e.g. 'servers-git'). Leave empty to update all."
---

# Update MCP Servers

## When to Use

- User wants to update one or more MCP servers to their latest upstream version
- User wants to check whether any MCP server has new commits available
- User wants to rebuild Docker images and apply proper version tags

## Variables

- **ROOT**: repository root (the directory containing `mcp-catalog.yaml`)
- **MCP_SERVERS_DIR**: `$ROOT/mcp-servers` _(git-ignored — cloned repos live here)_
- **MCP_DOCKERFILES_DIR**: `$ROOT/.mcp-dockerfiles` _(checked in — patched Dockerfiles live here)_
- **VSCODE_MCP_TEMPLATE**: `$ROOT/.vscode/mcp.example.json` _(checked in — template with placeholders)_
- **CLINE_MCP_TEMPLATE**: `$ROOT/.cline/mcp.example.json` _(checked in — template with placeholders)_
- **SCRIPT**: [./scripts/update-mcp-servers.sh](./scripts/update-mcp-servers.sh)

---

## Procedure

### Step 1 — Determine scope

If the user named specific servers, pass them as arguments.
If no servers are named, update all servers under `mcp-servers/`.

### Step 2 — Run the update script

```bash
# Update all servers:
bash .github/skills/update-mcp-servers/scripts/update-mcp-servers.sh

# Update a specific server by its directory name:
bash .github/skills/update-mcp-servers/scripts/update-mcp-servers.sh servers-git
```

The script will for each server:

1. `git pull --ff-only` and compare old vs new SHA
2. **Detect if the upstream Dockerfile changed** between the two SHAs (via `git diff --name-only`)
3. If updates were found (or `--force` is passed):
   - Look for the **patched Dockerfile** at `.mcp-dockerfiles/<name>/Dockerfile` first
   - Fall back to the original in `mcp-servers/<name>/` if no patched copy exists
   - Build: `docker build --file <patched-or-original> --build-arg HOST_UID/GID/USER … --tag mcp-<name>:<sha> --tag mcp-<name>:latest`
4. If no updates were found, skip rebuild and report "already up to date"

### Step 3 — Handle upstream Dockerfile changes

If the script emits a **"Upstream Dockerfile changed"** warning, inspect the diff manually:

```bash
# Show what changed in the upstream Dockerfile
git -C mcp-servers/<name> diff <OLD_SHA> <NEW_SHA> -- '**/Dockerfile' Dockerfile
```

Then decide:

- **Minor changes** (dependency version bumps, ENV tweaks, label updates) — the existing patched Dockerfile is usually still valid. Rebuild proceeds normally; inspect the warning and confirm.
- **Structural changes** (new build stages, new base image, new `WORKDIR`/`COPY` paths) — re-apply patches:
  1. Read the new upstream Dockerfile
  2. Diff it against the patched copy: `diff mcp-servers/<name>/<subpath>/Dockerfile .mcp-dockerfiles/<name>/Dockerfile`
  3. Re-apply the `fix-docker-perms` skill: copy the new upstream Dockerfile to `.mcp-dockerfiles/<name>/Dockerfile` and re-patch it
  4. Commit the updated patched Dockerfile
  5. Rebuild with `update-mcp-servers.sh --force <name>`

> **Never modify** the original in `mcp-servers/` — always patch in `.mcp-dockerfiles/<name>/Dockerfile`.

### Step 4 — Check if `mcp.example.json` args need updating

If the update changes how the container is invoked (new required env vars, changed ports, new mount paths), update both template files and re-run bootstrap:

1. Edit `.vscode/mcp.example.json` and `.cline/mcp.example.json` with the updated `docker run` args
2. Regenerate the actual configs:
   ```bash
   bash .github/skills/setup-mcp-server/scripts/bootstrap.sh --dry-run
   ```
3. Commit the updated `.example.json` templates

---

### Step 5 — Review the script output

| Server      | Previous SHA | New SHA   | Image                     | Action     |
| ----------- | ------------ | --------- | ------------------------- | ---------- |
| servers-git | `abc1234`    | `def5678` | `mcp-servers-git:def5678` | rebuilt    |
| …           |              |           |                           | up to date |

### Step 6 — Report to the user

Summarise which servers were updated and confirm the new image tags.
Mention any servers that failed and the reason.

---

## Options / Flags

| Flag                         | Effect                                                                |
| ---------------------------- | --------------------------------------------------------------------- |
| `--force`                    | Rebuild every server image even if no new commits were pulled         |
| `--dry-run`                  | Pull updates but skip the Docker build; just report what would change |
| `<server-name>` (positional) | Limit to one or more named servers (space-separated)                  |

---

## Error Handling

| Situation                                       | Action                                                          |
| ----------------------------------------------- | --------------------------------------------------------------- |
| `git pull` fails (diverged history, no network) | Skip server, report error, continue with others                 |
| Docker build fails                              | Show last 30 lines of build log; old `:latest` tag is preserved |
| No `mcp-servers/` directory                     | Inform user — no servers have been set up yet                   |
| Server dir has no `.git` folder                 | Skip with warning (manually placed directory)                   |
