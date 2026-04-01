---
name: setup-in-project
description: "Wire the agent framework into a project as a git submodule. Use when: starting a new project that should use the agent framework, adding agent skills to an existing project, setting up devcontainer with MCP tools."
argument-hint: "GitHub URL of the agent framework repo (e.g. https://github.com/DaniDeer/agent-kit)"
---

# Skill: setup-in-project

Wire the agent framework into a project as a git submodule at `.agent/`, create
the thin `.clinerules` and `copilot-instructions.md` that reference it, configure
the devcontainer to bootstrap MCP tools on creation, and generate the initial
MCP config files at the project root.

---

## When to run

- Starting a new project that should have access to agent skills and MCP tools
- Adding the agent framework to an existing project
- Setting up a devcontainer for the first time in a project
- When a project teammate needs to onboard to the same agent setup

---

## Variables

- **AGENT_REPO**: GitHub URL of the agent framework repo
- **PROJECT_ROOT**: root of the project repo (where `.clinerules` will live)
- **SUBMODULE_PATH**: `.agent` (fixed convention)

---

## Before the agent can run this skill

This skill assumes the agent is already loaded in the project workspace. On a
**brand-new project** with no `.clinerules` yet, the agent doesn't know about any
skills.

**Use the starter-kit `init.sh` script to bootstrap first:**

```bash
# Run from the project root (before opening in VS Code):
bash path/to/agent/starter-kit/init.sh
# or if the agent repo is at the default location:
bash ~/prj/agent/starter-kit/init.sh
```

The script adds the `.agent/` submodule and copies the template `.clinerules` and
`.github/copilot-instructions.md` into the project. Then open the project in VS Code
and say:

> "Run the `agent_setup-in-project` skill"

The agent will run **Steps 2–7** below to complete the full setup.

---

## Procedure

### Step 1 — Add the agent framework as a git submodule

> **Skip if already done:** If `.agent/` already exists with content (e.g. added by
> the devcontainer feature or `curl | bash` init.sh), go straight to Step 2.
> The agent framework is already bootstrapped — no need to re-clone.

```bash
cd <PROJECT_ROOT>
git submodule add <AGENT_REPO> .agent
git submodule update --init --recursive
```

This creates `.agent/` with the full framework and a `.gitmodules` file.

### Step 2 — Create the thin `.clinerules`

> **Skip if already exists** (created by init.sh or the devcontainer feature).

The canonical template lives at `.agent/starter-kit/.clinerules`. Copy it and
substitute the project name:

```bash
sed "s/<project-name>/$(basename "$PWD")/g" .agent/starter-kit/.clinerules > .clinerules
```

> **Why copy from starter-kit?** `starter-kit/.clinerules` is the single source of
> truth for the project template — skill tables, conventions, and formatting all live
> there. Never duplicate the table manually; update it in `starter-kit/` instead.

### Step 3 — Create the thin `.github/copilot-instructions.md`

> **Skip if already exists** (created by init.sh or the devcontainer feature).

```bash
mkdir -p .github
sed "s/<project-name>/$(basename "$PWD")/g" \
  .agent/starter-kit/.github/copilot-instructions.md \
  > .github/copilot-instructions.md
```

Same principle: `.agent/starter-kit/.github/copilot-instructions.md` is the single
source of truth for the Copilot template.

### Step 4 — Update `.gitignore`

Add generated MCP config files to `.gitignore`:

```
# Agent framework — generated MCP configs (host-specific, never commit)
.vscode/mcp.json
.cline/mcp.json
```

### Step 5 — Configure `.devcontainer/devcontainer.json`

Add or update `postCreateCommand` to bootstrap the agent framework on container creation:

```json
{
	"postCreateCommand": "git submodule update --init --recursive && bash .agent/.github/skills/mcp_setup-mcp-server/scripts/bootstrap.sh && bash .agent/.github/skills/mcp_generate-mcp-configs/scripts/generate-mcp-configs.sh --root .agent --output-root ."
}
```

> **Already running in a container?** The `postCreateCommand` has no effect on the
> currently running container — that one was already bootstrapped by the devcontainer
> feature or `init.sh`. This command is essential for future container rebuilds and for
> teammates cloning the project fresh. Always commit it.

> **Note on Docker in devcontainers:** `bootstrap.sh` builds Docker images and requires
> Docker to be available. Use `"features": {"ghcr.io/devcontainers/features/docker-in-docker:2": {}}`
> or `docker-outside-of-docker` in your devcontainer to enable this.

### Step 6 — Generate initial MCP configs

Run outside the container (on the host) to generate the initial configs:

```bash
bash .agent/.github/skills/mcp_generate-mcp-configs/scripts/generate-mcp-configs.sh \
  --root .agent \
  --output-root .
```

This writes `.vscode/mcp.json` and `.cline/mcp.json` at the project root (git-ignored).

### Step 7 — Commit

```bash
git add .agent .gitmodules .clinerules .github/copilot-instructions.md \
  .devcontainer/devcontainer.json .gitignore
git commit -m "chore(agent): add agent framework as submodule

- .agent: submodule pointing to agent framework repo
- .clinerules: thin wrapper referencing .agent/.clinerules
- .github/copilot-instructions.md: thin wrapper referencing .agent
- .devcontainer/devcontainer.json: postCreateCommand bootstraps MCP tools
- .gitignore: exclude generated mcp.json files"
```

---

## Project-specific skills

Once the framework is set up, add project-local skills to `.github/skills/` using
the `project` category:

```bash
mkdir -p .github/skills/project_<name>
# Create .github/skills/project_<name>/SKILL.md using agent_create-skill
```

Then add the skill to the project's `.clinerules` table.

Project skills follow the same canonical format as framework skills — use the
`agent_create-skill` skill for guidance.

---

## Updating the framework

Use the `agent_update-agent-framework` skill to pull the latest framework changes
into the project, or to push improvements made in `.agent/` back to the framework repo.

---

## Error Handling

| Situation                                  | Action                                                                         |
| ------------------------------------------ | ------------------------------------------------------------------------------ |
| `git submodule add` fails (already exists) | Run `git submodule update --init` instead                                      |
| Bootstrap fails (Docker not available)     | Add docker-in-docker or docker-outside-of-docker devcontainer feature          |
| MCP config writes to wrong location        | Verify `--root` points to `.agent/` and `--output-root` points to project root |
| Submodule shows detached HEAD              | `cd .agent && git checkout main`                                               |
