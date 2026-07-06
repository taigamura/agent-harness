# agent-harness

My agentic-engineering harness: a set of Claude Code skills plus a standalone **RALPH loop** for shipping real software with coding agents — not vibe coding.

> **Attribution.** This project began as a fork of [mattpocock/skills](https://github.com/mattpocock/skills) (MIT) and is diverging into my own workflow. The `engineering/`, `productivity/`, and `misc/` skills are Matt Pocock's excellent work; the `ralph/` loop and project-specific pieces are mine. See [LICENSE](./LICENSE).

Developing real applications is hard. Approaches like GSD, BMAD, and Spec-Kit try to help by owning the process — but they take away your control and make bugs in the process hard to resolve. These skills are deliberately small, easy to adapt, and composable. They work with any model.

## Setup

### New machine (run once)

```bash
git clone https://github.com/taigamura/agent-harness.git
cd agent-harness
./setup-machine.sh
```

This installs the Claude Code skills and the `ralph` CLI in one step.

### New project (run once per repo)

```bash
cd your-project
harness-init
```

One command, two phases:

1. **`ralph-enable`** — scaffolds `.ralph/PROMPT.md`, `fix_plan.md`, `AGENT.md`, and `.ralphrc` in your project.
2. **`/setup-matt-pocock-skills`** — auto-launches Claude Code and walks you through the three per-repo conventions the engineering skills (`/to-prd`, `/to-issues`, `/triage`, `/qa`) read from:
   - **Issue tracker** — GitHub, GitLab, local markdown, or an "other" workflow you describe
   - **Triage label vocabulary** — the exact label strings `/triage` applies (defaults to `needs-triage`, `ready-for-agent`, etc., but map to your existing labels if you already have some)
   - **Domain doc layout** — single-context (one `CONTEXT.md` at the root) or multi-context (a `CONTEXT-MAP.md` pointing at per-package contexts, typical for monorepos)

Flags pass through to `ralph-enable`; add `--skip-skill` if you only want phase 1. Re-run only when you want to switch trackers or change conventions.

## Workflow

This harness implements Matt Pocock's **HITL → AFK pipeline**: planning is human-in-the-loop; implementation runs away-from-keyboard. The two halves hand off through a task list.

### Stage 0 — Setup (once)

```bash
./setup-machine.sh   # once per machine
harness-init         # once per project repo (scaffolds .ralph/ + runs /setup-matt-pocock-skills)
```

### Stage 1–3 — Research & Prototype (optional, HITL)

Explore unfamiliar parts of the codebase with a research subagent or a throwaway prototype. Use these stages to surface unknowns before committing to a design — not to produce production code.

### Stage 4 — PRD (HITL)

```
/grill-me   →   /to-prd
```

`/grill-me` interviews you one question at a time until the design is fully resolved. `/to-prd` synthesizes the conversation into a PRD and publishes it to GitHub Issues, auto-labelled `ready-for-agent`. Don't double-check the output — the grilling already produced the shared understanding.

### Stage 5 — Kanban (HITL)

```
/to-issues   →   /to-fix-plan   (flat graph)
             →   /to-queue      (any Blocked-by)
```

`/to-issues` breaks the PRD into vertical-slice tickets (each a thin cut through every layer — schema, API, UI, tests — not a horizontal layer), grills you on priority (`P0`/`P1`/`P2`) and Blocked-by per slice, and publishes the issues with those labels. At the end it recommends the downstream skill based on the dependency graph:

- **Flat set** (every slice `Blocked by: None`) → `/to-fix-plan` materialises the issues into `.ralph/fix_plan.md`, the checklist the linear loop reads top-to-bottom.
- **Real dependencies** (any slice `Blocked by: #N`) → `/to-queue` loads the issues into `ralph-queue`, which keeps the dep graph live and picks the next ready item on every step. Use `ralph --process-queue` in Stage 6 instead of plain `ralph`.

> `/triage` is not part of this flow. `/to-prd` and `/to-issues` already apply the `ready-for-agent` label. Run `/triage` only for issues that arrive from outside this flow (human bug reports, external PRs) that start as `needs-triage`.

> **Note on `ralph_import.sh`**: This upstream ralph tool is not part of this workflow. It replaces `/to-issues → /to-fix-plan` for teams who already have a PRD and want to generate `fix_plan.md` automatically — it assumes alignment has already happened elsewhere. The `/grill-me → /to-prd` steps this workflow uses first are not replaceable by it: that's where the design gets fully resolved before any code runs. If you're using this harness, skip `ralph_import.sh` entirely.

### Stage 6 — Implementation (AFK)

```bash
ralph --dry-run          # simulate without API calls — verify the task list looks right
ralph                    # linear: run the loop off .ralph/fix_plan.md
ralph --process-queue    # queue: dependency-aware; --halt-on-failure recommended when deps exist
```

The RALPH loop picks tasks (from `.ralph/fix_plan.md` or from `.ralph/queue.json` under `--process-queue`), runs `/tdd` per task (Red → Green → Refactor), commits, and loops. Runs unattended overnight. Use `ralph --monitor` for a live tmux dashboard.

#### Interrupting and resuming the loop on another machine

If you kill the tmux session mid-loop (e.g. you run out of tokens and want to continue later on a different PC):

1. **Commit any partial work** — run `git status` on the project repo. Commits Claude made are already in history; any uncommitted edits from the in-flight iteration should be staged and committed manually.
2. **Push** — `git push` the project repo as normal.

On the new machine, `git pull` and run `ralph` again. The loop restarts cleanly: it re-reads `fix_plan.md` to know where you left off, starts a fresh Claude session (no session continuity needed — the prompt + task list carry the context), and resets the hourly call counter.

**What carries over vs. what doesn't:**

| Transfers (`git push/pull`) | Stays behind (gitignored) |
|---|---|
| `.ralph/PROMPT.md` | `.ralph/.call_count` |
| `.ralph/fix_plan.md` | `.ralph/.claude_session_id` |
| `.ralph/AGENT.md` | `.ralph/.circuit_breaker_state` |
| All source code commits | `.ralph/status.json`, logs |

The only thing to check manually is `fix_plan.md` — make sure checked items reflect the actual committed state before you restart.

### Stage 7 — Review (AFK)

```
/clear   →   code-review subagent
```

Clear context before reviewing so the agent reads the diff cold — not with the same context that produced the code. The review runs as a fresh subagent against the PRD's acceptance criteria.

### Stage 8 — QA (HITL)

A human executes the QA checklist against the running build. Only humans catch "technically passes tests but wrong UX" failures. New failures become tickets and feed back into Stage 5.

## Ralph

### Understanding Ralph Files

After `harness-init` (or `ralph-enable` directly), your project's `.ralph/` directory contains:

| File | Auto-generated? | You should… |
|------|-----------------|-------------|
| `.ralph/PROMPT.md` | Yes (smart defaults) | **Review & customize** project goals and principles |
| `.ralph/fix_plan.md` | Yes (can import tasks) | **Add/modify** specific implementation tasks |
| `.ralph/AGENT.md` | Yes (detects build commands) | Rarely edit (auto-maintained by Ralph) |
| `.ralph/specs/` | Empty directory | Add files when `PROMPT.md` isn't detailed enough |
| `.ralph/specs/stdlib/` | Empty directory | Add reusable patterns and conventions |
| `.ralphrc` | Yes (project-aware) | Rarely edit (sensible defaults) |

```
PROMPT.md (high-level goals)
    ↓
specs/ (detailed requirements when needed)
    ↓
fix_plan.md (specific tasks Ralph executes)
    ↓
AGENT.md (build/test commands — auto-maintained)
```

### Configuration (.ralphrc)

```bash
PROJECT_NAME="my-project"
PROJECT_TYPE="typescript"

# Claude Code CLI command
CLAUDE_CODE_CMD="claude"
# CLAUDE_CODE_CMD="npx @anthropic-ai/claude-code"

# Shell init file — source before running claude (for zsh/fish users)
#RALPH_SHELL_INIT_FILE="~/.zshrc"

# Loop settings
MAX_CALLS_PER_HOUR=100
CLAUDE_TIMEOUT_MINUTES=15
CLAUDE_OUTPUT_FORMAT="json"
#MAX_TOKENS_PER_HOUR=500000   # 0 = disabled

# Tool permissions
ALLOWED_TOOLS="Write,Read,Edit,Bash(git *),Bash(npm *),Bash(pytest)"

# Session management
SESSION_CONTINUITY=true
SESSION_EXPIRY_HOURS=24

# Circuit breaker thresholds
CB_NO_PROGRESS_THRESHOLD=3
CB_SAME_ERROR_THRESHOLD=5
CB_COOLDOWN_MINUTES=30
CB_AUTO_RESET=false   # true = bypass cooldown on startup (fully unattended)
```

**Optional sections in `fix_plan.md`** — by default Ralph loops until every `- [ ]` is checked. Mark work as genuinely optional by placing it under a heading called `Optional`, `Future`, `Future Enhancements`, or `Nice to Have` (configurable via `OPTIONAL_SECTIONS` in `.ralphrc`, comma-separated, case-insensitive):

```markdown
## High Priority
- [x] Core feature

## Optional
- [ ] Frontend integration   # does NOT block exit
- [ ] SMS notifications      # does NOT block exit
```

### Integration Hooks

Two env-var hooks let external tooling plug into the loop without patching ralph itself. Both are no-ops when unset.

| Env var | When it runs | Exit code semantics |
|---------|-------------|---------------------|
| `SAP_HARNESS_COMPOSE` | Before each Claude invocation | `0` = proceed; `42` = sprint done, stop cleanly; other non-zero = error, stop |
| `SAP_HARNESS_POST_ITER` | After each successful iteration | Non-zero logged as warning; loop continues |

`SAP_HARNESS_COMPOSE` receives the current `PROMPT_FILE` path as `$1` and is expected to overwrite it in place. `SAP_HARNESS_POST_ITER` receives no arguments.

```bash
export SAP_HARNESS_COMPOSE=/path/to/compose_prompt.sh
export SAP_HARNESS_POST_ITER=/path/to/post_iteration.sh
```

### Signal-File Loop Control

Two files in the project's `.ralph/` directory control the loop without killing the process:

```bash
touch .ralph/pause    # pause at the next iteration boundary (loop spins until removed)
touch .ralph/stop     # clean exit at the next iteration boundary
rm .ralph/pause       # resume a paused loop
```

Both files are gitignored. In-flight Claude sessions run to completion naturally before the gate fires.

### GitHub Issue Lifecycle

Pass `--github-issue <ref>` to `ralph` to close the loop on the whole GitHub workflow. All operations are opt-in and degrade gracefully — a `gh` failure is logged and the loop continues.

```bash
# Post a progress comment every 5 loops
ralph --github-issue 69 --comment-progress --comment-interval 5

# On completion: PR linked to the issue, summary comment, close it
ralph --github-issue 69 --create-pr --link-issue --close-summary --auto-close

# Add labels on close; open a follow-up for any TODO/FIXME in the diff
ralph --github-issue 69 --auto-close --add-label completed \
      --create-followups --followup-label tech-debt

# Draft PR for manual review
ralph --github-issue 69 --create-pr --draft-pr
```

These can also be set in `.ralphrc` (`COMMENT_PROGRESS`, `AUTO_CLOSE`, `CREATE_PR`, etc.).

### Batch Processing / Issue Queue

`ralph-queue` builds a persistent queue at `.ralph/queue.json` and processes items sequentially by priority and dependency order.

```bash
# Build a queue
ralph-queue add --github-label "bug,P0"
ralph-queue add --github-milestone "v1.0"
ralph-queue add --github-issues 69,70,71
ralph-queue add --prd ./docs/feature.md

# Manage
ralph-queue status            # show queue; --json for machine output
ralph-queue reorder           # sort by priority (P0 first)
ralph-queue validate          # check for circular dependencies
ralph-queue remove 69
ralph-queue clear

# Process
ralph --process-queue                    # priority + dependency order
ralph --process-queue --halt-on-failure  # stop at first failure
ralph --resume-queue                     # continue remaining pending items
```

### Sandbox Execution

**Docker**: Ralph's orchestration stays on the host; only Claude's execution is containerised.

```bash
docker pull ghcr.io/frankbria/ralph-sandbox:latest
ralph --sandbox docker
ralph --sandbox docker --sandbox-image node:20 --sandbox-memory 8g --sandbox-cpus 4
ralph --sandbox docker --sandbox-network none   # full isolation (blocks Claude API — special images only)
```

**E2B cloud**: project uploaded once at start; changed files sync back after every iteration.

```bash
pip install e2b
export E2B_API_KEY="e2b_..."
ralph --sandbox e2b
ralph --sandbox e2b --sandbox-max-cost 5.00 --sandbox-cost-alert 2.00
ralph --sandbox e2b --sync-include "src/**,tests/**" --sync-exclude "*.log,node_modules"
```

### Monitoring and Debugging

```bash
ralph --monitor              # integrated tmux dashboard (recommended)
ralph-monitor                # manual monitoring in a separate terminal
ralph --status               # JSON status output
tail -f .ralph/logs/ralph.log
ralph-stats                  # metrics summary from .ralph/logs/metrics.jsonl
```

**tmux controls:** `Ctrl+B D` detach (keeps running), `Ctrl+B ←/→` switch panes, `tmux attach -t <name>` reattach.

### Common Issues

- **Ralph exits on first loop** — Claude Code CLI not installed or not in PATH. Add `CLAUDE_CODE_CMD="npx @anthropic-ai/claude-code"` to `.ralphrc` if using npx.
- **Permission denied** — Update `ALLOWED_TOOLS` in `.ralphrc` (e.g. add `Bash(npm *)`), then `ralph --reset-session`.
- **Stuck / premature exit** — Check `fix_plan.md` for unclear tasks; review whether Claude is setting `EXIT_SIGNAL: false`.
- **5-hour API limit** — Ralph detects it and prompts: wait 60 min or exit. In unattended mode it auto-waits.
- **Session expired** — Sessions expire after 24 hours by default; `ralph --reset-session` to start fresh.
- **`timeout: command not found` (macOS)** — `brew install coreutils`.
- **Circuit breaker open** — `ralph --reset-circuit` or set `CB_AUTO_RESET=true` in `.ralphrc`.

### System Requirements

- **Bash 4.0+**
- **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`
- **tmux** — `apt-get install tmux` / `brew install tmux`
- **jq** — JSON processing
- **Git** — projects must be git repos
- **GNU coreutils** — for `timeout`; on macOS: `brew install coreutils`

### Command Reference

```bash
# Loop options
ralph [OPTIONS]
  -h, --help              show help
  -c, --calls NUM         max calls/hour (default: 100)
  -p, --prompt FILE       prompt file (default: .ralph/PROMPT.md)
  -s, --status            show status and exit
  -m, --monitor           start with tmux monitoring
  -v, --verbose           detailed progress updates
  -l, --live              real-time Claude Code output streaming
  -t, --timeout MIN       execution timeout in minutes (1-120, default: 15)
      --dry-run           simulate without API calls
  -n, --notify            desktop notifications for key events
  -b, --backup            git backup branch before each loop
      --rollback [BRANCH] roll back to a backup branch
      --output-format     json (default) or text
      --allowed-tools     allowed Claude tools
      --no-continue       fresh session each loop
      --session-expiry    session expiration in hours (default: 24)
      --reset-circuit     reset the circuit breaker
      --circuit-status    show circuit breaker status
      --auto-reset-circuit auto-reset circuit breaker on startup
      --reset-session     reset session state manually
      --github-issue REF  track a GitHub issue (enables lifecycle flags)
      --process-queue     process queued issues sequentially
      --resume-queue      continue remaining pending items
      --queue-status      show the queue and exit
      --queue-next        print the next ready issue id
      --queue-clear       empty the queue
      --queue-remove <id> remove one item
      --sandbox docker|e2b run Claude in an isolated container/cloud sandbox

# Project commands
ralph-setup my-project   # create new project
ralph-enable             # enable ralph in existing project (interactive)
ralph-enable-ci          # same, non-interactive
ralph-import prd.md      # convert PRD/spec to ralph project
ralph-queue add …        # add items to the batch queue
ralph-monitor            # live monitoring dashboard
ralph-stats              # metrics summary
ralph-migrate            # migrate flat structure to .ralph/ subfolder

# tmux session management
tmux list-sessions
tmux attach -t <name>
```

## Why These Skills Exist

I built these skills as a way to fix common failure modes I see with Claude Code, Codex, and other coding agents.

### #1: The Agent Didn't Do What I Want

> "No-one knows exactly what they want"
>
> David Thomas & Andrew Hunt, [The Pragmatic Programmer](https://www.amazon.co.uk/Pragmatic-Programmer-Anniversary-Journey-Mastery/dp/B0833F1T3V)

**The Problem**. The most common failure mode in software development is misalignment. You think the dev knows what you want. Then you see what they've built - and you realize it didn't understand you at all.

This is just the same in the AI age. There is a communication gap between you and the agent. The fix for this is a **grilling session** - getting the agent to ask you detailed questions about what you're building.

**The Fix** is to use:

- [`/grill-me`](./skills/productivity/grill-me/SKILL.md) - for non-code uses
- [`/grill-with-docs`](./skills/engineering/grill-with-docs/SKILL.md) - same as [`/grill-me`](./skills/productivity/grill-me/SKILL.md), but adds more goodies (see below)

These are my most popular skills. They help you align with the agent before you get started, and think deeply about the change you're making. Use them _every_ time you want to make a change.

### #2: The Agent Is Way Too Verbose

> With a ubiquitous language, conversations among developers and expressions of the code are all derived from the same domain model.
>
> Eric Evans, [Domain-Driven-Design](https://www.amazon.co.uk/Domain-Driven-Design-Tackling-Complexity-Software/dp/0321125215)

**The Problem**: At the start of a project, devs and the people they're building the software for (the domain experts) are usually speaking different languages.

I felt the same tension with my agents. Agents are usually dropped into a project and asked to figure out the jargon as they go. So they use 20 words where 1 will do.

**The Fix** for this is a shared language. It's a document that helps agents decode the jargon used in the project.

<details>
<summary>
Example
</summary>

Here's an example [`CONTEXT.md`](https://github.com/mattpocock/course-video-manager/blob/076a5a7a182db0fe1e62971dd7a68bcadf010f1c/CONTEXT.md), from my `course-video-manager` repo. Which one is easier to read?

- **BEFORE**: "There's a problem when a lesson inside a section of a course is made 'real' (i.e. given a spot in the file system)"
- **AFTER**: "There's a problem with the materialization cascade"

This concision pays off session after session.

</details>

This is built into [`/grill-with-docs`](./skills/engineering/grill-with-docs/SKILL.md). It's a grilling session, but that helps you build a shared language with the AI, and document hard-to-explain decisions in ADR's.

It's hard to explain how powerful this is. It might be the single coolest technique in this repo. Try it, and see.

> [!TIP]
> A shared language has many other benefits than reducing verbosity:
>
> - **Variables, functions and files are named consistently**, using the shared language
> - As a result, the **codebase is easier to navigate** for the agent
> - The agent also **spends fewer tokens on thinking**, because it has access to a more concise language

### #3: The Code Doesn't Work

> "Always take small, deliberate steps. The rate of feedback is your speed limit. Never take on a task that’s too big."
>
> David Thomas & Andrew Hunt, [The Pragmatic Programmer](https://www.amazon.co.uk/Pragmatic-Programmer-Anniversary-Journey-Mastery/dp/B0833F1T3V)

**The Problem**: Let's say that you and the agent are aligned on what to build. What happens when the agent _still_ produces crap?

It's time to look at your feedback loops. Without feedback on how the code it produces actually runs, the agent will be flying blind.

**The Fix**: You need the usual tranche of feedback loops: static types, browser access, and automated tests.

For automated tests, a red-green-refactor loop is critical. This is where the agent writes a failing test first, then fixes the test. This helps give the agent a consistent level of feedback that results in far better code.

I've built a **[`/tdd`](./skills/engineering/tdd/SKILL.md) skill** you can slot into any project. It encourages red-green-refactor and gives the agent plenty of guidance on what makes good and bad tests.

For debugging, I've also built a **[`/diagnosing-bugs`](./skills/engineering/diagnosing-bugs/SKILL.md)** skill that wraps best debugging practices into a simple loop.

### #4: We Built A Ball Of Mud

> "Invest in the design of the system _every day_."
>
> Kent Beck, [Extreme Programming Explained](https://www.amazon.co.uk/Extreme-Programming-Explained-Embrace-Change/dp/0321278658)

> "The best modules are deep. They allow a lot of functionality to be accessed through a simple interface."
>
> John Ousterhout, [A Philosophy Of Software Design](https://www.amazon.co.uk/Philosophy-Software-Design-2nd/dp/173210221X)

**The Problem**: Most apps built with agents are complex and hard to change. Because agents can radically speed up coding, they also accelerate software entropy. Codebases get more complex at an unprecedented rate.

**The Fix** for this is a radical new approach to AI-powered development: caring about the design of the code.

This is built in to every layer of these skills:

- [`/to-prd`](./skills/engineering/to-prd/SKILL.md) quizzes you about which modules you're touching before creating a PRD

And crucially, [`/improve-codebase-architecture`](./skills/engineering/improve-codebase-architecture/SKILL.md) helps you rescue a codebase that has become a ball of mud. I recommend running it on your codebase once every few days.

### Summary

Software engineering fundamentals matter more than ever. These skills are my best effort at condensing these fundamentals into repeatable practices, to help you ship the best apps of your career. Enjoy.

## Reference

These split on one axis — who can invoke them. **User-invoked** skills are reachable only when you type them (e.g. `/grill-me`); their job is to orchestrate. **Model-invoked** skills can be invoked by you _or_ reached for automatically by the agent when the task fits; they hold the reusable discipline. A user-invoked skill may invoke model-invoked skills, but never another user-invoked one.

### Engineering

Skills I use daily for code work.

**User-invoked**

- **[ask-matt](./skills/engineering/ask-matt/SKILL.md)** — Ask which skill or flow fits your situation. A router over the user-invoked skills in this repo.
- **[grill-with-docs](./skills/engineering/grill-with-docs/SKILL.md)** — Grilling session that also builds your project's domain model, sharpening terminology and updating `CONTEXT.md` and ADRs inline.
- **[triage](./skills/engineering/triage/SKILL.md)** — Move issues through a state machine of triage roles.
- **[improve-codebase-architecture](./skills/engineering/improve-codebase-architecture/SKILL.md)** — Scan a codebase for deepening opportunities, present them as a visual HTML report, then grill through whichever one you pick.
- **[setup-matt-pocock-skills](./skills/engineering/setup-matt-pocock-skills/SKILL.md)** — Configure this repo's issue-tracker choice, triage label vocabulary, and domain doc layout, so `/to-prd`, `/to-issues`, `/triage`, and `/qa` know what conventions to follow here. Run once per repo before first use of the engineering flow.
- **[to-issues](./skills/engineering/to-issues/SKILL.md)** — Break any plan, spec, or PRD into independently-grabbable issues using vertical slices.
- **[to-fix-plan](./skills/engineering/to-fix-plan/SKILL.md)** — Turn ready-for-agent issues into a frankbria ralph `.ralph/fix_plan.md` checklist (the `local` task source the AFK loop works top-to-bottom). Use when the graph is flat.
- **[to-queue](./skills/engineering/to-queue/SKILL.md)** — Turn ready-for-agent issues into a frankbria ralph `.ralph/queue.json` — dependency-aware task source for `ralph --process-queue`. Use when the graph has real blockers.
- **[to-prd](./skills/engineering/to-prd/SKILL.md)** — Turn the current conversation into a PRD and publish it to the issue tracker. No interview — just synthesizes what you've already discussed.
- **[prototype](./skills/engineering/prototype/SKILL.md)** — Build a throwaway prototype to flesh out a design — either a runnable terminal app for state/business-logic questions, or several radically different UI variations toggleable from one route.

**Model-invoked**

- **[diagnosing-bugs](./skills/engineering/diagnosing-bugs/SKILL.md)** — Disciplined diagnosis loop for hard bugs and performance regressions: reproduce → minimise → hypothesise → instrument → fix → regression-test.
- **[tdd](./skills/engineering/tdd/SKILL.md)** — Test-driven development with a red-green-refactor loop. Builds features or fixes bugs one vertical slice at a time.
- **[domain-modeling](./skills/engineering/domain-modeling/SKILL.md)** — Actively build and sharpen a project's domain model — challenge terms against the glossary, stress-test with edge-case scenarios, and update `CONTEXT.md` and ADRs inline.
- **[codebase-design](./skills/engineering/codebase-design/SKILL.md)** — Shared discipline and vocabulary for designing deep modules: a lot of behaviour behind a small interface, placed at a clean seam, testable through that interface.

### Productivity

General workflow tools, not code-specific.

**User-invoked**

- **[grill-me](./skills/productivity/grill-me/SKILL.md)** — Get relentlessly interviewed about a plan or design until every branch of the decision tree is resolved.
- **[handoff](./skills/productivity/handoff/SKILL.md)** — Compact the current conversation into a handoff document so another agent can continue the work.
- **[teach](./skills/productivity/teach/SKILL.md)** — Teach the user a new skill or concept over multiple sessions, using the current directory as a stateful teaching workspace.
- **[writing-great-skills](./skills/productivity/writing-great-skills/SKILL.md)** — Reference for writing and editing skills well: the vocabulary and principles that make a skill predictable.

**Model-invoked**

- **[grilling](./skills/productivity/grilling/SKILL.md)** — Interview the user relentlessly about a plan or design until every branch of the decision tree is resolved. The reusable loop behind `grill-me` and `grill-with-docs`.

