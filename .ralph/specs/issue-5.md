# Config files and templates

> GitHub issue #5 | Labels: ready-for-agent, P0 | https://github.com/taigamura/agent-harness/issues/5

## Parent

#3

## What to build

Create the four config and template files the scripts depend on: global aider defaults, the loop constitution, a per-repo aider config template, and a Continue.dev snippet.

## Acceptance criteria

- [ ] `config/aider.conf.yml` exists with: model `ollama/qwen2.5-coder:14b-instruct-q4_K_M`, openai-api-base `http://localhost:11434/v1`, auto-test: true, auto-commits: true, dirty-commits: false, gitignore: true, stream: true, edit-format: diff, map-tokens: 4096
- [ ] `config/ralph-prompt.md` exists with a loop constitution instructing: one task per iteration, no features beyond the task, CI must stay green
- [ ] `templates/aider-project.yml` exists as a per-repo aider config template a user can copy into a new repo
- [ ] `templates/continue-config.yaml` exists with a Continue.dev snippet wiring autocomplete to `qwen2.5-coder:1.5b-base` and chat to `qwen2.5-coder:14b-instruct-q4_K_M` on `localhost:11434`

## Blocked by

None - can start immediately

