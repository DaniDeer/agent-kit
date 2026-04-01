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

## Test: Devcontainer (Option A — devcontainer feature)

_Coming soon — requires the devcontainer feature to be published to GHCR._

Until the feature is published, test the devcontainer manually by adding a
`devcontainer.json` that uses the curl `postCreateCommand`:

```json
{
	"name": "test-project",
	"image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
	"features": {
		"ghcr.io/devcontainers/features/docker-outside-of-docker:1": {}
	},
	"postCreateCommand": "curl -fsSL https://raw.githubusercontent.com/DaniDeer/agent-kit/main/starter-kit/init.sh | bash"
}
```

Open the project folder in VS Code → **Reopen in Container** → the bootstrap runs
automatically on container creation.
