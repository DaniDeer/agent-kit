---
name: update-agent-framework
description: "Sync the agent framework submodule in a project. Use when: pulling latest skills from the agent framework, pushing framework improvements made inside a project back to the framework repo, updating submodule after agent framework was updated."
---

# Skill: update-agent-framework

Manage the agent framework submodule (`.agent/`) inside a project — both pulling
the latest framework changes into the project, and pushing improvements made while
working inside a project back to the agent framework repo.

---

## When to run

- New skills or fixes were committed to the agent framework repo and you want them in this project
- You improved a skill or script while working in `.agent/` and want to publish it back
- After running `agent_update-skills` while inside `.agent/` — the submodule SHA needs bumping

---

## Direction A — Pull: update framework in this project

Use this when the agent framework repo was updated elsewhere and you want this
project to pick up the latest version.

### Step 1 — Pull the latest framework

```bash
git submodule update --remote --merge
```

This fetches the latest `main` branch of the agent framework and merges it into
the local `.agent/` submodule checkout.

### Step 2 — Refresh project config files if skills changed

If the pull updated the framework's skill list (check with
`git diff .agent -- starter-kit/.clinerules`), run `agent_sync-skill-tables`
to refresh the project's `.clinerules` and `.github/copilot-instructions.md`
framework skills tables. Preserve all project-specific content.

See `.agent/.github/skills/agent_sync-skill-tables/SKILL.md`.

### Step 3 — Regenerate MCP configs

If new MCP servers were added to the catalog or existing configs changed:

```bash
bash .agent/.github/skills/mcp_generate-mcp-configs/scripts/generate-mcp-configs.sh \
  --root .agent \
  --output-root .
```

### Step 4 — (Optional) Rebuild MCP images

If the server Dockerfiles changed or new servers were added:

```bash
bash .agent/.github/skills/mcp_setup-mcp-server/scripts/bootstrap.sh --force
```

### Step 5 — Commit

```bash
git add .agent .clinerules .github/copilot-instructions.md
git commit -m "chore(agent): update agent framework submodule to $(cd .agent && git rev-parse --short HEAD)"
```

---

## Direction B — Push: publish framework improvements back upstream

Use this when you have improved a skill, fixed a script, or added a new skill
while working inside `.agent/` and want to contribute it back to the framework repo.

### Step 1 — Enter the submodule

```bash
cd .agent
```

Inside `.agent/`, all normal git operations work against the agent framework repo.

### Step 2 — Review and stage changes

```bash
git status
git diff
git add <files>
```

Follow all conventions from the `agent_update-skills` and `agent_git-commit` skills:

- Update relevant `SKILL.md` files if behaviour changed
- Run the PII check: `git ls-files | xargs grep -l "$(id -un)" 2>/dev/null || echo "clean"`
- Use Conventional Commits format

### Step 3 — Commit and push to the framework repo

```bash
git commit -m "feat(skills): <description>"
git push
```

### Step 4 — Return to the project and bump the submodule SHA

```bash
cd ..
git add .agent
git commit -m "chore(agent): update agent framework submodule to $(cd .agent && git rev-parse --short HEAD)"
```

---

## Quick reference

```bash
# Pull latest framework into this project
git submodule update --remote --merge
bash .agent/.github/skills/mcp_generate-mcp-configs/scripts/generate-mcp-configs.sh \
  --root .agent --output-root .
git add .agent && git commit -m "chore(agent): update agent framework submodule"

# Push framework changes from inside the project
cd .agent
git add <files> && git commit -m "feat(skills): ..." && git push
cd .. && git add .agent && git commit -m "chore(agent): update agent framework submodule"

# Check current submodule status
git submodule status
```

---

## Notes

- The submodule tracks the `main` branch of the agent framework repo by default
- To pin to a specific version, use `git submodule update --init` (without `--remote`)
- When inside `.agent/`, you may be on a detached HEAD — run `git checkout main` first
  if you intend to make and push commits
