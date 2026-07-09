# ralph-code — fix_plan.md task source fallback

> GitHub issue #9 | Labels: ready-for-agent, P0 | https://github.com/taigamura/agent-harness/issues/9

## Parent

#3

## What to build

Add fix_plan.md as a fallback task source in `ralph-code`. When queue.json has no pending items (or is absent), pull the first unchecked `- [ ]` line from `.ralph/fix_plan.md`, pass it to aider, and mark it `- [x]` on success.

## Acceptance criteria

- [ ] When queue.json has pending items, loop uses queue (not fix_plan.md)
- [ ] When queue.json is empty or absent, loop falls back to fix_plan.md
- [ ] Extracts the first unchecked `- [ ]` line as the task message
- [ ] Marks the line `- [x]` in fix_plan.md on task success
- [ ] Logs which task source was used each iteration ("source: fix_plan")
- [ ] Loop exits cleanly when both queue and fix_plan have no remaining tasks

## Blocked by

- #7 (loop skeleton)

