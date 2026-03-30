---
name: fix-docker-perms
description: "Patch a Dockerfile to run as the host's non-root user. Runs a helper script to collect UID/GID/username, then creates a patched copy of the Dockerfile in .mcp-dockerfiles/<server-name>/ (version-controlled) without modifying the upstream clone. Works for any language or base image — not Python-specific."
argument-hint: "Path to Dockerfile (default: ./Dockerfile)"
---

# Fix Dockerfile Permissions for Non-Root Containers

## When to Use

- You want to run a container as your host user (not root)
- You want to avoid permission errors with bind mounts (e.g. `/home`)
- You want to ensure files and directories in the image are owned and readable by UID/GID
- You want to update `mcp.json` so the Docker run command uses the correct `--user` flag

## Procedure

### Step 1 — Collect host user info

Run the helper script to get the current user's identity:

```bash
bash .github/skills/fix-docker-perms/scripts/fix-docker-perms.sh
```

This outputs a JSON object with the fields you'll need:

```json
{ "uid": 1000, "gid": 1000, "user": "alice", "home": "/home/alice" }
```

### Step 2 — Read and understand the Dockerfile

Before making any changes, read the full Dockerfile from the upstream clone (at
`mcp-servers/<server-name>/<subpath>/Dockerfile`) and note:

