#!/usr/bin/env bash
# once.sh — run ONE iteration of the RALPH loop.
#
# Gathers context (open issues + last 5 commits + prompt.md + PROGRESS.md), hands it to
# the coding agent once, and expects the agent to implement one slice, keep CI green, and
# commit. Run this manually (HITL) to verify before going AFK with ralph.sh / afk.sh.
#
# Exit codes:
#   0  iteration ran
#   2  configuration/usage error
#   3  stop condition — no open issues (the loop scripts use this to stop)
#
# Env:
#   AGENT_CMD          agent CLI (default: claude). Must accept `-p "<prompt>"` headless.
#   AGENT_EXTRA_ARGS   extra args appended to the agent invocation.
#   RALPH_ISSUE_SOURCE github (default, uses `gh`) | local (reads .ralph/issues/*.md)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_CMD="${AGENT_CMD:-claude}"
ISSUE_SOURCE="${RALPH_ISSUE_SOURCE:-github}"
PROMPT_FILE="$HERE/prompt.md"
PROGRESS_FILE="$HERE/PROGRESS.md"

[ -f "$PROMPT_FILE" ] || { echo "error: missing $PROMPT_FILE" >&2; exit 2; }

gather_issues() {
  case "$ISSUE_SOURCE" in
    github)
      command -v gh >/dev/null 2>&1 || { echo "error: gh not found (set RALPH_ISSUE_SOURCE=local)" >&2; exit 2; }
      gh issue list --state open --limit 50 2>/dev/null || true
      ;;
    local)
      cat "$HERE"/issues/*.md 2>/dev/null || true
      ;;
    *)
      echo "error: unknown RALPH_ISSUE_SOURCE='$ISSUE_SOURCE' (want: github|local)" >&2
      exit 2
      ;;
  esac
}

OPEN_ISSUES="$(gather_issues)"
RECENT_COMMITS="$(git log --oneline -5 2>/dev/null || true)"
PROGRESS="$(cat "$PROGRESS_FILE" 2>/dev/null || true)"

# Stop condition: nothing left to do.
if [ -z "$(printf '%s' "$OPEN_ISSUES" | tr -d '[:space:]')" ]; then
  echo "RALPH: no open issues — nothing to do"
  exit 3
fi

INPUT="$(cat "$PROMPT_FILE")

## Open issues
${OPEN_ISSUES}

## Recent commits
${RECENT_COMMITS}

## PROGRESS.md
${PROGRESS}
"

echo "RALPH: running one iteration via '${AGENT_CMD}' (issues: ${ISSUE_SOURCE})..."
# shellcheck disable=SC2086
"$AGENT_CMD" -p "$INPUT" ${AGENT_EXTRA_ARGS:-}
