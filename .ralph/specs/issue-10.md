# ralph-code — retry logic and test detection

> GitHub issue #10 | Labels: ready-for-agent, P0 | https://github.com/taigamura/agent-harness/issues/10

## Parent

#3

## What to build

Wrap the aider execution in `ralph-code` with per-task retry logic and test-based success detection. After aider exits 0, run the configured test command to verify correctness. On failure, pass test output back to aider and retry up to 3 times.

## Acceptance criteria

- [ ] After aider exits 0, runs `$TEST_CMD` to verify success
- [ ] `TEST_CMD` is read from `.ralph/config` (KEY=VALUE format) if present; otherwise auto-detects: tries `make test`, then `pytest`; treats both failing as "no test suite" and passes through
- [ ] On test failure, captures last 50 lines of output and retries aider with message: `"Tests still failing. Fix:\n$FAILURE"`
- [ ] Retries up to 3 times per task; after 3 failures marks task failed and continues to next task
- [ ] Each retry counts toward the global `MAX_ITERATIONS` cap
- [ ] progress.json reflects the current attempt status on each write

## Blocked by

- #7 (loop skeleton)

