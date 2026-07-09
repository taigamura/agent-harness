---
type: concept
title: "agent-harness — Design Doc"
created: 2026-07-09
updated: 2026-07-09
tags:
  - harness-engineering
  - agentic-ai
  - workflow
  - ai-coding
  - local-inference
  - aider
  - ralph
  - design-doc
status: draft
complexity: intermediate
domain: ai-tools
question: "What's the minimum-viable coding stack on WSL that pairs aider + qwen2.5-coder with a ralph loop, without over-engineering it into a chat harness?"
aliases:
  - "agent-harness"
  - "WSL coding stack"
  - "aider + ralph stack"
related:
  - "[[Local LLM Setup for Coding]]"
  - "[[chat-harness — Design Doc]]"
  - "[[RALPH — Autonomous Coding Loop]]"
  - "[[agent-harness — Workflow Setup and Project Bootstrap]]"
  - "[[sap-harness — Design Doc]]"
  - "[[Vibe Coding — AI Coding Evolution and Cline]]"
sources:
  - "Existing WSL repo at ~/agent-harness/ — already has ralph subtree"
  - "[[Local LLM Setup for Coding]] — Aider capability table (lines 249-328)"
  - "[[RALPH — Autonomous Coding Loop]] — loop mechanics"
  - "Design conversation 2026-07-09"
---

# agent-harness — Design Doc

**Status:** Design doc, opened 2026-07-09. The `~/agent-harness/` repo already exists in WSL with a ralph subtree at `~/agent-harness/ralph/`. This doc formalizes what the OSS coding stack should look like on top of that starting point.

**One-sentence pitch:** A WSL-hosted coding stack that pairs aider (for HITL edits) with ralph (for AFK loops), both pointed at local qwen2.5-coder over Ollama — deliberately narrow, no MCP, no skills, no chat.

---

## Motivation

The AI workflows split cleanly:

| Workflow | Stack |
|---|---|
| **Coding** (this doc) | Aider + ralph + qwen2.5-coder — repo-scoped, tool-poor, deterministic |
| **Chat / vault** | [[chat-harness — Design Doc]] — MCP-heavy, skill-driven, Qwen instruct |

Trying to build one harness that does both was the initial instinct. Rejected on 2026-07-09 after grilling — the tools are different (aider vs custom Python agent), the model is different (coder vs instruct), the tool surface is different (files+shell+git vs MCP), and the runtime is different (WSL-primary coding vs Windows-launched chat).

**agent-harness stays narrow on purpose.** Coding = code + tests + git + occasional web reference. That's aider's exact scope. No need to reinvent it.

---

## Design principle

**Reuse the OSS coding tools that already exist; add the thinnest possible glue.**

- Aider handles: file edits, repo map, /add, /run, /diff, auto-commit, auto-test, git integration
- Ralph handles: the outer loop, task list, iteration cap, sandbox
- The user handles: the prompt, the review, the merge

The harness's job is to make invocation frictionless — sensible defaults, per-repo config templates, a couple of wrapper scripts. Not to build a new agent runtime.

If a coding task needs MCP, sub-agents, or vault access, that's the wrong tool. Use Claude Code (or chat-harness for research context). Coding-mode is deliberately dumb.

---

## Architecture

