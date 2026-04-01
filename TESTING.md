# Testing

Test procedures for the agent-kit bootstrap and devcontainer setup.

---

## Test: Kick-start (Option B — curl)

Verifies that `starter-kit/init.sh` correctly bootstraps a project when run via
`curl | bash` (the recommended one-liner path).

### Prerequisites

- `git`, `curl` available on the host
- Internet access (downloads from `github.com`)

### Steps

#### 1 — Create a temporary test repo

```bash
mkdir test-project && cd test-project
git init
echo "# test-project" > README.md && git add README.md && git commit -m "init"
```

#### 2 — Run the curl bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/DaniDeer/agent-kit/main/starter-kit/init.sh | bash
```

#### 3 — Verify the results

```bash
# Directory structure — should show .agent/, .clinerules, .github/, .gitignore, .gitmodules
ls -la

# .clinerules should say "Project: test-project"
cat .clinerules

# .gitignore should have mcp.json entries
grep "mcp.json" .gitignore

# .agent submodule should be populated with agent-kit files
ls .agent/

# Git status: .agent + .gitmodules staged (A), others untracked (??)
git status --short
```

**Expected `git status` output:**

```
A  .agent
A  .gitmodules
?? .clinerules
?? .github/
?? .gitignore
```

#### 4 — Clean up

```bash
cd .. && rm -rf test-project
```

> `test-project/` is listed in `.gitignore` so it will never be accidentally committed.

---

## Test: Devcontainer feature (local — no GHCR publish required)

Tests `src/agent-kit/install.sh` directly using a local feature reference,
without publishing to GHCR first.

### Prerequisites

- VS Code with the **Dev Containers** extension installed
- Docker running on the host

### Structure

```
test-project/
  .devcontainer/
    devcontainer.json      ← references the local feature
    feature/               ← copy of src/agent-kit/ from agent-kit repo
      devcontainer-feature.json
      install.sh
  README.md
```

### Steps

#### 1 — Start from a clean test-project

```bash
mkdir test-project && cd test-project
git init
echo "# test-project" > README.md && git add README.md && git commit -m "init"
```

#### 2 — Copy the feature files

```bash
mkdir -p .devcontainer/feature
cp /path/to/agent-kit/src/agent-kit/devcontainer-feature.json .devcontainer/feature/
cp /path/to/agent-kit/src/agent-kit/install.sh .devcontainer/feature/
```

#### 3 — Create `.devcontainer/devcontainer.json`

```json
{
	"name": "test-project",
	"image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
	"features": {
		"./feature": {
			"agentUrl": "https://github.com/DaniDeer/agent-kit"
		}
	}
}
```

#### 4 — Open in VS Code and reopen in container

```
File → Open Folder → select test-project/
```

VS Code will detect `.devcontainer/devcontainer.json` and offer to **Reopen in Container**.
Accept — the container will build and install the feature.

#### 5 — Verify inside the container

`agent-kit-init` already ran at `postCreateCommand` time. Open a terminal inside
the container and check the results:

```bash
# agent-kit-init binary is installed
which agent-kit-init         # → /usr/local/bin/agent-kit-init

# All files were created by the bootstrap
ls -la                       # .agent/, .clinerules, .github/, .gitignore, .gitmodules

# .clinerules substituted the project name correctly
cat .clinerules              # "Project: test-project" at the top

# .agent submodule contains the full agent framework
ls .agent/                   # mcp-catalog.yaml, README.md, starter-kit/, src/, ...

# Git status: .agent + .gitmodules staged, others untracked
git status --short
```

**Expected `git status` output:**

```
A  .agent
A  .gitmodules
?? .clinerules
?? .devcontainer/
?? .github/
?? .gitignore
```

#### 6 — Clean up

Close the container window, then:

```bash
cd .. && rm -rf test-project
```

> **Re-running without a full teardown?** If you want to reset the container test
> without deleting the entire `test-project/`, you must clean the stale git state
> left by the previous run before rebuilding:
>
> ```bash
> cd test-project
> git rm --cached .agent .gitmodules 2>/dev/null || true
> git config --remove-section submodule..agent 2>/dev/null || true
> rm -rf .git/modules/ .agent .clinerules .github .gitignore .gitmodules
> ```
>
> Then rebuild the container. `init.sh` ≥ v1.1 also does this cleanup automatically,
> but cleaning on the host first ensures a truly fresh state.

---

## Test: Devcontainer feature (published — GHCR)

Tests the full production path via the GHCR-published feature.

### Prerequisites

- Feature published to GHCR (push tag `feature-v1.0.0` to trigger the release workflow)
- VS Code with the **Dev Containers** extension

### Steps

Use this `devcontainer.json` in any project:

```json
{
	"name": "my-project",
	"image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
	"features": {
		"ghcr.io/danideer/agent-kit/agent-kit:1": {}
	}
}
```

Open in VS Code → **Reopen in Container** → verify `agent-kit-init` is available.
