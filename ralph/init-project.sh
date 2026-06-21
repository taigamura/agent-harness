#!/usr/bin/env bash
# init-project.sh — install the RALPH loop into a target project.
#
# Copies the loop scripts + prompt template into <target>/.ralph/ and scaffolds a
# fresh PROGRESS.md. Run from anywhere:
#
#   ~/dev/agent-harness/ralph/init-project.sh /path/to/project
#   ~/dev/agent-harness/ralph/init-project.sh .          # current dir
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "error: target directory '$TARGET' does not exist" >&2
  exit 1
fi

DEST="$(cd "$TARGET" && pwd)/.ralph"
mkdir -p "$DEST"

# Copy the loop scripts and the prompt template. We intentionally do NOT overwrite an
# existing prompt.md or PROGRESS.md — those are per-project and get customized.
for f in once.sh ralph.sh afk.sh; do
  cp "$SRC_DIR/$f" "$DEST/$f"
  chmod +x "$DEST/$f"
done

if [ ! -f "$DEST/prompt.md" ]; then
  cp "$SRC_DIR/prompt.md" "$DEST/prompt.md"
  echo "wrote   $DEST/prompt.md (customize this)"
else
  echo "kept    $DEST/prompt.md (already present)"
fi

if [ ! -f "$DEST/PROGRESS.md" ]; then
  cat > "$DEST/PROGRESS.md" <<'EOF'
# RALPH PROGRESS

Append-only sprint memory. One short paragraph per iteration. Delete this file when
the sprint is done.

EOF
  echo "wrote   $DEST/PROGRESS.md"
else
  echo "kept    $DEST/PROGRESS.md (already present)"
fi

echo "ready   $DEST"
echo
echo "Next:"
echo "  cd $(cd "$TARGET" && pwd)"
echo "  ./.ralph/once.sh         # one verified pass (HITL)"
echo "  ./.ralph/ralph.sh --max 50   # then go AFK"