```
┌─ Windows host ────────────────────────────────────────────────┐
│                                                                │
│  Ollama service (native) ──── localhost:11434                  │
│    ├─ qwen2.5-coder:14b-instruct-q4_K_M   (chat/edit)          │
│    └─ qwen2.5-coder:1.5b-base             (VS Code Continue.dev│
│                                            autocomplete)       │
│                                                                │
│  VS Code (Windows) + WSL Remote extension                      │
│    └─ Continue.dev extension → localhost:11434                 │
│         (autocomplete + inline edit, editor-side)              │
│                                                                │
└──────────────────┬─────────────────────────────────────────────┘
                   │  (WSL2 mirrored networking → Windows Ollama)
┌──────────────────┴─────────────────────────────────────────────┐
│  WSL2 (Ubuntu)                                                  │
│                                                                  │
│  ~/agent-harness/                                                │
│    ├─ ralph/                    ← existing (frankbria-ralph)     │
│    │    ├─ ralph.sh                                              │
│    │    ├─ afk.sh                                                │
│    │    ├─ lib/                                                  │
│    │    └─ ...                                                   │
│    ├─ config/                                                    │
│    │    ├─ aider.conf.yml       ← default aider settings         │
│    │    └─ ralph-prompt.md      ← default ralph loop prompt      │
│    ├─ bin/                                                       │
│    │    ├─ code                 ← aider wrapper, sane defaults   │
│    │    ├─ code-ralph           ← ralph loop wrapper             │
│    │    └─ code-issue           ← ralph-via-GitHub-Issues        │
│    ├─ templates/                                                 │
│    │    ├─ ralph-scaffold/      ← files copied into new repos    │
│    │    │    ├─ PROGRESS.md                                      │
│    │    │    ├─ TASKS.md                                         │
│    │    │    └─ .ralph/                                          │
│    │    └─ aider-project.yml    ← per-repo aider config template │
│    ├─ install/                                                   │
│    │    └─ wsl-setup.sh         ← apt: git, python; pip: aider   │
│    └─ README.md                                                  │
│                                                                  │
│  Target repos (anywhere in WSL)                                  │
│    ~/code/<project>/                                             │
│      ├─ (whatever the project is)                                │
│      ├─ .aider.conf.yml   ← from template, optional              │
│      └─ .ralph/           ← from scaffold when ralph is used     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Layer ownership matrix

| Concern | Owner | Why |
|---|---|---|
| Model inference | Windows Ollama | Same as chat-harness — GPU-native |
| Editor autocomplete | Continue.dev (VS Code, Windows) | Editor-side; not part of the WSL harness |
| Editor chat/inline-edit | Continue.dev OR aider — user choice per session | Continue for quick, aider for repo-scoped |
| File edits (repo-scoped) | Aider | Its native strength |
| Repo map | Aider | Better than anything we'd build |
| Shell command execution | Aider `/run` | Native |
| Git commits | Aider (auto) | Better than any wrapper |
| Test loop | Aider `--auto-test --test-cmd` | Native |
| Loop control (AFK) | ralph.sh | Deterministic bash state machine |
| Iteration cap | ralph.sh | Circuit breaker; prevents runaway |
| Task list | `TASKS.md` per repo | Simple; human-editable |
| Iteration memory | `PROGRESS.md` per repo | Ralph's append-only sprint memory |
| Sandbox | Docker (via ralph) or nothing (HITL) | Only needed for AFK |
| GitHub issue integration | `code-issue` wrapper (gh CLI + aider) | ~30 LOC bash |
| Config defaults | `~/agent-harness/config/` | One place to tune |
| Per-project overrides | `.aider.conf.yml` in target repo | Aider's native mechanism |

---

## Key design decisions

### 1. No custom Python agent — aider is the agent

Aider is a mature OSS coding agent with a repo map, file management, git awareness, and test-loop feedback. Writing our own would duplicate 10k+ LOC of proven code to gain nothing. Aider handles the entire "agent" surface for coding.

The harness's Python content is zero. Everything is bash, YAML config, and markdown templates.

### 2. Ralph stays a bash loop, not a Python module

The existing `~/agent-harness/ralph/` (frankbria implementation) is fine. It's a state machine in bash — deterministic, no drift, easy to debug. This doc does not touch it.

What this doc adds is `bin/code-ralph`, a thin wrapper that:
1. Ensures target repo has `.ralph/` scaffold (copy from `templates/ralph-scaffold/` if missing)
2. Invokes `~/agent-harness/ralph/ralph.sh` with correct env vars
3. Sets `AGENT_CMD="aider --model ollama/qwen2.5-coder:14b-instruct-q4_K_M --auto-test --yes"`

### 3. Two invocation shapes: `code` and `code-ralph`

- `code [file1 file2 ...]` — HITL. Starts aider with sane defaults, drops you at the aider prompt. Same session ergonomics as `aider` but with `--model`, `--auto-test`, and log path pre-configured.
- `code-ralph` — AFK. Reads `TASKS.md` in CWD, runs ralph loop, iterates until tasks are done or iteration cap hit.

A third: `code-issue <N>` — pulls GitHub issue N, feeds to aider, opens a PR. The wrapper sketched at `Local LLM Setup for Coding.md:280-311`.

### 4. Continue.dev is separate, but documented here

The VS Code Continue.dev extension provides editor-inline autocomplete + chat, using the same Ollama backend but a different model (`qwen2.5-coder:1.5b-base` for autocomplete, `14b` for chat). It is an editor extension, not part of `agent-harness`, but the harness's install script emits a `continue-config.yaml` snippet the user pastes into Continue's config.

Rationale for including: someone reproducing this stack on a new machine expects the "coding setup" to include autocomplete. Documenting it here means one canonical setup doc.

### 5. No MCP

Aider does not speak MCP. Adding MCP to aider is a fork-scale project. The coding workflow doesn't need it — file edits, git, tests, shell all exist as aider primitives.

If a coding session needs web search or docs, the flow is:
1. Ask [[chat-harness — Design Doc|chat-harness]] to research + write to vault
2. `aider /add /mnt/c/.../wiki/concepts/<page>.md` to bring it into the coding session as context
3. Continue

This is the same "two-hat" split professionals do anyway — separate research and coding sessions.

### 6. No skills

Aider has `/help`, `/add`, `/run`, `/diff`, etc. — those are the "skills" of the coding stack. User-defined skills (`/brief`, `/recall`) are chat-harness territory. Coding is prompt-driven and repo-context-driven; a skill layer would be over-engineering.

---

## Directory layout

```
~/agent-harness/                        (WSL, existing repo)
├── ralph/                              # existing frankbria-ralph subtree — DO NOT MODIFY
│   ├── ralph.sh
│   ├── afk.sh
│   ├── lib/
│   └── ... (as it stands today)
├── config/
│   ├── aider.conf.yml                  # global defaults: model, auto-test, log dir
│   └── ralph-prompt.md                 # default loop constitution
├── bin/
│   ├── code                            # → exec aider with defaults
│   ├── code-ralph                      # → exec ralph.sh with aider as agent
│   └── code-issue                      # → gh + aider + push + PR
├── templates/
│   ├── ralph-scaffold/                 # copied into target repos on first ralph run
│   │   ├── PROGRESS.md
│   │   ├── TASKS.md
│   │   └── .ralph/
│   │       └── prompt.md
│   ├── aider-project.yml               # per-repo aider config template
│   └── continue-config.yaml            # snippet for VS Code Continue.dev
├── install/
│   ├── wsl-setup.sh                    # apt: git, python3, pipx; pipx: aider
│   ├── ollama-pull.ps1                 # Windows: pulls coder + autocomplete models
│   └── vscode-continue-note.md         # how to paste continue-config.yaml
└── README.md
```

---

## Wrapper script shapes

**`bin/code`** — HITL aider launcher:

```bash
#!/usr/bin/env bash
set -euo pipefail
exec aider \
  --model "ollama/qwen2.5-coder:14b-instruct-q4_K_M" \
  --openai-api-base "http://localhost:11434/v1" \
  --auto-test --test-cmd "make test 2>/dev/null || pytest 2>/dev/null || true" \
  --config "$HOME/agent-harness/config/aider.conf.yml" \
  "$@"
