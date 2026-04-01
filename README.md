# My Agent Framework

A VS Code-based AI agent framework with Docker-hosted MCP servers and reusable agent skills.

> **README contract**: This file documents the overall architecture and the key
> workflows. When a workflow changes substantially (new flags, new files, changed
> naming conventions) — update this file as part of that change so future agent
> sessions start with accurate context.

---

## Kick-start — add agent-kit to any project

### Option A — Devcontainer feature (recommended)

Add to your project's `devcontainer.json` — everything runs automatically when the container starts:

```json
{
	"features": {
		"ghcr.io/danideer/agent-kit/agent-kit:1": {}
	}
}
```

The feature installs `agent-kit-init` during image build and runs it at `postCreateCommand` time. No extra steps.

> **Publishing:** push tag `feature-v1.0.0` to trigger the release workflow and publish to GHCR.

### Option B — One-liner (no clone, no feature install)

From your **project root**:

```bash
# Via curl (fresh, no clone):
curl -fsSL https://raw.githubusercontent.com/DaniDeer/agent-kit/main/starter-kit/init.sh | bash

# Or from a local clone:
bash ~/prj/agent-kit/starter-kit/init.sh

# Or in devcontainer.json postCreateCommand:
# "postCreateCommand": "curl -fsSL https://raw.githubusercontent.com/DaniDeer/agent-kit/main/starter-kit/init.sh | bash"
```

### What gets created

| File / Directory                  | Purpose                                                     |
| --------------------------------- | ----------------------------------------------------------- |
| `.agent/`                         | Agent framework as a git submodule (all skills + MCP tools) |
| `.clinerules`                     | Cline reads `.agent/.clinerules` at every session start     |
| `.github/copilot-instructions.md` | Copilot reads `.agent/` at every session start              |
| `.gitignore`                      | Updated — excludes generated `mcp.json` files               |

Then open the project in VS Code and tell the agent:

> "Run the `agent_setup-in-project` skill"

The agent generates MCP configs, configures the devcontainer, and commits everything.

> **Want to verify first?** See [TESTING.md](TESTING.md) for a step-by-step test procedure.

### Skills table hierarchy

The skills list is maintained through a source-of-truth chain so it only needs
to be updated in one place:

```
.clinerules / .github/copilot-instructions.md   ← source of truth (this repo)
      ↓  agent_sync-skill-tables
starter-kit/.clinerules / .github/copilot-instructions.md  ← project templates
      ↓  init.sh / agent_update-agent-framework
project/.clinerules / .github/copilot-instructions.md      ← project copies
```

After adding or removing a skill, run `agent_sync-skill-tables` to propagate the
change to all downstream files automatically.

### Day-to-day in a project

| Goal                             | How                                                              |
| -------------------------------- | ---------------------------------------------------------------- |
| Use a framework skill            | Just ask — agent reads `.agent/.clinerules`                      |
| Add a project-specific skill     | "Create a skill called `<name>`" — agent uses `project` category |
| Pull latest framework updates    | "Run `agent_update-agent-framework`"                             |
| Push framework improvements back | "Run `agent_update-agent-framework`" (direction B)               |

---

## Structure

```
.github/
  copilot-instructions.md    ← Copilot always-on working agreements [checked in]
  skills/
    mcp_setup-mcp-server/        ← skill: add a new MCP server from a GitHub URL
      SKILL.md
      scripts/
        setup-mcp-server.sh  ← clone repo, build Docker image (sha + latest tags)
        bootstrap.sh         ← install every server from the catalog at once
    mcp_update-mcp-servers/      ← skill: pull upstream changes, rebuild images
      SKILL.md
      scripts/
        update-mcp-servers.sh
    mcp_fix-docker-perms/        ← skill: patch Dockerfiles for non-root container use
      SKILL.md
      scripts/
        fix-docker-perms.sh
    mcp_generate-mcp-configs/    ← skill: regenerate .vscode/mcp.json + .cline/mcp.json
      SKILL.md
      scripts/
        generate-mcp-configs.sh
    mcp_check-mcp-servers/       ← skill: read-only health check for all catalog servers
      SKILL.md
      scripts/
        check-mcp-servers.sh
    mcp_start-http-mcp-servers/  ← skill: start persistent HTTP-transport MCP server containers
      SKILL.md
      scripts/
        start-http-mcp-servers.sh
    agent_create-skill/          ← skill: create a new skill following the canonical format
      SKILL.md
    agent_update-skills/         ← skill: sync SKILL.md files at end of session
      SKILL.md
    agent_git-commit/            ← skill: commit with Conventional Commits format + PII check
      SKILL.md
    agent_setup-in-project/      ← skill: wire agent framework into a project as a git submodule
      SKILL.md
    agent_update-agent-framework/ ← skill: pull/push agent framework submodule in a project
      SKILL.md
    agent_sync-skill-tables/     ← skill: propagate skills tables from root to starter-kit + project
      SKILL.md
    system_disk-cleanup/         ← skill: remove unused Docker images and cloned repos
      SKILL.md
.mcp-dockerfiles/            ← patched Dockerfiles (one per server) [checked in]
  servers-git/
    Dockerfile
.vscode/
  mcp.example.json           ← VS Code config template      [checked in]
  settings.json              ← associates *.example.json with JSONC [checked in]
  mcp.json                   ← VS Code MCP config (generated, git-ignored)
.cline/
  mcp.example.json           ← Cline config template        [checked in]
  mcp.json                   ← Cline MCP config (generated, git-ignored)
mcp-catalog.yaml             ← list of all MCP servers      [checked in]
mcp-servers/                 ← cloned repos & build context [git-ignored]
src/
  agent-kit/                 ← devcontainer feature: installs agent-kit-init during image build
    devcontainer-feature.json
    install.sh
starter-kit/                 ← one-shot bootstrap for using this framework in a project
  init.sh                    ← run from a project root to add .agent/ submodule + template files
  .clinerules                ← template: thin project .clinerules referencing .agent
  .github/
    copilot-instructions.md  ← template: thin project copilot-instructions referencing .agent
.clinerules                  ← Cline always-on working agreements  [checked in]
.gitignore
README.md
```

