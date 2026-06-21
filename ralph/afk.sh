#!/usr/bin/env bash
# afk.sh — run the RALPH loop inside a Docker sandbox for isolation.
#
# Mounts the project at /work and runs ralph.sh inside the container, passing through
# the agent config. The image MUST contain your agent CLI (e.g. claude) and its auth —
# set RALPH_IMAGE to a prepared image. Args (e.g. --max N) are forwarded to ralph.sh.
#
# Usage:  ./.ralph/afk.sh [--max N]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HERE/.." && pwd)"
IMAGE="${RALPH_IMAGE:-agent-harness/ralph:latest}"

command -v docker >/dev/null 2>&1 || { echo "error: docker not found" >&2; exit 2; }

exec docker run --rm -it \
  -v "$PROJECT_ROOT":/work -w /work \
  -e AGENT_CMD -e AGENT_EXTRA_ARGS -e RALPH_ISSUE_SOURCE -e GH_TOKEN \
  "$IMAGE" bash -lc "./.ralph/ralph.sh $*"
