---
name: create-skill
description: "Create a new reusable skill following the canonical format. Use when: capturing a new repeatable workflow, documenting a multi-step process, standardising a discovered technique, or when the user asks to 'create a skill' or 'capture this as a skill'."
argument-hint: "Name of the new skill in kebab-case (e.g. my-new-skill)"
---

# Skill: create-skill

Create a new skill that documents a reusable workflow, process, or technique.
This skill is both the procedure for creating skills **and** the canonical template
that all skills should follow.

---

## When to run

Run this skill when:

- The user explicitly asks to create or capture a skill
- You spot a pattern during a session that is worth preserving (see **Proactive identification** below)
- An existing workflow has evolved significantly and needs a fresh document
- A multi-step process was figured out from scratch and will clearly be needed again

### Proactive identification

During any session, watch for these signals that a new skill may be warranted:

- A multi-step workflow was figured out from scratch (especially if it took >1 attempt)
- A process was done once and will clearly need to be repeated
- A non-obvious fix or workaround took meaningful effort to discover
- A new tool, API, or convention was introduced to the project
- Three or more manual steps that follow a predictable sequence

When you spot one, say:

> "This looks repeatable — want me to capture it as a skill?"

If the user agrees, run this skill.

---

## Criteria — is a skill warranted?

A skill is worth creating when **at least two** of the following are true:

| Signal                                               | Example                                        |
| ---------------------------------------------------- | ---------------------------------------------- |
| ≥ 3 sequential steps                                 | clone → patch → build → register               |
| Easy to forget or get wrong                          | Dockerfile ARG patching order                  |
| Produces artifacts that must stay in sync            | script + SKILL.md + catalog entry              |
| Took non-trivial effort to figure out the first time | Docker permission patching                     |
| Must be reproducible across sessions or machines     | bootstrap on a fresh clone                     |
| Involves files in multiple locations                 | .clinerules + copilot-instructions.md + README |

If none of the above apply, inline documentation or a code comment is sufficient.

---

## Procedure

### Step 1 — Choose a name and category

Skills are organised with a `<category>_<name>` directory naming convention.

Pick a **category** from the existing set (or introduce a new one if none fits):

| Category | Used for                                                                 |
| -------- | ------------------------------------------------------------------------ |
| `mcp`    | MCP server lifecycle (setup, update, check, perms, configs)              |
| `agent`  | Agent workflow meta-skills (skill creation, commits, session management) |
| `system` | Host-level maintenance (disk, logs, packages)                            |

Pick a **name** in `kebab-case`, all lowercase:

- Verb phrase for actions: `setup-mcp-server`, `fix-docker-perms`
- Noun for things managed: `disk-cleanup`, `git-commit`

The full directory name is `<category>_<name>` (e.g. `agent_create-skill`, `mcp_setup-mcp-server`).

### Step 2 — Create the directory structure

```bash
mkdir -p .github/skills/<category>_<name>/scripts   # only if scripts are needed
```

Skills without shell scripts (documentation-only or agent-executed procedures)
do **not** need a `scripts/` directory.

### Step 3 — Write SKILL.md using the canonical template

Copy the template below and fill in each section. See **Canonical template** further down.

Required sections:

- YAML frontmatter (`name`, `description`, `argument-hint` if applicable)
- `# Skill: <name>` heading with one-paragraph summary
- `## When to run` — trigger conditions as a bullet list
- `## Procedure` — numbered steps, each a `### Step N — Title` subsection

Optional sections (include only when applicable):

- `## Variables` — if the skill references named paths or config values
- `## Usage` — bash examples (required if the skill has scripts)
- `## Error Handling` — table of situation → action pairs
- `## Script Reference` — table of scripts and their purpose

### Step 4 — Write scripts (if needed)

If the skill involves repeatable shell operations, create scripts in `scripts/`:

```bash
# Script conventions
set -euo pipefail                        # always — fail fast
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"  # repo root (.github/skills/<dir>/scripts/ → 4 levels up)
# Use relative paths — no /home/<user>/... anywhere
# Use Docker ARG — no hardcoded UIDs, usernames, or home dirs
```

Scripts should:

- Accept `--dry-run` and `--force` flags where meaningful
- Print a clear summary table or status at the end
- Be callable standalone AND from other scripts (idempotent where possible)

### Step 5 — Update `.clinerules`

Add the new skill to the category table in `.clinerules`:

```
| `<category>` | ..., `<category>_<name>` |
```

### Step 6 — Update `.github/copilot-instructions.md`

Add a row to the skills table:

```markdown
| `<name>` | `/<name> [args]` | One-line description of what it does |
```

### Step 7 — Update `README.md`

Add the new skill to the **Structure** directory tree under `.github/skills/`:

```
    <category>_<name>/       ← skill: <one-line description>
      SKILL.md
      scripts/
        <name>.sh
```

### Step 8 — Commit

Group all new skill files + reference updates into a single commit:

```
feat(skills): add <category>_<name> skill

- .github/skills/<category>_<name>/SKILL.md: <what it documents>
- .clinerules: add <category>_<name> to skills table
- .github/copilot-instructions.md: add <name> to skills table
- README.md: add <category>_<name> to structure tree
```

---

## Canonical SKILL.md template

````markdown
---
name: <skill-name>
description: "<one-liner for agent discovery — include trigger phrases>"
argument-hint: "<optional: what argument the user provides>"
---

# Skill: <name>

<One paragraph: what this skill does and why it exists.>

---

## When to run

- <Trigger condition 1>
- <Trigger condition 2>

## Variables

- **ROOT**: repository root (the directory containing `mcp-catalog.yaml`)
- **VAR_NAME**: `$ROOT/path/to/thing` — description

## Procedure

### Step 1 — <Title>

<Explanation of what to do and why.>

```bash
bash .github/skills/<category>_<name>/scripts/<name>.sh [--flag]
```

### Step 2 — <Title>

<...>

## Usage

```bash
# Default run
bash .github/skills/<category>_<name>/scripts/<name>.sh

# With options
bash .github/skills/<category>_<name>/scripts/<name>.sh --dry-run
bash .github/skills/<category>_<name>/scripts/<name>.sh --force
```

## Error Handling

| Situation | Action       |
| --------- | ------------ |
| <error>   | <what to do> |

## Script Reference

| Script                           | Purpose       |
| -------------------------------- | ------------- |
| [<name>.sh](./scripts/<name>.sh) | <description> |
````

---

## Checklist — before committing a new skill

- [ ] Frontmatter has `name`, `description` (with trigger phrases), and `argument-hint` (if applicable)
- [ ] `## When to run` covers both explicit invocation and proactive triggers
- [ ] `## Procedure` has numbered steps with clear actions
- [ ] Scripts use `set -euo pipefail`, relative paths, no PII
- [ ] `.clinerules` updated
- [ ] `.github/copilot-instructions.md` updated
- [ ] `README.md` structure tree updated
- [ ] All changes committed together
