# Project: <project-name>

Uses the shared agent framework from `.agent/`.

Available framework skills (invoke via `/skill-name` in Copilot Chat):

| Skill                    | Trigger                   | What it does                                                            |
| ------------------------ | ------------------------- | ----------------------------------------------------------------------- |
| `setup-mcp-server`       | `/setup-mcp-server <url>` | Clone, patch, build, register a new MCP server                          |
| `update-mcp-servers`     | `/update-mcp-servers`     | Pull upstream changes and rebuild changed images                        |
| `fix-docker-perms`       | (called by setup)         | Patch a Dockerfile for non-root use via Docker ARG                      |
| `generate-mcp-configs`   | `/generate-mcp-configs`   | Regenerate .vscode/mcp.json and .cline/mcp.json from .example templates |
| `check-mcp-servers`      | `/check-mcp-servers`      | Read-only health check: clone, Dockerfile, image, SHA currency          |
| `start-http-mcp-servers` | `/start-http-mcp-servers` | Start persistent HTTP-transport MCP server containers before a session  |
| `update-skills`          | `/update-skills`          | Sync SKILL.md files and README to reflect session changes               |
| `create-skill`           | `/create-skill <name>`    | Create a new skill following the canonical format                       |
| `git-commit`             | `/git-commit`             | Commit with Conventional Commits format and run PII check               |
| `setup-in-project`       | `/setup-in-project`       | Wire the agent framework into a project as a git submodule              |
| `update-agent-framework` | `/update-agent-framework` | Pull latest framework into a project, or push improvements back         |
| `sync-skill-tables`      | `/sync-skill-tables`      | Propagate root skills tables to starter-kit templates and project files |
| `disk-cleanup`           | `/disk-cleanup`           | Remove unused Docker images and cloned repos                            |

Full procedures: `.agent/.github/skills/<category>_<name>/SKILL.md`
Working conventions: `.agent/.github/copilot-instructions.md`

## Project-specific skills

Project-local skills live in `.github/skills/` (using `project_<name>` directories).
Use the `agent_create-skill` skill with the `project` category to add new ones.