```

**`bin/code-ralph`** — AFK ralph loop:

```bash
#!/usr/bin/env bash
set -euo pipefail
REPO="${1:-$PWD}"
cd "$REPO"

# Scaffold if missing
[ -f TASKS.md ]     || cp "$HOME/agent-harness/templates/ralph-scaffold/TASKS.md" .
[ -f PROGRESS.md ]  || cp "$HOME/agent-harness/templates/ralph-scaffold/PROGRESS.md" .
[ -d .ralph ]       || cp -r "$HOME/agent-harness/templates/ralph-scaffold/.ralph" .

export AGENT_CMD="aider --model ollama/qwen2.5-coder:14b-instruct-q4_K_M --auto-test --yes"
export MAX_ITERATIONS="${MAX_ITERATIONS:-20}"

exec "$HOME/agent-harness/ralph/ralph.sh"
```

**`bin/code-issue`** — ralph-via-issues (sketch from `Local LLM Setup for Coding.md:280-311`):

```bash
#!/usr/bin/env bash
set -euo pipefail
ISSUE_NUM=$1
BRANCH="ralph/issue-${ISSUE_NUM}"

git checkout -b "$BRANCH"
TASK=$(gh issue view "$ISSUE_NUM" --json title,body -q '.title + "\n\n" + .body')