- **Base image(s)** and any multi-stage build structure
- **WORKDIR** and all directories created or populated via `COPY`, `ADD`, or `RUN`
- Existing `USER`, `RUN useradd/adduser`, `chown`, `chmod` instructions
- The position of `ENTRYPOINT` / `CMD`
- Which directories actually exist in which stage (avoid referencing paths that don't exist)
- **Whether the build stage uses `uv`** — see the special section below

### Step 3 — Apply context-aware patches

Using the user info from Step 1 and your understanding of the Dockerfile from Step 2, apply the following patches as appropriate for this specific image.

> **Use Docker `ARG` — never hardcode usernames or UIDs in committed Dockerfiles.**
> This keeps the patched Dockerfiles safe to publish in public repositories.

1. **Declare build arguments** — add `ARG` declarations near the top of the final stage with safe defaults:

   ```dockerfile
   ARG HOST_UID=1000
   ARG HOST_GID=1000
   ARG HOST_USER=user
   ```

   `build-mcp-server.sh` passes the real values at build time via `--build-arg`.

2. **COPY/ADD ownership** — use `--chown=${HOST_USER}:${HOST_USER}` on all `COPY` / `ADD` instructions that copy files the runtime user needs to read or execute. Docker BuildKit supports ARG values in `--chown`.

3. **Create the non-root user** — add `RUN` instructions using the ARG variables:

   ```dockerfile
   RUN groupadd -g ${HOST_GID} ${HOST_USER} \
       && useradd -m -u ${HOST_UID} -g ${HOST_USER} ${HOST_USER}
   ```

   > **Note:** Do not use `&>` redirects — this is bash-only and silently fails in
   > `/bin/sh` (the default Dockerfile shell). Use POSIX-safe redirects instead:
   > `>/dev/null 2>&1`.

   Place this before `WORKDIR`, `COPY`, `USER`, and `ENTRYPOINT`/`CMD`.

4. **Set the runtime user** — add `USER ${HOST_USER}` after the `useradd` step and before `ENTRYPOINT`/`CMD`.

5. **Remove hardcoded values** — remove or replace any hardcoded UID/GID integers (e.g. `1000:1000`) or usernames with the corresponding ARG variables.

6. **chown only what exists** — if `RUN chown` instructions reference directories, ensure those directories actually exist in that build stage. Remove or guard references to non-existent paths (e.g. wrap in `if [ -d ... ]`).

7. **Instruction order** — `ENTRYPOINT`/`CMD` must come _after_ `USER`. Reorder if necessary.

### Step 4 — Create the patched Dockerfile in `.mcp-dockerfiles/`

**Do NOT modify the original Dockerfile** in `mcp-servers/<server-name>/`. That directory
is git-ignored and will be overwritten on the next clone/pull.

Instead, create a patched copy at:

```
.mcp-dockerfiles/<server-name>/Dockerfile
```

This file is **checked into git** and is the canonical patched version.
`build-mcp-server.sh` picks it up automatically via the `--file` flag, using the
original `mcp-servers/<server-name>/<subpath>/` directory as the build context.

**Steps:**

1. Create the directory: `mkdir -p .mcp-dockerfiles/<server-name>/`
2. Copy the original Dockerfile there: `cp mcp-servers/<server-name>/<subpath>/Dockerfile .mcp-dockerfiles/<server-name>/Dockerfile`
3. Apply all patches (Step 3) to `.mcp-dockerfiles/<server-name>/Dockerfile`
4. Add a header comment to the patched file documenting the source and patches applied

Example header:

```dockerfile
# Patched Dockerfile for mcp-<server-name>
# Source:  <github-url>
# Patches: non-root user via fix-docker-perms skill (uses Docker ARG — no hardcoded values)
#
# Build context: mcp-servers/<server-name>/<subpath>/
# Build command (build-mcp-server.sh passes --build-arg automatically):
#   docker build \
#     --build-arg HOST_UID=$(id -u) \
#     --build-arg HOST_GID=$(id -g) \
#     --build-arg HOST_USER=$(id -un) \
#     --file .mcp-dockerfiles/<server-name>/Dockerfile \
#     --tag  mcp-<server-name>:latest \
#     mcp-servers/<server-name>/<subpath>/
```

### Step 5 — Update mcp-catalog.yaml

Add the `patched_dockerfile:` field to the server entry in `mcp-catalog.yaml`:

```yaml
- key: <server-key>
  url: <github-url>
  patched_dockerfile: .mcp-dockerfiles/<server-name>/Dockerfile
  description: ...
```

### Step 6 — Update the mcp.json template files

**Do NOT edit** the generated `.vscode/mcp.json` or `.cline/mcp.json` — those are
git-ignored and will be overwritten by `bootstrap.sh`.

Instead, edit the **template files** (checked in):

- `.vscode/mcp.example.json`
- `.cline/mcp.example.json`

For the relevant server entry, update or add:

- `"--user", "<HOST_UID>:<HOST_GID>"` — use the `<HOST_*>` placeholder tokens, not hardcoded values
- `"-e", "HOME=<HOST_HOME>"` — use the `<HOST_HOME>` placeholder
- Any bind-mount `src=` paths using `<HOST_HOME>` instead of a hardcoded `/home/<user>`

After editing the templates, regenerate the actual config files:

```bash
bash .github/skills/setup-mcp-server/scripts/bootstrap.sh --dry-run
```

### Step 7 — Output a summary

After making all changes, summarise:

- Patched Dockerfile created at: `.mcp-dockerfiles/<server-name>/Dockerfile`
- `mcp-catalog.yaml` updated with `patched_dockerfile:` field
- Template files updated: `.vscode/mcp.example.json` and `.cline/mcp.example.json`
- Generated configs regenerated via `bootstrap.sh --dry-run`: `.vscode/mcp.json` and `.cline/mcp.json`
- What was changed and why
- Any assumptions made (e.g. which stage owns which paths)
- Remind user to commit: `.mcp-dockerfiles/<server-name>/Dockerfile`, `mcp-catalog.yaml`, `.vscode/mcp.example.json`, `.cline/mcp.example.json`

---

## Special Case: uv-managed Python Venvs

If the Dockerfile uses [`astral-sh/uv`](https://github.com/astral-sh/uv) as a
build stage, the virtual environment it creates contains symlinks like:

```
/app/.venv/bin/python -> /root/.local/share/uv/python/cpython-3.x.y-.../bin/python3.x
```

This path (`/root/.local/share/uv/python/...`) **exists only in the build stage**.
If you simply copy `/root/.local` to `/home/<user>/.local` in the final stage,
the symlink will be broken and the container will fail with:

```
exec /app/.venv/bin/<entrypoint>: no such file or directory
```

### The fix

Keep the uv-managed Python at `/root/.local` in the final stage (where the symlink
expects it), and make it world-readable so the non-root runtime user can traverse it:

```dockerfile
# Keep uv-managed Python at /root/.local (venv symlinks point there); make it world-readable
COPY --from=uv /root/.local /root/.local
RUN chmod 755 /root && chmod -R a+rX /root/.local
COPY --from=uv --chown=<user>:<user> /app/.venv /app/.venv
```

**Why this works:**

- `chmod 755 /root` — makes the `/root` directory traversable by all users (previously `700`)
- `chmod -R a+rX /root/.local` — makes all files readable and directories executable by all users
- The venv itself is owned by `<user>` so it is writable by the runtime user
- The Python interpreter symlink resolves correctly to the uv-managed CPython binary

**Do not** copy `/root/.local` to `/home/<user>/.local` for uv images — the
symlinks will point to the wrong absolute path.

---

## Special Case: Node.js Alpine Images (node:xx-alpine)

Alpine-based `node` images (e.g. `node:22-alpine`, `node:22.12-alpine`) already
include a built-in `node` user at **uid/gid 1000**. Using `addgroup -g 1000` will fail:

```
addgroup: gid '1000' in use
```

### The fix

Delete the existing `node` user and group first, then create your own:

```dockerfile
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG HOST_USER=user

RUN set -eux; \
    (deluser  node 2>/dev/null || true); \
    (delgroup node 2>/dev/null || true); \
    addgroup -g "${HOST_GID}" "${HOST_USER}"; \
    adduser  -D -u "${HOST_UID}" -G "${HOST_USER}" "${HOST_USER}"
```

Note the Alpine syntax differences vs Debian:

|              | Debian (`slim-bookworm`)               | Alpine                                 |
| ------------ | -------------------------------------- | -------------------------------------- |
| Create group | `groupadd -g <gid> <name>`             | `addgroup -g <gid> <name>`             |
| Create user  | `useradd -m -u <uid> -g <name> <name>` | `adduser -D -u <uid> -G <name> <name>` |
| Delete user  | `userdel <name>`                       | `deluser <name>`                       |
| Delete group | `groupdel <name>`                      | `delgroup <name>`                      |

The `deluser`/`delgroup` step is safe even when `HOST_GID` ≠ 1000 (the `|| true` handles
the case where neither command finds the `node` user/group to delete).

---

## Special Case: Monorepo Dockerfiles with Root-Relative COPY Paths

Some MCP servers in monorepos (e.g. `modelcontextprotocol/servers`) have Dockerfiles
designed to be built from the **monorepo root**, not the subdirectory. They use paths like:

```dockerfile
COPY src/sequentialthinking /app   # expects monorepo root as build context
COPY tsconfig.json /tsconfig.json  # expects root-level config file
```

Since `build-mcp-server.sh` uses the **subpath directory** as the build context
(e.g. `mcp-servers/servers-sequentialthinking/src/sequentialthinking/`), these paths
will fail with `not found`.

### The fix

In the patched Dockerfile, replace root-relative paths with subdirectory-relative ones:

1. **`COPY src/<subdir> /app`** → **`COPY . /app`** (`.` = the subdir, which is the build context)
2. **`COPY tsconfig.json /tsconfig.json`** — if the referenced file lives outside the
   subdir (e.g. at the monorepo root), check whether the subdir has its own copy.
   - If the subdir has its own `tsconfig.json` that extends the root one (via `"extends": "../../tsconfig.json"`),
     inline the root tsconfig content as a `RUN printf ...` step so it's available at
     the path the compiler expects:
     ```dockerfile
     RUN printf '{ "compilerOptions": { ... } }\n' > /tsconfig.json
     ```
   - Copy the content verbatim from `mcp-servers/<name>/<root>/tsconfig.json`.

Document both patches in the patched Dockerfile's header comment.

---

## Best Practices

- **Never modify the original** — always patch in `.mcp-dockerfiles/<server-name>/Dockerfile`.
- **Use Docker `ARG`, never hardcode** — usernames and UIDs must come from `ARG HOST_UID`/`HOST_GID`/`HOST_USER`. This keeps committed Dockerfiles safe for public repos.
- **Match ARG names everywhere**: `--chown=${HOST_USER}:${HOST_USER}`, `useradd ... ${HOST_USER}`, and `USER ${HOST_USER}` must all use the same ARG variable name.
- **ARG scope**: `ARG` values are only available after their declaration. Declare them before the first instruction that uses them in each stage.
- **Multi-stage builds**: only the final stage needs the ARG declarations, `useradd`, and `USER`. Earlier builder stages typically run as root — that's fine.
- **Layer efficiency**: group `useradd` with other setup `RUN` instructions if possible to avoid extra layers.
- **Idempotency guard** (POSIX-safe — avoids `&>` which is bash-only):
  ```dockerfile
  RUN id -u ${HOST_USER} >/dev/null 2>&1 || (groupadd -g ${HOST_GID} ${HOST_USER} && useradd -m -u ${HOST_UID} -g ${HOST_USER} ${HOST_USER})
  ```
- **uv images**: always keep `/root/.local` at `/root/.local` in the final stage — never move it. See the special case above.

---

## Reference Files

- [fix-docker-perms.sh](./scripts/fix-docker-perms.sh) — outputs host user info as JSON
