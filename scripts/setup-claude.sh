#!/usr/bin/env bash
# setup-claude.sh — install Claude user-level settings from this repo onto the current machine.
#
# Run once per machine:
#   cd ~/agent-harness && ./scripts/setup-claude.sh
#
# What it does:
#   1. Symlinks scripts/statusline-command.sh -> ~/.claude/statusline-command.sh
#   2. Merges declarative keys (statusLine) into ~/.claude/settings.json
#
# What it does NOT touch:
#   - ANTHROPIC_AUTH_TOKEN, ANTHROPIC_BASE_URL, mcpServers — machine-local, keep in settings.local.json
#   - Any key already in settings.json that is not listed here

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
STATUSLINE_SRC="$REPO/scripts/statusline-command.sh"
STATUSLINE_DST="$CLAUDE_DIR/statusline-command.sh"

mkdir -p "$CLAUDE_DIR"

# 1. Symlink statusline script so edits in the repo take effect immediately
if [ -L "$STATUSLINE_DST" ] && [ "$(readlink -f "$STATUSLINE_DST")" = "$STATUSLINE_SRC" ]; then
  echo "statusline-command.sh symlink already correct — skipping"
else
  ln -sfn "$STATUSLINE_SRC" "$STATUSLINE_DST"
  echo "linked $STATUSLINE_DST -> $STATUSLINE_SRC"
fi

# 2. Merge statusLine key into settings.json (create file if absent)
if [ ! -f "$SETTINGS" ]; then
  echo "{}" > "$SETTINGS"
  echo "created $SETTINGS"
fi

python3 - "$SETTINGS" <<'EOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)

cfg["statusLine"] = {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
}

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print(f"merged statusLine into {path}")
EOF

echo "setup-claude.sh complete."
