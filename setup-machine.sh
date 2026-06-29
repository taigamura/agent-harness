#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up agent-harness on this machine..."
echo ""

echo "1/2  Installing Claude Code skills..."
npx skills@latest add taigamura/agent-harness

echo ""

echo "2/2  Installing Ralph CLI..."
bash "$SCRIPT_DIR/ralph/install.sh"

echo ""
echo "Machine setup complete."
echo ""
echo "Per-project setup (run once in each new repo):"
echo "  ralph-enable"
echo ""
echo "Optional — only if not on GitHub or need custom triage labels:"
echo "  /setup-matt-pocock-skills"
