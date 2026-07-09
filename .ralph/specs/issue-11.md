# ralph-code-issue — GitHub issue one-shot

> GitHub issue #11 | Labels: ready-for-agent, P1 | https://github.com/taigamura/agent-harness/issues/11

## Parent

#3

## What to build

Create `bin/ralph-code-issue`, a one-shot script that fetches a GitHub issue by number, runs aider on it using the same retry and test detection logic as `ralph-code`, closes the issue on success, and posts a "human needed" comment after 3 failed retries. Commits directly to the current branch — no branching or PR.

## Acceptance criteria

- [ ] `bin/ralph-code-issue <N>` exists and is executable
- [ ] Fetches issue title and body via `gh issue view $N --json title,body`
- [ ] Passes `$CONSTITUTION\n\n$title\n\n$body` (truncated at 4000 chars) to aider, same as ralph-code queue tasks
- [ ] Uses same test detection and retry logic as ralph-code (3 attempts, test output fed back on failure)
- [ ] On success: closes issue with `gh issue close $N --comment "Closed by ralph-code-issue."`
- [ ] On 3 failures: posts `gh issue comment $N --body "ralph-code-issue failed after 3 attempts. Human needed."` and exits non-zero
- [ ] Exits with clear error if `.ralph/` is absent, pointing to `harness-init`

## Blocked by

- #8 (queue task source — shares queue mark-complete/fail pattern)
- #10 (retry + test detection — shares retry logic)

