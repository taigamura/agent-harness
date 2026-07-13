#!/bin/bash

set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SHIM="$ROOT/bin/codex-claude-shim"
FAKE_FIXTURE="$ROOT/tests/fixtures/fake-codex"
QUEUE_LOOP_FIXTURE="$ROOT/tests/fixtures/fake-ralph-loop"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/project/.ralph"
cp "$FAKE_FIXTURE" "$tmp_dir/bin/codex"
chmod +x "$tmp_dir/bin/codex"

export PATH="$tmp_dir/bin:$PATH"
export FAKE_CODEX_ARGV="$tmp_dir/codex.argv"
unset CODEX_MODEL FAKE_CODEX_STDOUT_FILE FAKE_CODEX_EXIT_CODE

pass_count=0
fail_count=0

pass() {
    printf 'ok - %s\n' "$1"
    pass_count=$((pass_count + 1))
}

fail() {
    printf 'not ok - %s: %s\n' "$1" "$2" >&2
    fail_count=$((fail_count + 1))
}

assert_eq() {
    local name=$1 expected=$2 actual=$3
    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "expected [$expected], got [$actual]"
    fi
}

assert_argv() {
    local name=$1
    shift
    local -a actual=()
    mapfile -d '' -t actual < "$FAKE_CODEX_ARGV"
    if [[ ${#actual[@]} -ne $# ]]; then
        fail "$name" "expected $# argv entries, got ${#actual[@]}: ${actual[*]}"
        return
    fi
    local i=0 expected
    for expected in "$@"; do
        if [[ "${actual[$i]}" != "$expected" ]]; then
            fail "$name" "argv[$i] expected [$expected], got [${actual[$i]}]"
            return
        fi
        i=$((i + 1))
    done
    pass "$name"
}

run_shim() {
    local stdout_file=$1 stderr_file=$2
    shift 2
    "$SHIM" "$@" > "$stdout_file" 2> "$stderr_file"
}

version_output=$($SHIM --version)
version_status=$?
assert_eq "--version succeeds" "0" "$version_status"
if [[ "$version_output" == "codex-claude-shim 1.0.0 (codex 0.144.2)" ]]; then
    pass "--version reports shim and Codex versions"
else
    fail "--version reports shim and Codex versions" "got [$version_output]"
fi

special_prompt=$' whitespace "quotes" \\backslash\n$(touch should-not-exist); `echo nope`\t日本語 '
run_shim "$tmp_dir/out.json" "$tmp_dir/err" \
    --output-format json --allowedTools Bash Read Write \
    --resume session-id --append-system-prompt $'system\ncontext' --effort high \
    -p "$special_prompt"
assert_eq "successful shim exits zero" "0" "$?"
assert_argv "prompt stays one exact argv entry with modern unattended flags" \
    --ask-for-approval never --sandbox workspace-write exec "$special_prompt"
if [[ ! -e "$tmp_dir/project/should-not-exist" && ! -e "$ROOT/should-not-exist" ]]; then
    pass "prompt shell metacharacters are not evaluated"
else
    fail "prompt shell metacharacters are not evaluated" "prompt content was executed"
fi

run_shim "$tmp_dir/out.json" "$tmp_dir/err" -p prompt --model gpt-5.5
assert_argv "explicit model is forwarded unchanged" \
    --ask-for-approval never --sandbox workspace-write exec --model gpt-5.5 prompt

CODEX_MODEL=environment-model run_shim "$tmp_dir/out.json" "$tmp_dir/err" \
    --model explicit-model -p prompt
assert_argv "explicit model overrides CODEX_MODEL" \
    --ask-for-approval never --sandbox workspace-write exec --model explicit-model prompt

CODEX_MODEL=environment-model run_shim "$tmp_dir/out.json" "$tmp_dir/err" -p prompt
assert_argv "CODEX_MODEL supplies the model fallback" \
    --ask-for-approval never --sandbox workspace-write exec --model environment-model prompt

unset CODEX_MODEL
run_shim "$tmp_dir/out.json" "$tmp_dir/err" -p prompt
assert_argv "model argv is omitted when unconfigured" \
    --ask-for-approval never --sandbox workspace-write exec prompt

mkdir -p "$tmp_dir/complete-ralph" "$tmp_dir/in-progress-ralph"
printf '%s\n' '- [x] finished' > "$tmp_dir/complete-ralph/fix_plan.md"
RALPH_DIR="$tmp_dir/complete-ralph" run_shim "$tmp_dir/out.json" "$tmp_dir/err" -p prompt
if jq -e '.exit_signal == true and (.result | contains("STATUS: COMPLETE"))' \
    "$tmp_dir/out.json" >/dev/null; then
    pass "completed fix plan emits Ralph completion signal"
else
    fail "completed fix plan emits Ralph completion signal" "got [$(command cat "$tmp_dir/out.json")]"
fi

printf '%s\n' '- [ ] unfinished' > "$tmp_dir/in-progress-ralph/fix_plan.md"
RALPH_DIR="$tmp_dir/in-progress-ralph" run_shim "$tmp_dir/out.json" "$tmp_dir/err" -p prompt
if jq -e '.exit_signal == false and (.result | contains("STATUS: IN_PROGRESS"))' \
    "$tmp_dir/out.json" >/dev/null; then
    pass "unchecked fix plan preserves in-progress detection"
else
    fail "unchecked fix plan preserves in-progress detection" "got [$(command cat "$tmp_dir/out.json")]"
fi

if mapfile -d '' -t last_argv < "$FAKE_CODEX_ARGV" && \
   [[ " ${last_argv[*]} " != *" --approval-mode "* ]] && \
   [[ " ${last_argv[*]} " != *" --quiet "* ]]; then
    pass "removed Codex flags are absent"
else
    fail "removed Codex flags are absent" "argv was: ${last_argv[*]}"
fi

run_shim "$tmp_dir/out.json" "$tmp_dir/err" --output-format json
missing_status=$?
assert_eq "missing -p exits non-zero" "1" "$missing_status"
missing_json=$(command cat "$tmp_dir/err")
if jq -e '.is_error == true and .result == "codex-claude-shim: no -p prompt provided"' \
    <<< "$missing_json" >/dev/null; then
    pass "missing -p emits structured error JSON"
else
    fail "missing -p emits structured error JSON" "got [$missing_json]"
fi

FAKE_CODEX_EXIT_CODE=23 run_shim "$tmp_dir/out.json" "$tmp_dir/err" -p prompt
codex_failure_status=$?
assert_eq "Codex non-zero status is preserved" "23" "$codex_failure_status"
if jq -e '.is_error == true and .exit_signal == false and (.result | contains("STATUS: IN_PROGRESS"))' \
    "$tmp_dir/out.json" >/dev/null; then
    pass "Codex failure emits Ralph-compatible error JSON"
else
    fail "Codex failure emits Ralph-compatible error JSON" "got [$(command cat "$tmp_dir/out.json")]"
fi

printf '%s' $'line 1: "quoted" and \\slashes\nline 2:\ttab and 日本語\nline 3\rcontrol' \
    > "$tmp_dir/codex.stdout"
FAKE_CODEX_STDOUT_FILE="$tmp_dir/codex.stdout" run_shim \
    "$tmp_dir/out.json" "$tmp_dir/err" -p prompt
if jq -e --rawfile expected "$tmp_dir/codex.stdout" \
    '.is_error == false and (.result | startswith($expected)) and (.result | contains("---RALPH_STATUS---"))' \
    "$tmp_dir/out.json" >/dev/null; then
    pass "complex multiline Codex output remains valid lossless JSON"
else
    fail "complex multiline Codex output remains valid lossless JSON" "got [$(command cat "$tmp_dir/out.json")]"
fi

queue_project="$tmp_dir/project"
printf '%s\n' '# Integration PRD' > "$queue_project/spec.md"
jq -n --arg path "$queue_project/spec.md" '{
    version:"1.0", created_at:"now", updated_at:"now", repository:"",
    queue:[{id:"prd-integration", source:"prd", path:$path, title:"Integration", priority:"P0", labels:[], dependencies:[], status:"pending"}]
}' > "$queue_project/.ralph/queue.json"
(
    cd "$queue_project" || exit 1
    HARNESS_DIR="$ROOT" \
    RALPH_DIR="$queue_project/.ralph" \
    RALPH_LOOP_CMD="$QUEUE_LOOP_FIXTURE" \
    FAKE_CODEX_ARGV="$FAKE_CODEX_ARGV" \
    PATH="$tmp_dir/bin:$PATH" \
    "$ROOT/ralph/ralph_loop.sh" --process-queue --halt-on-failure \
        --agent codex --model gpt-5.5
) > "$tmp_dir/queue.out" 2> "$tmp_dir/queue.err"
queue_status=$?
assert_eq "queue integration command succeeds with fake Codex" "0" "$queue_status"
assert_argv "queue path reaches Codex shim with selected model" \
    --ask-for-approval never --sandbox workspace-write exec --model gpt-5.5 \
    "queue integration prompt"

if [[ $fail_count -ne 0 ]]; then
    printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count" >&2
    exit 1
fi

printf '\n%d passed, 0 failed\n' "$pass_count"
