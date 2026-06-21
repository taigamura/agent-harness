#!/usr/bin/env bash
# ralph.sh — run the RALPH loop locally until done or a max-iteration cap is hit.
#
# Repeatedly calls once.sh, logging each pass to .ralph/ralph.log. Stops when once.sh
# reports the stop condition (no open issues, exit 3) or when a pass fails.
#
# Usage:  ./.ralph/ralph.sh [--max N]   (default N=100)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX=100
while [ $# -gt 0 ]; do
  case "$1" in
    --max) MAX="${2:?--max needs a number}"; shift 2 ;;
    -h|--help) echo "usage: ralph.sh [--max N]"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

LOG="$HERE/ralph.log"
i=0
while [ "$i" -lt "$MAX" ]; do
  i=$((i + 1))
  echo "=== RALPH iteration ${i}/${MAX} $(date -Iseconds 2>/dev/null || date) ===" | tee -a "$LOG"
  set +e
  "$HERE/once.sh" 2>&1 | tee -a "$LOG"
  code=${PIPESTATUS[0]}
  set -e
  case "$code" in
    0) : ;;  # ran; continue
    3) echo "RALPH: stop condition reached after ${i} iteration(s)." | tee -a "$LOG"; exit 0 ;;
    *) echo "RALPH: iteration ${i} failed (exit ${code}). Stopping for inspection." | tee -a "$LOG"; exit "$code" ;;
  esac
done
echo "RALPH: reached max iterations (${MAX})." | tee -a "$LOG"
