# Agent Working Agreements

#

# This file is read automatically by GitHub Copilot for every chat session in this workspace.

# Keep it accurate — it is the persistent memory that carries working conventions

# across sessions.

---

## Repository overview

This is an agent framework built around Docker-hosted MCP servers and reusable skills.
Key files to read for context at the start of any session:

- `README.md` — architecture, bootstrap instructions, conventions
- `mcp-catalog.yaml` — registered MCP servers (source of truth)
- `.github/skills/<category>_<skill>/SKILL.md` — procedure for each skill (directories follow `<category>_<skill>` naming)

Available skills (invoke via `/skill-name` in Copilot Chat):

| Skill                    | Trigger                   | What it does                                                            |
| ------------------------ | ------------------------- | ----------------------------------------------------------------------- |
| `setup-mcp-server`       | `/setup-mcp-server <url>` | Clone, patch, build, register a new MCP server                          |
| `update-mcp-servers`     | `/update-mcp-servers`     | Pull upstream changes and rebuild changed images                        |
| `fix-docker-perms`       | (called by setup)         | Patch a Dockerfile for non-root use via Docker ARG                      |
| `generate-mcp-configs`   | `/generate-mcp-configs`   | Regenerate .vscode/mcp.json and .cline/mcp.json from .example templates |
| `check-mcp-servers`      | `/check-mcp-servers`      | Read-only health check: clone, Dockerfile, image, SHA currency          |
| `update-skills`          | `/update-skills`          | Sync SKILL.md files and README to reflect session changes               |
| `disk-cleanup`           | `/disk-cleanup`           | Remove unused Docker images and cloned repos                            |
| `start-http-mcp-servers` | `/start-http-mcp-servers` | Start persistent HTTP-transport MCP server containers before a session  |
| `create-skill`           | `/create-skill <name>`    | Create a new skill following the canonical format                       |
| `git-commit`             | `/git-commit`             | Commit with Conventional Commits format and run PII check               |
| `setup-in-project`       | `/setup-in-project <url>` | Wire the agent framework into a project as a git submodule              |
| `update-agent-framework` | `/update-agent-framework` | Pull latest framework into a project, or push improvements back         |

---

## Multi-agent sync rule

This repo supports multiple agents: **Cline** reads `.clinerules` and **GitHub Copilot** reads
`.github/copilot-instructions.md`. Both files carry the same working agreements.

**Rule: any change to one must be mirrored in the other in the same commit.**

---

## Starter-kit template sync rule

`starter-kit/.clinerules` and `starter-kit/.github/copilot-instructions.md` are the
single source of truth for the skills tables that get copied into every new project.

**Rule: any time a skill is added, renamed, or removed, update both starter-kit
templates in the same commit as the skill itself.**

- `starter-kit/.clinerules` — category/skills table (Cline format)
- `starter-kit/.github/copilot-instructions.md` — trigger table (Copilot format)
- The two starter-kit files must stay in sync with each other AND with the root
  `.clinerules` / `.github/copilot-instructions.md` skill lists.

---

## Multi-agent sync rule (continued)

The two files are allowed to differ only in agent-specific formatting:

- `.clinerules` uses a category/skills table
- `.github/copilot-instructions.md` uses a trigger-based table for Copilot Chat

Everything else — PII rules, skill lists, proactive identification triggers, MCP
checklist — must be identical.

---

## Skills are living documents

Skills improve over time as we discover new edge cases and conventions.

**The rule: fix → codify → commit.**

- When a script behaviour changes, update the corresponding `SKILL.md` in the same commit.
- When a new edge case is handled (e.g. a new Dockerfile base image pattern),
  add it to the relevant `SKILL.md` so the next session starts with that knowledge.
- When a workflow changes substantially, update `README.md`.

---

## Proactive skill identification

During any session, watch for patterns that are worth capturing as a reusable skill:

- A multi-step workflow that was figured out from scratch
- A process that was done, or will clearly need to be repeated
- A non-obvious fix or workaround that took meaningful effort to discover
- A new tool, API, or convention introduced to the project

When you spot one, proactively say:

> "This looks repeatable — want me to capture it as a skill?"

If the user agrees, follow the `agent_create-skill` skill (`.github/skills/agent_create-skill/SKILL.md`).

---

## End-of-session skill sync

After any session where skills, scripts, or conventions changed, offer to run:

> "Update the skills to reflect what we did today."

This triggers the `agent_update-skills` skill — see `.github/skills/agent_update-skills/SKILL.md`.

---

## MCP server install checklist

Every new MCP server must end with all of the following committed:

1. Entry in `mcp-catalog.yaml` — `key`, `url`, `patched_dockerfile`, `description`, `notes`
2. Patched Dockerfile at `.mcp-dockerfiles/<name>/Dockerfile` (uses Docker ARG, no hardcoded values)
3. `.vscode/mcp.example.json` updated with the new server entry
4. `.cline/mcp.example.json` updated with the new server entry
5. If the skill scripts changed to handle this server type, update the SKILL.md too

---

## No PII in commits

- Generated `.vscode/mcp.json` and `.cline/mcp.json` are git-ignored — never commit them.
- Patched Dockerfiles must use `ARG HOST_UID`, `ARG HOST_GID`, `ARG HOST_USER` — no hardcoded
  usernames, UIDs, or home directory paths.
- SKILL.md and script files must use relative paths, not absolute `/home/<user>/...` paths.
- Before committing, run this dynamic PII check to catch the current user's real username and
  home path (not a placeholder):

  ```bash
  git diff --cached --name-only | xargs grep -rn "$(id -un)" 2>/dev/null && echo "⚠ username found" || true
  git diff --cached --name-only | xargs grep -rn "$HOME" 2>/dev/null && echo "⚠ home path found" || true
  ```
