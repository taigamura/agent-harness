# WSL setup script and machine install wiring

> GitHub issue #4 | Labels: ready-for-agent, P0 | https://github.com/taigamura/agent-harness/issues/4

## Parent

#3

## What to build

Create `install/wsl-setup.sh` to bootstrap a fresh WSL Ubuntu with the aider+Ollama stack. Add installation of `code`, `ralph-code`, and `ralph-code-issue` to `setup-machine.sh`. Update README to document that `wsl-setup.sh` is only needed for the aider+Ollama stack — skip it if using Claude Code only.

## Acceptance criteria

- [ ] `install/wsl-setup.sh` exists and idempotently installs git, python3, pipx, and aider-chat via pipx on a fresh WSL Ubuntu
- [ ] `setup-machine.sh` installs `bin/code`, `bin/ralph-code`, `bin/ralph-code-issue` to `~/.local/bin` using `install -m 755`, as a new step after the existing harness-init step
- [ ] README documents `install/wsl-setup.sh` as optional (aider+Ollama stack only, not needed for Claude Code only usage) and states which script to run first

## Blocked by

None - can start immediately