aider --model ollama/qwen2.5-coder:14b-instruct-q4_K_M \
      --message "$TASK" --auto-test --test-cmd "make test" --yes

attempts=0
while ! make test && [ $attempts -lt 3 ]; do
  attempts=$((attempts+1))
  FAILURE=$(make test 2>&1 | tail -50)
  aider --message "Tests still failing. Fix:\n$FAILURE" --yes
done

if make test; then
  git push -u origin "$BRANCH"
  gh pr create --title "Fix #${ISSUE_NUM}" --body "Closes #${ISSUE_NUM}. Automated ralph loop."
else
  gh issue comment "$ISSUE_NUM" --body "Ralph loop failed after 3 attempts. Human needed."
fi
```

---

## Config file shapes

**`config/aider.conf.yml`** (global defaults):

```yaml
model: ollama/qwen2.5-coder:14b-instruct-q4_K_M
openai-api-base: http://localhost:11434/v1
auto-test: true
auto-commits: true
dirty-commits: false
gitignore: true
pretty: true
stream: true
edit-format: diff
map-tokens: 4096
```

**`config/ralph-prompt.md`** (default loop constitution):

```markdown
You are executing a single iteration of a ralph loop.

Inputs:
- TASKS.md — the task list. Do exactly one focused task per iteration.
- PROGRESS.md — sprint memory. Read what you did last iteration.
- Last 5 commits — the working record.

Rules:
- One task per iteration. Do not batch.
- CI must stay green. If tests fail, fix in this iteration or revert.
- Append to PROGRESS.md what you learned, what surprised you.
- Move completed tasks to a "Done" section at the bottom of TASKS.md.
- If TASKS.md has no incomplete items, output the literal string:
    <promise>NO MORE TASKS</promise>
  and exit.

