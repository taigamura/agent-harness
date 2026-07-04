#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"

echo "Setting up agent-harness on this machine..."
echo ""

echo "1/3  Installing Claude Code skills..."
npx skills@latest add taigamura/agent-harness

echo ""

echo "2/3  Installing Ralph CLI..."
bash "$SCRIPT_DIR/ralph/install.sh"

echo ""

echo "3/3  Installing harness-init..."
mkdir -p "$INSTALL_DIR"
install -m 755 "$SCRIPT_DIR/harness-init.sh" "$INSTALL_DIR/harness-init"
echo "Installed: $INSTALL_DIR/harness-init"

echo ""
echo "Machine setup complete."
echo ""
echo "Per-project setup (run once in each new repo):"
echo "  harness-init"
