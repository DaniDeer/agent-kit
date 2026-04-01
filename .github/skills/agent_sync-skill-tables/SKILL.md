---
name: sync-skill-tables
description: "Sync the skills tables across all config files. Use when: a skill is added, renamed or removed, after pulling the framework, or when starter-kit templates or project configs are out of sync with the root .clinerules."
---

# Skill: sync-skill-tables

Keep the skills tables consistent across the entire source-of-truth chain.

The root `.clinerules` and `.github/copilot-instructions.md` are the authoritative
skill registry. All downstream files must be derived from them — never edited directly
for skill list changes.

```
.clinerules  (category/skills)          ← source of truth
.github/copilot-instructions.md  (trigger table)  ← source of truth
      ↓  sync-skill-tables
starter-kit/.clinerules                 ← project template
starter-kit/.github/copilot-instructions.md       ← project template
      ↓  init.sh / agent_update-agent-framework
project/.clinerules                     ← project copy (framework section)
project/.github/copilot-instructions.md           ← project copy (framework section)
```

---

## When to run

- After adding, renaming, or removing a skill (via `agent_create-skill`)
- After pulling the latest framework into a project (via `agent_update-agent-framework`)
- After any session where the skill list changed (via `agent_update-skills`)
- When starter-kit templates or a project's config files appear out of sync

---

## Procedure

### Step 1 — Verify the root config files are up to date

Confirm the skills table in `.clinerules` and the trigger table in
`.github/copilot-instructions.md` reflect all current skills under `.github/skills/`.

If anything is missing, update root configs first — they are the source of truth.

### Step 2 — Update `starter-kit/.clinerules`

Replace the "Available framework skills" table section in `starter-kit/.clinerules`
with the updated category/skills table from root `.clinerules`.

Preserve the surrounding template structure — project-name placeholder header,
"Full skill procedures" footer line, and project-specific sections.

### Step 3 — Update `starter-kit/.github/copilot-instructions.md`

Replace the trigger table in `starter-kit/.github/copilot-instructions.md` with
the updated trigger table from root `.github/copilot-instructions.md`.

Preserve the template structure — project-name header, footer lines, and
project-specific skills section.

### Step 4 — (Optional) Update project config files

When running `agent_update-agent-framework` Direction A (pull) inside a project,
also refresh the project's own config files from the updated starter-kit templates:

- `.clinerules` — update only the "Available framework skills" table; preserve the
  project-specific skills table and working agreements sections
- `.github/copilot-instructions.md` — update only the trigger table; preserve the
  project-specific skills section

### Step 5 — Commit

Include all modified config files in the same commit as the triggering change:

```
chore(skills): sync skill tables

- starter-kit/.clinerules: update framework skills table
- starter-kit/.github/copilot-instructions.md: update trigger table
[- project/.clinerules: refresh framework skills table]
[- project/.github/copilot-instructions.md: refresh trigger table]
```

---

## Reference — table locations in each file

| File                                          | Section to update                          |
| --------------------------------------------- | ------------------------------------------ |
| `.clinerules`                                 | "Available skills" table (source of truth) |
| `.github/copilot-instructions.md`             | "Available skills" trigger table (source)  |
| `starter-kit/.clinerules`                     | "Available framework skills" table         |
| `starter-kit/.github/copilot-instructions.md` | "Available framework skills" trigger table |
| `project/.clinerules`                         | "Available framework skills" table         |
| `project/.github/copilot-instructions.md`     | "Available framework skills" trigger table |
