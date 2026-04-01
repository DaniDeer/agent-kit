---
name: git-commit
description: "Commit changes following the Conventional Commits format with a PII safety check. Use when: committing code, saving work, creating a git commit, finishing a task, end of session."
---

# Skill: git-commit

Commit staged or unstaged changes using the Conventional Commits format, with a
mandatory PII check before pushing to ensure no usernames, UIDs, or home paths
are accidentally committed.

---

## When to run

- At the end of any meaningful change (new skill, new MCP server, script update)
- When the user says "commit", "save", "push", or "let's commit this"
- After completing a multi-step workflow that changed tracked files
- Before ending a session (especially after running `update-skills`)

---

## Commit message format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

- <bullet describing what changed>
- <bullet describing what changed>
```

### Types

| Type       | When to use                                           |
| ---------- | ----------------------------------------------------- |
| `feat`     | New skill, new MCP server, new script, new feature    |
| `fix`      | Bug fix in a script or incorrect documentation        |
| `docs`     | Documentation-only change (SKILL.md, README, rules)   |
| `chore`    | Maintenance — catalog update, gitignore, config tweak |
| `refactor` | Restructuring without behaviour change                |

### Scope (optional but encouraged)

Use the skill name, directory, or area of change:

| Example scope  | Use for                                               |
| -------------- | ----------------------------------------------------- |
| `skills`       | Changes across multiple skills or the skills system   |
| `<skill-name>` | A single skill (e.g. `setup-mcp-server`)              |
| `catalog`      | `mcp-catalog.yaml` changes                            |
| `configs`      | `.vscode/mcp.example.json`, `.cline/mcp.example.json` |
| `dockerfiles`  | `.mcp-dockerfiles/` changes                           |

### Examples

```
feat(skills): add create-skill and git-commit skills

- .github/skills/create-skill/SKILL.md: canonical skill creation procedure
- .github/skills/git-commit/SKILL.md: commit format and PII check
- .clinerules: add new skills, proactive identification rule
- README.md: update structure tree
```

```
docs(setup-mcp-server): document Node.js slim Dockerfile patch pattern

- SKILL.md Step 4b: add node:*-slim base image handling
```

```
fix(generate-mcp-configs): handle spaces in HOME path
```

```
chore(catalog): add notes for github server (requires GITHUB_TOKEN)
```

---

## Procedure

### Step 1 — Stage changes

```bash
git add <files>
# or
git add -A   # all tracked changes
```

Review what will be committed:

```bash
git diff --cached --stat
```

### Step 2 — PII check (mandatory before push)

Before committing anything that will be pushed, verify no PII has leaked:

```bash
git ls-files | xargs grep -l "$(id -un)" 2>/dev/null
```

Also check for absolute home paths and UIDs:

```bash
git diff --cached | grep -E "(\/home\/[a-z]|ARG.*=.*[0-9]{4,})" || echo "clean"
```

If any matches appear in tracked/staged files:

- Replace hardcoded usernames with `<HOST_USER>` placeholders (templates) or `$(id -un)` (scripts)
- Replace absolute home paths with `<HOST_HOME>` (templates) or `$HOME` (scripts)
- Replace hardcoded UIDs/GIDs with `<HOST_UID>`/`<HOST_GID>` (templates) or `$(id -u)`/`$(id -g)` (scripts)

> **Never proceed to push if tracked files contain PII.**

### Step 3 — Commit

```bash
git commit -m "<type>(<scope>): <summary>" -m "- <change 1>
- <change 2>"
```

Or open an editor for a longer message:

```bash
git commit
```

### Step 4 — Push (when ready)

```bash
git push
```

---

## Grouping guidelines

| Situation           | What to commit together                                                                   |
| ------------------- | ----------------------------------------------------------------------------------------- |
| New skill           | SKILL.md + scripts + .clinerules + copilot-instructions.md + README.md                    |
| New MCP server      | mcp-catalog.yaml + .mcp-dockerfiles/ + .vscode/mcp.example.json + .cline/mcp.example.json |
| Script bug fix      | The script + its SKILL.md (if the documented behaviour changed)                           |
| End-of-session sync | All SKILL.md / README / catalog updates in one `docs:` commit                             |

Avoid mixing unrelated changes in a single commit.

---

## Quick reference

```bash
# Check staged content
git diff --cached --stat

# PII check
git ls-files | xargs grep -l "$(id -un)" 2>/dev/null || echo "clean"

# Commit
git commit -m "feat(skills): add <name> skill"

# Amend last commit message (before push)
git commit --amend
```
