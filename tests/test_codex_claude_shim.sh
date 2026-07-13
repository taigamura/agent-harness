#!/bin/bash

set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SHIM="$ROOT/bin/codex-claude-shim"
FAKE_FIXTURE="$ROOT/tests/fixtures/fake-codex"
FAKE_JQ_FAILURE_FIXTURE="$ROOT/tests/fixtures/fake-jq-failure"
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

# A payload larger than typical ARG_MAX values catches accidental transport
# through argv or the environment. Include difficult JSON and shell content in
# every record, then compare the decoded result byte-for-byte with the source.
# shellcheck disable=SC2016 # Metacharacters are intentional literal payload.
awk 'BEGIN {
    for (i = 0; i < 50000; i++) {
        printf "record %05d: \\\"quoted\\\" \\\\backslash $HOME $(echo nope); `false` 日本語\\n", i
    }
}' > "$tmp_dir/codex-large.stdout"
large_size=$(wc -c < "$tmp_dir/codex-large.stdout" | tr -d '[:space:]')
if [[ "$large_size" -ge 3145728 ]]; then
    pass "large response fixture is at least 3 MiB"
else
    fail "large response fixture is at least 3 MiB" "got $large_size bytes"
fi

FAKE_CODEX_STDOUT_FILE="$tmp_dir/codex-large.stdout" run_shim \
    "$tmp_dir/large.json" "$tmp_dir/large.err" -p prompt
large_status=$?
assert_eq "large Codex response exits zero" "0" "$large_status"
if jq -rj '.result' "$tmp_dir/large.json" > "$tmp_dir/large-result.txt" 2>/dev/null; then
    command cat "$tmp_dir/codex-large.stdout" > "$tmp_dir/large-expected.txt"
    large_exit_signal=$(jq -r '.exit_signal' "$tmp_dir/large.json")
    if [[ "$large_exit_signal" == "true" ]]; then
        large_status_text="COMPLETE"
    else
        large_status_text="IN_PROGRESS"
    fi
    printf '\n\n---RALPH_STATUS---\nSTATUS: %s\nEXIT_SIGNAL: %s\n---END_RALPH_STATUS---' \
        "$large_status_text" "$large_exit_signal" \
        >> "$tmp_dir/large-expected.txt"
    if cmp -s "$tmp_dir/large-expected.txt" "$tmp_dir/large-result.txt"; then
        pass "large complex Codex response survives JSON encoding byte-for-byte"
    else
        fail "large complex Codex response survives JSON encoding byte-for-byte" \
            "decoded result differs from the original payload plus status block"
    fi
else
    fail "large complex Codex response survives JSON encoding byte-for-byte" \
        "shim did not emit valid JSON: $(command cat "$tmp_dir/large.err")"
fi

mkdir -p "$tmp_dir/failing-jq-bin"
cp "$FAKE_JQ_FAILURE_FIXTURE" "$tmp_dir/failing-jq-bin/jq"
chmod +x "$tmp_dir/failing-jq-bin/jq"
PATH="$tmp_dir/failing-jq-bin:$PATH" run_shim \
    "$tmp_dir/encode-failure.out" "$tmp_dir/encode-failure.err" -p prompt
encoding_status=$?
if [[ "$encoding_status" -ne 0 ]]; then
    pass "JSON encoding failure exits non-zero"
else
    fail "JSON encoding failure exits non-zero" "shim returned success"
fi
if grep -q 'failed to encode Codex response' "$tmp_dir/encode-failure.err"; then
    pass "JSON encoding failure emits a concise diagnostic"
else
    fail "JSON encoding failure emits a concise diagnostic" \
        "got [$(command cat "$tmp_dir/encode-failure.err")]"
fi

run_analyzer_length_case() (
    local prior_kind=$1 prior_value=${2:-}
    local case_dir="$tmp_dir/analyzer-$prior_kind"
    mkdir -p "$case_dir"
    printf '%s\n' 'ordinary analyzer output' > "$case_dir/output.log"
    case "$prior_kind" in
        empty) : > "$case_dir/.last_output_length" ;;
        *) printf '%s' "$prior_value" > "$case_dir/.last_output_length" ;;
    esac
    RALPH_DIR="$case_dir"
    # shellcheck source=../ralph/lib/response_analyzer.sh
    source "$ROOT/ralph/lib/response_analyzer.sh"
    analyze_response "$case_dir/output.log" 1 "$case_dir/analysis.json" >/dev/null 2> "$case_dir/analyzer.err"
)

for analyzer_case in 'zero:0' 'empty:' 'malformed:not-a-number' 'positive:100'; do
    case_name=${analyzer_case%%:*}
    case_value=${analyzer_case#*:}
    if run_analyzer_length_case "$case_name" "$case_value"; then
        pass "analyzer accepts $case_name previous output length"
    else
        fail "analyzer accepts $case_name previous output length" \
            "analysis crashed for persisted value [$case_value]"
    fi
done

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
