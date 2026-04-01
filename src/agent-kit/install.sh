#!/usr/bin/env bash
# install.sh — Devcontainer feature: agent-kit
#
# Runs during IMAGE BUILD (as root). The workspace is NOT available yet.
# This script installs `agent-kit-init` as a binary with the agent URL baked in.
# The `postCreateCommand` lifecycle hook in devcontainer-feature.json then calls
# `agent-kit-init` once the workspace is mounted and the container is running.
#
# What agent-kit-init does (at postCreateCommand time):
#   - Adds the agent framework as a git submodule at .agent/
#   - Creates a thin .clinerules referencing .agent/.clinerules
#   - Creates a thin .github/copilot-instructions.md
#   - Updates .gitignore
#
# After that, open in VS Code and tell the agent:
#   "Run the agent_setup-in-project skill"

set -e

AGENT_URL="${AGENTURL:-https://github.com/DaniDeer/agent-kit}"
INIT_SCRIPT_URL="https://raw.githubusercontent.com/DaniDeer/agent-kit/main/starter-kit/init.sh"

echo "[agent-kit feature] Installing agent-kit-init (agent URL: $AGENT_URL)"

# Create a wrapper script with the agent URL baked in
mkdir -p /usr/local/share/agent-kit
cat > /usr/local/bin/agent-kit-init << EOF
#!/usr/bin/env bash
# agent-kit-init — installed by the agent-kit devcontainer feature
# Runs at postCreateCommand time to bootstrap the agent framework into the project.
set -e
echo "[agent-kit-init] Bootstrapping agent framework..."
curl -fsSL "$INIT_SCRIPT_URL" | bash -s -- --agent-url "$AGENT_URL"
EOF

chmod +x /usr/local/bin/agent-kit-init

echo "[agent-kit feature] agent-kit-init installed at /usr/local/bin/agent-kit-init"
echo "[agent-kit feature] It will run automatically at postCreateCommand."
