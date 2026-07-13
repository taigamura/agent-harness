#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"

echo "Setting up agent-harness on this machine..."
echo ""

echo "1/4  Installing Claude Code skills..."
npx skills@latest add taigamura/agent-harness

echo ""

echo "2/4  Installing Ralph CLI..."
bash "$SCRIPT_DIR/ralph/install.sh"

echo ""

echo "3/4  Installing harness-init..."
mkdir -p "$INSTALL_DIR"
install -m 755 "$SCRIPT_DIR/harness-init.sh" "$INSTALL_DIR/harness-init"
echo "Installed: $INSTALL_DIR/harness-init"

echo ""

echo "4/4  Installing bin tools (code, aider-claude-shim, codex-claude-shim)..."
mkdir -p "$INSTALL_DIR"
for bin in code aider-claude-shim codex-claude-shim; do
  install -m 755 "$SCRIPT_DIR/bin/$bin" "$INSTALL_DIR/$bin"
  echo "Installed: $INSTALL_DIR/$bin"
done

# Remove old commands that were replaced by the shim
for old in ralph-code ralph-code-issue; do
  if [[ -f "$INSTALL_DIR/$old" ]]; then
    rm "$INSTALL_DIR/$old"
    echo "Removed stale: $INSTALL_DIR/$old"
  fi
done

echo ""
echo "Machine setup complete."
echo ""
echo "Per-project setup (run once in each new repo):"
echo "  harness-init"