---

## What is checked in vs. git-ignored

| Path                       | In git | Notes                                                                       |
| -------------------------- | ------ | --------------------------------------------------------------------------- |
| `mcp-catalog.yaml`         | ✅     | Source of truth for which servers exist                                     |
| `.vscode/mcp.example.json` | ✅     | VS Code config template — uses `<HOST_*>` placeholders, no PII              |
| `.cline/mcp.example.json`  | ✅     | Cline config template — uses `<HOST_*>` placeholders, no PII                |
| `.mcp-dockerfiles/*/`      | ✅     | Patched Dockerfiles using Docker ARG — no hardcoded values                  |
| `.github/skills/`          | ✅     | All skill definitions and scripts                                           |
| `.vscode/mcp.json`         | ❌     | Generated by `bootstrap.sh` from `.example` — contains host-specific values |
| `.cline/mcp.json`          | ❌     | Generated by `bootstrap.sh` from `.example` — contains host-specific values |
| `mcp-servers/*/`           | ❌     | Cloned repos — rebuilt by `bootstrap.sh`                                    |
| Docker images              | ❌     | Rebuilt by `bootstrap.sh` or `update-mcp-servers.sh`                        |

---

## Bootstrap (new machine / fresh clone)

```bash
bash .github/skills/mcp_setup-mcp-server/scripts/bootstrap.sh
```

Reads every `url:` entry from `mcp-catalog.yaml` and calls `setup-mcp-server.sh`
for each one. Patched Dockerfiles are already committed in `.mcp-dockerfiles/` and
are picked up automatically — no patching step needed.

Flags:

- `--dry-run` — report only, no clone/build
- `--force` — rebuild even if images already exist

---

## Adding an MCP Server

1. Open Copilot Chat and type:

   ```
   /setup-mcp-server https://github.com/org/some-mcp-server
   ```

   Monorepo subdirectory URLs work too (e.g. `.../tree/main/src/git`).

2. The agent will:
   - Clone the repo (sparse if a subdirectory) into `mcp-servers/<name>/`
   - Inspect the Dockerfile and apply non-root patches via `fix-docker-perms`
   - **Create a patched copy** at `.mcp-dockerfiles/<name>/Dockerfile` _(checked in)_
   - Build the Docker image tagged `mcp-<name>:<sha>` **and** `mcp-<name>:latest`
   - Update `.vscode/mcp.json` and `.cline/mcp.json` with the correct `docker run` entry
   - Add an entry to `mcp-catalog.yaml` (including a `patched_dockerfile:` field)

3. Commit `mcp-catalog.yaml`, `.vscode/mcp.example.json`, `.cline/mcp.example.json`, and `.mcp-dockerfiles/<name>/Dockerfile`.

---

## Updating MCP Servers

```bash
# Check all servers for upstream changes and rebuild if needed:
/update-mcp-servers

# Or directly:
bash .github/skills/mcp_update-mcp-servers/scripts/update-mcp-servers.sh
```

- Pulls upstream commits with `git fetch --depth=1 + reset --hard`
- Reapplies sparse-checkout for monorepo subdirectory servers after each pull
- Rebuilds only servers that have new commits (unless `--force`)
- Tags each new image as `mcp-<name>:<sha>` **and** `mcp-<name>:latest`
- Prints a summary table: server / old SHA / new SHA / image / action

Flags: `--force` (rebuild all regardless of changes), `--dry-run` (pull only, no build).

---

## MCP Server Catalog

All registered servers are listed in [mcp-catalog.yaml](mcp-catalog.yaml).
Each entry includes:

- `key` — identifier used in `mcp.json`
- `url` — GitHub URL (may point to a monorepo subdirectory)
- `patched_dockerfile` — path to the patched Dockerfile in `.mcp-dockerfiles/`
- `description` — short description
- `notes` — any env vars, bind mounts, or special config

## MCP Server Configuration

All servers are configured in [.vscode/mcp.json](.vscode/mcp.json) (VS Code / Copilot)
and [.cline/mcp.json](.cline/mcp.json) (Cline).
Most use `stdio` transport via `docker run --rm -i <image>:latest`.
Servers requiring secrets use VS Code input variables (`${input:KEY}`) so
credentials are never stored in plain text.

## Patched Dockerfiles

Upstream Dockerfiles are **never modified** in `mcp-servers/` (git-ignored).
Instead, patched copies live in `.mcp-dockerfiles/<server-name>/Dockerfile` (checked in).
`build-mcp-server.sh` uses the patched copy automatically via `docker build --file`.
This allows the patched Dockerfiles to be version-controlled and reproduced on any machine.

## Requirements

- Docker (running on the host)
- `git`
- VS Code with the GitHub Copilot extension
