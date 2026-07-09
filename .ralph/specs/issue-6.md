# code — HITL aider launcher

> GitHub issue #6 | Labels: ready-for-agent, P0 | https://github.com/taigamura/agent-harness/issues/6

## Parent

#3

## What to build

Create `bin/code`, a thin exec wrapper that launches aider with harness defaults pre-applied. Drops the user into an interactive aider session — no loop, no automation.

## Acceptance criteria

- [ ] `bin/code` exists, is executable, and passes all arguments through to aider
- [ ] Invokes aider with `--model ollama/qwen2.5-coder:14b-instruct-q4_K_M`, `--openai-api-base http://localhost:11434/v1`, and `--config $HOME/agent-harness/config/aider.conf.yml`
- [ ] Running `code somefile.py` starts an interactive aider session with that file added

## Blocked by

- #5 (needs `config/aider.conf.yml`)

