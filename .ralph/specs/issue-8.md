# ralph-code — queue.json task source

> GitHub issue #8 | Labels: ready-for-agent, P0 | https://github.com/taigamura/agent-harness/issues/8

## Parent

#3

## What to build

Wire `ralph-code` to pull tasks from `.ralph/queue.json` using ralph's existing `queue_manager.sh` functions. Each iteration: get next ready item, mark it processing, pass title+body to aider, mark complete or failed.

## Acceptance criteria

- [ ] Loop calls `get_next_issue()` to fetch the next pending, dependency-satisfied item from queue.json
- [ ] Marks item `processing` before aider runs, `completed` on success, `failed` after all retries exhausted
- [ ] Passes task as `$CONSTITUTION\n\n$title\n\n$body` (truncated at 4000 chars) to aider via `--message`
- [ ] Constitution is read from `config/ralph-prompt.md` at startup
- [ ] Logs which task source was used each iteration ("source: queue")
- [ ] Loop exits cleanly when no pending queue items remain

## Blocked by

- #7 (loop skeleton)

