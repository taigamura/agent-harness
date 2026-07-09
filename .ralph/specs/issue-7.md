# ralph-code — loop skeleton

> GitHub issue #7 | Labels: ready-for-agent, P0 | https://github.com/taigamura/agent-harness/issues/7

## Parent

#3

## What to build

Create `bin/ralph-code` as a thin bash loop that drives aider against a single hardcoded task message. This slice establishes the skeleton: lib sourcing, `.ralph/` guard, one aider execution, progress.json write, and iteration cap. Task source integration (queue, fix_plan) and retry logic are added in follow-on slices.

## Acceptance criteria

- [ ] `bin/ralph-code` exists and is executable
- [ ] Sources `$HOME/agent-harness/ralph/lib/queue_manager.sh`, `lib/log_utils.sh`, and `lib/date_utils.sh` at startup
- [ ] Exits with a clear error message and points to `harness-init` if `.ralph/` directory is absent in CWD
- [ ] Executes aider with `--config $HOME/agent-harness/config/aider.conf.yml --yes` and a placeholder `--message`
- [ ] Writes `.ralph/progress.json` after each execution in ralph's schema: `{"status": "completed"|"failed", "timestamp": "..."}`
- [ ] Respects `MAX_ITERATIONS` env var (default 20); halts when the cap is reached and logs how many tasks remain

## Blocked by

- #5 (needs `config/aider.conf.yml`)

