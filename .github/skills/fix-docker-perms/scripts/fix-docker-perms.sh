#!/usr/bin/env bash
# fix-docker-perms.sh
# Outputs host user info as JSON for the LLM agent to use when patching Dockerfiles.
#
# Usage:
#   bash fix-docker-perms.sh
#
# Output (JSON):
#   { "uid": <int>, "gid": <int>, "user": "<str>", "home": "<str>" }

set -euo pipefail

echo "{\"uid\": $(id -u), \"gid\": $(id -g), \"user\": \"$(id -un)\", \"home\": \"$HOME\"}"
