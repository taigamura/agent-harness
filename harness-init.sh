#!/bin/bash
# harness-init — one-shot per-project setup for the agent-harness.
#
# Runs the two per-repo steps back-to-back:
#   1. ralph-enable  — scaffolds .ralph/PROMPT.md, fix_plan.md, AGENT.md, .ralphrc
#   2. /setup-matt-pocock-skills — interactive Claude Code skill that configures
#      the issue tracker, triage label vocabulary, and domain doc layout the
#      engineering skills read from
#
# Any flags are passed through to ralph-enable. Common ones:
#   --force         Overwrite an existing .ralph/ configuration
#   --skip-tasks    Skip task import, use default templates
#   --skip-skill    Only run ralph-enable; don't launch Claude Code
#   --help          ralph-enable help (plus a note about --skip-skill)

set -e

SKIP_SKILL=false
FILTERED_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --skip-skill)
            SKIP_SKILL=true
            ;;
        *)
            FILTERED_ARGS+=("$arg")
            ;;
    esac
done

if ! command -v ralph-enable >/dev/null 2>&1; then
    echo "Error: ralph-enable not found on PATH." >&2
    echo "Run ./setup-machine.sh from the agent-harness repo first." >&2
    exit 1
fi

echo "1/2  Running ralph-enable..."
echo ""
ralph-enable "${FILTERED_ARGS[@]}"
echo ""

if [[ "$SKIP_SKILL" == "true" ]]; then
    echo "Per-repo setup complete (skill step skipped)."
    echo "Finish it later with:  claude \"/setup-matt-pocock-skills\""
    exit 0
fi

echo "2/2  Launching Claude Code for /setup-matt-pocock-skills..."
echo ""

# Fall back gracefully if claude isn't installed or we're not on a TTY —
# the skill is interactive and needs stdin.
if ! command -v claude >/dev/null 2>&1; then
    echo "Claude Code CLI ('claude') not found on PATH — skipping."
    echo "Install it (npm install -g @anthropic-ai/claude-code), then run:"
    echo "  claude \"/setup-matt-pocock-skills\""
    exit 0
fi

if [[ ! -t 0 ]]; then
    echo "Not attached to a terminal — skipping the interactive skill step."
    echo "From an interactive shell, run:"
    echo "  claude \"/setup-matt-pocock-skills\""
    exit 0
fi

exec claude "/setup-matt-pocock-skills"
