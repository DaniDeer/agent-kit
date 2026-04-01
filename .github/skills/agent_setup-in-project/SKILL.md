---
name: setup-in-project
description: "Wire the agent framework into a project as a git submodule. Use when: starting a new project that should use the agent framework, adding agent skills to an existing project, setting up devcontainer with MCP tools."
argument-hint: "GitHub URL of the agent framework repo (e.g. https://github.com/you/agent)"
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

## Procedure

### Step 1 — Add the agent framework as a git submodule

```bash
cd <PROJECT_ROOT>
git submodule add <AGENT_REPO> .agent
git submodule update --init --recursive
```

This creates `.agent/` with the full framework and a `.gitmodules` file.

### Step 2 — Create the thin `.clinerules`

Create `.clinerules` at the project root:

```markdown
# Project: <project-name>

## Agent framework

Uses the shared agent framework from `.agent/`.
At session start, read `.agent/.clinerules` for all framework skills, MCP setup,
and conventions.

## Project-specific skills

`.github/skills/` contains project-local skills:

| Category  | Skills                                                                    |
| --------- | ------------------------------------------------------------------------- |
| `project` | _(none yet — add project-specific skills here as `project_<name>` dirs)\_ |

## Project-specific working agreements

<add project-specific notes here>
```

### Step 3 — Create the thin `.github/copilot-instructions.md`

```bash
mkdir -p .github
```

Create `.github/copilot-instructions.md`:

```markdown
# Project: <project-name>

Uses the shared agent framework from `.agent/`.
Read `.agent/.github/copilot-instructions.md` for all framework skills and conventions.

## Project-specific skills

Project-local skills live in `.github/skills/` (using `project_<name>` directories).
```

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
