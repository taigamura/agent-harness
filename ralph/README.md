# ralph/ — the RALPH loop

Standalone host-level scripts that run a coding agent in a loop over a task list
until it's done. This is **not** a skill — it drives the agent from *outside* a
session, the opposite layer from the things under `skills/`.

> Technique by [Geoffrey Huntley](https://ghuntley.com/ralph/) (named after Ralph
> Wiggum), popularized for Claude Code by Matt Pocock. Reference implementation:
> [`frankbria/ralph-claude-code`](https://github.com/frankbria/ralph-claude-code).

## The model

| Script | Role |
|--------|------|
| `once.sh` | **one iteration** — gather context (open issues + last 5 commits + `prompt.md` + `PROGRESS.md`), run the agent once, expect a commit. The HITL entry point: run it manually to verify before going AFK. |
| `ralph.sh` | **the loop** — run `once.sh` repeatedly with a max-iteration cap and a stop condition (no open issues), logging each pass. |
| `afk.sh` | **the AFK loop** — same as `ralph.sh` but inside a Docker sandbox for isolation. |
| `prompt.md` | the per-project loop prompt the agent receives each iteration (customize it). |
| `init-project.sh` | copy this loop into a target project (`./.ralph/`) and scaffold its `PROGRESS.md`. |

State the loop reads/writes per project:

- **Issues** — the task list. GitHub Issues (`gh`) by default; local markdown under
  `.ralph/issues/` as a fallback. Configurable via `RALPH_ISSUE_SOURCE`.
- **`PROGRESS.md`** — append-only sprint memory. The agent appends learnings each pass;
  delete it when the sprint ends.
- **`git log`** — the real session memory. Every iteration commits, so the next pass
  reconstructs context from history.

The safeguard that makes it ship working code: **whenever the loop commits, CI must
stay green.** Feedback is the speed limit.

## Why scripts live here (centrally) but run per-project

These scripts are standalone, not a plugin, so they don't install onto the agent the
way `skills/` do. Instead this directory is the **canonical source**; `init-project.sh`
copies a working copy into each target project, next to that project's issues, git
history, and `CONTEXT.md` — where the loop's state actually lives. Per-project copies
are correct here: `prompt.md` gets customized per project, and the scripts are small
and stable.

## Usage

```bash
# from inside a target project repo:
~/dev/agent-harness/ralph/init-project.sh .

# verify one pass with a human watching:
./.ralph/once.sh

# then go AFK (local loop):
./.ralph/ralph.sh --max 50

# or sandboxed:
./.ralph/afk.sh --max 50
```

Prerequisites: `git`, the agent CLI (`claude` by default; override with `AGENT_CMD`),
and — for the default issue source — the `gh` CLI authenticated. `afk.sh` also needs Docker.
