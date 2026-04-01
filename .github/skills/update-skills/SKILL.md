---
name: update-skills
description: "Sync all SKILL.md files, README.md, copilot-instructions.md, .clinerules, and mcp-catalog.yaml to reflect session changes. Use when: end of session, after changing scripts or conventions, after adding a new skill or MCP server, when asked to 'update the skills'."
---

# Skill: update-skills

Sync all SKILL.md files, README.md, and mcp-catalog.yaml to accurately reflect
what changed during the current or most recent session. This skill is the mechanism
for continuous improvement — run it at the end of any session where skills, scripts,
or conventions changed.

---

## When to run

- After installing a new MCP server (especially if fix-docker-perms needed new logic)
- After changing a script's flags, output format, or file conventions
- After discovering and handling a new edge case
- After any workflow change that isn't yet documented
- Proactively offered at end of session; also triggered explicitly:

  > "Update the skills to reflect what we did today."

---

## What to review

Go through each item below and check whether it accurately reflects the current state.
Update any file that is out of date, then commit everything together.

### 1. `.github/skills/setup-mcp-server/SKILL.md`

- Does it describe the current clone + patch + build flow?
- Are all script flags documented (`--force`, `--dry-run`)?
- Does it cover any new server types encountered (Node.js, Go, Alpine, npx, uvx)?
- Is the bootstrap.sh workflow accurate?

### 2. `.github/skills/fix-docker-perms/SKILL.md`

- Does it document all Dockerfile base image patterns currently handled?
- If a new base image type was patched this session, is the new pattern described?

### 3. `.github/skills/update-mcp-servers/SKILL.md`

- Does it describe the current pull + rebuild flow?
- Are flags documented?

### 4. `.github/skills/disk-cleanup/SKILL.md`

- Does it reflect what gets cleaned and what is preserved?

### 5. `README.md`

- Does the **Structure** tree reflect all files and directories?
- Does the **What is checked in vs. git-ignored** table reflect current state?
- Are all workflows (bootstrap, add server, update server) accurate?
- Does the **Requirements** section list all needed tools?

### 6. `mcp-catalog.yaml`

- Does every installed server have an entry?
- Is the `notes:` field accurate for each server (env vars, bind mounts, special flags)?
- Are `patched_dockerfile:` paths correct?

### 7. `.clinerules` and `.github/copilot-instructions.md`

- Do the skill tables and working agreements reflect the current set of skills?
- If a new skill was added, is it listed?

---

## How to commit

Group all SKILL.md / README / catalog updates into a single commit:

```
docs: sync skills to reflect session changes

<bullet list of what changed, e.g.:>
- fix-docker-perms/SKILL.md: document Node.js slim Dockerfile patch pattern
- README.md: add disk-cleanup to skills table
- mcp-catalog.yaml: add notes for github server (requires GITHUB_TOKEN env var)
```

---

## Fast path — nothing changed

If you review all items above and nothing is out of date, the skill is done.
No commit needed. Say: "Skills are already up to date."