Do not add features, refactor, or introduce abstractions beyond what the task requires.
```

---

## Load-bearing risks

### 1. Qwen2.5-coder 14B falls short on multi-file agentic work

Documented in [[Local LLM Setup for Coding]] line 340-343. The model handles isolated file changes well and degrades on cross-file reasoning. Mitigations:

- Keep tasks small in `TASKS.md` — one file, one concept per task
- Use aider's repo map (`--map-tokens 4096`) to give Qwen structural context without full-file loads
- For complex multi-file refactors, don't use this stack; use Claude Code

### 2. Ralph AFK loops on Qwen produce plausible-looking-broken code

Even with `--auto-test`, Qwen will occasionally make tests pass by weakening them or by touching unrelated code. The 3-attempt retry cap in `code-issue` is a circuit breaker, not a quality gate. Mitigations:

- HITL first on any repo — run `code` a dozen times before running `code-ralph`
- Enable Docker sandbox in ralph (`afk.sh` variant) for anything untrusted
- Review every merge — treat ralph output as junior-engineer PRs, not merged commits

### 3. Continue.dev + aider can double-edit files

If both are active on the same file at the same time, edits race. Not a data-loss risk (git catches it) but confusing. Mitigation: convention. Continue for inline autocomplete only; aider for structural edits. Don't run both against the same file simultaneously.

### 4. Autocomplete model at 1.5B is *very* small

Continue.dev's default assumption is a 7B autocomplete model. Qwen2.5-coder:1.5b-base saves VRAM (leaves headroom for the 14B) at the cost of suggestion quality. If autocomplete suggestions feel weak, bump to `qwen2.5-coder:7b-base` — but then long chat context on 14B gets tight.

---

## Non-goals (out of scope)

- **MCP** — no MCP client. Route through [[chat-harness — Design Doc]] if MCP is needed, dump results to a file, `/add` the file to aider.
- **Vault I/O** — the coding stack does not read or write the Obsidian vault. Vault is chat-harness territory.
- **Skills** — no custom skill runner. Aider's built-in commands are the coding stack's vocabulary.
- **Sub-agents** — one agent per session. No parallel workers. (Ralph's iterations are sequential.)
- **Chat / research** — see [[chat-harness — Design Doc]].
- **Windows-native runtime** — this stack lives in WSL. The only Windows-side install is Ollama (already there) and Continue.dev in VS Code.

---

## V1 → V2 progression

**V1 (build target):**
- `bin/code`, `bin/code-ralph`, `bin/code-issue` scripts exist and work
- `config/aider.conf.yml` and `config/ralph-prompt.md` capture sensible defaults
- `templates/ralph-scaffold/` scaffolds a new repo on first run
- `install/wsl-setup.sh` reproducible on a fresh WSL Ubuntu
- One real repo used HITL via `code` for a week to validate defaults

**V2 (as friction accumulates):**
- Per-language `aider.conf.yml` variants (Python, Go, TS) selected by repo detection
- Ralph loop enhancements: better stop-condition detection, per-iteration timeout
- Optional Docker sandbox wrapper for `code-ralph` (already in `ralph/afk.sh` — expose as `code-ralph-afk`)
- Log aggregation across ralph runs into a single searchable format
- Optional web search shim (calls ddg CLI, prints results to stdout; user pipes into aider `--message`)

---

## Open questions to resolve during build

- Model size for autocomplete — start with 1.5b, upgrade to 7b if suggestions feel weak. Requires VRAM math: 14B chat (~9GB) + 7B autocomplete (~5GB) = 14GB, over the 10GB VRAM budget. So autocomplete must stay 1.5b unless the coder chat model is downgraded to 7B.
- Whether `code-ralph` should default to Docker sandbox or bare WSL. Bare is faster and matches HITL parity; Docker is safer. Tentative: bare by default, `code-ralph --sandbox` for opt-in.
- Whether to expose an `--openai-provider` env var for switching to a non-Ollama provider (e.g. groq, together.ai) when on a plane with no local GPU. Cheap to add; defer unless needed.

---

## Relationship to Claude-side harnesses

| Harness | Role | Model | Runtime |
|---|---|---|---|
| **agent-harness** (this doc) | OSS coding stack | qwen2.5-coder | WSL |
| **chat-harness** ([[chat-harness — Design Doc]]) | OSS chat/vault stack | qwen2.5-instruct | WSL, Windows-launched |
| **suzawa_help** | Claude coding harness (HITL) | Claude Sonnet/Opus | Windows |
| **frankbria-ralph** | Claude coding harness (AFK) | Claude Sonnet/Opus | WSL, Docker |
| **sap-harness** ([[sap-harness — Design Doc]]) | Claude hybrid (suzawa on ralph) | Claude | WSL/Docker |

agent-harness is the *OSS analog of frankbria-ralph* — same shape (aider replaces Claude Code, qwen replaces Claude), same purpose (repo-scoped AFK coding), same weaknesses (no MCP, model quality gap).

---

## Related

- [[chat-harness — Design Doc]] — sibling doc, chat-side stack. Read that one for the chat/research workflow.
- [[Local LLM Setup for Coding]] — hardware, model picks, install procedure, the Aider capability table (lines 249-328) this doc formalizes.
- [[RALPH — Autonomous Coding Loop]] — mechanics of the ralph loop.
- [[agent-harness — Workflow Setup and Project Bootstrap]] — earlier notes on the agent-harness repo.
- [[sap-harness — Design Doc]] — different harness (Claude-side). Cited for design-doc format and for the "bash owns the loop, prose owns the specialization" principle that also applies here (bash owns the loop, aider owns the edit).
- [[Vibe Coding — AI Coding Evolution and Cline]] — Cline was considered; ruled out for coding because aider is stronger on repo-scoped edits.
