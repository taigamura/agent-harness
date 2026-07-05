---
name: to-queue
description: Turn ready-for-agent issues into a frankbria ralph `.ralph/queue.json` — the dependency-aware task source the AFK loop works via `ralph --process-queue`.
disable-model-invocation: true
---

# To Queue

Load the ready-for-agent issues into `ralph-queue`, the dependency-aware sibling of
`.ralph/fix_plan.md`. This is the bridge between HITL planning (`/to-prd` → `/to-issues`) and the
AFK loop when the issue graph has real dependencies — items that must complete before others become
implementable, or that may unblock mid-run in a different order than you first predicted.

Run this **after** `/to-issues` has published the slices with priority labels (`P0`/`P1`/`P2`) and
"Blocked by" references. It does not interview and it does not invent work — it verifies the graph
the issues already encode, feeds it to `ralph-queue`, and hands off.

> **When NOT to use this.** If `/to-issues` produced a flat set (every slice `Blocked by: None`),
> use `/to-fix-plan` instead. The queue's win over fix_plan is dep-aware ordering — a flat queue
> gives you no benefit over the checklist file, and the fix_plan carries a Definition-of-done
> header and Out-of-scope fence prose that suit linear runs.

## Why a queue beats a fix_plan when deps exist

`fix_plan.md` is a flat ordered checklist. The loop reads it top-to-bottom, and dependency
information the plan-writer used to *decide* the order is discarded once it's written — the file
carries no machine-readable "depends on #N". If a blocking item stalls, or a mid-list item
unblocks after work on a later item, ralph can't reorder.

`ralph-queue` keeps issues as JSON with `priority` + `dependencies` fields, and `get_next_issue`
picks the highest-priority item whose deps are all `completed` **on every step**. `parse_issue_dependencies`
reads "depends on / blocked by / requires #N" out of issue bodies — the same phrasing `/to-issues`
already writes in its `## Blocked by` section.

## Process

### 1. Preflight

- Verify `ralph-queue` is on PATH. If not, tell the user to run `./install.sh` from the harness repo.
- Verify the current directory is a git repo with `.ralphrc` (or a ralph-enabled project). If not,
  tell the user to run `ralph-enable` or `harness-init` first.
- Verify `gh` and `jq` are on PATH — `ralph-queue add` needs both for GitHub sources.

If any preflight fails, stop and point at the fix.

### 2. Fetch the ready-for-agent issues

Pull the issues labelled `ready-for-agent` (or the project's configured agent label; the frankbria
default in `.ralphrc` is `GITHUB_TASK_LABEL="ralph-task"`) from the issue tracker. Read each
issue's body and its "Blocked by" field.

If nothing is `ready-for-agent`, stop and tell the user to run `/to-issues` (and if applicable
`/triage`) first.

### 3. Sanity-check the graph

`ralph-queue` will silently degrade to FIFO if the graph isn't shaped for it. Catch that here,
before building the queue. Verify every fetched issue has:

- **A priority label the queue recognises** — bare `P0`–`P9` or a `priority: PN` label. The
  standard produced by `/to-issues` is `P0` / `P1` / `P2`. If any issue is missing one, stop and
  tell the user to re-run `/to-issues` on the offending issues (or add the label manually via
  `gh issue edit <N> --add-label P1`).
- **A `## Blocked by` section that names concrete `#N` references or "None".** `ralph-queue`'s
  parser recognises "depends on / blocked by / requires #N"; free-prose blockers ("waiting on the
  API refactor") will not be parsed. If any issue has an unparseable blocker, stop and ask the user
  to fix the wording on GitHub.
- **Every `Blocked by: #N` target is either in the fetched set, or already `closed` on GitHub.**
  A blocker that isn't queued and isn't closed will sit `pending` forever. Warn if a blocker is
  closed (the queue treats it as an unmet dep — either add it to the queue as completed, or edit
  the issue to remove the reference).

Stop on any hard failure. Do not proceed with a half-valid graph.

### 4. Write session guardrails into `.ralph/PROMPT.md`

`.ralph/PROMPT.md` is the durable instruction file the ralph loop re-reads on every iteration.
`ralph-queue` writes a per-item `fix_plan.md` at each step, but has no home for
**session-scoped** guardrails — the "don't touch payments while working on notifications" prose
that no single issue's acceptance criteria says.

Add a `## Session guardrails` section to `.ralph/PROMPT.md`. If the section already exists (from a
prior `/to-queue` run), replace its contents. If not, append it. The section carries:

- **Definition of done (every item):** the project's verify gate is green, one commit per item,
  revert-and-report if you can't finish cleanly.
- **Out of scope this session:** an explicit fence naming what the loop must NOT touch. Pull this
  from the PRD, `CLAUDE.md`, or `.ralph/AGENT.md`.

Use these exact markers so the section can be found and replaced on re-run:

```markdown
<!-- BEGIN: to-queue session guardrails -->
## Session guardrails

**Definition of done (every item):** <the verify gate + one-commit + revert-on-red rules>.

**Out of scope this session:** <what the loop must not touch — deferred to a supervised pass>.
<!-- END: to-queue session guardrails -->
```

### 5. Build the queue

- `ralph-queue clear` if a stale queue exists from a prior run (confirm with the user first — this
  drops any `completed` history in `.ralph/queue.json`).
- `ralph-queue add --github-label <ready-label>` — adds every ready-for-agent issue in one call.
  Fewer round-trips than `--github-issues N,N,N`, and `ralph-queue` reuses the ralph-import filter
  machinery so labels + milestone + assignee filters compose the same way if the user needs them.
- `ralph-queue validate` — hard-check for circular dependencies. If it fails, stop and surface the
  cycle to the user.
- `ralph-queue reorder` — sort by priority (P0 first, FIFO tiebreak).

### 6. Show + hand off

- `ralph-queue status` — print the queue.
- Summarise the dep chains in plain English: "A (#12) → C (#14), B (#13) → D (#15) → E (#16)".
- Recommend the launch command, keyed on whether the graph has real dependencies:

  - **Any issue has a `Blocked by: #N`:**
    ```bash
    ralph --process-queue --halt-on-failure
    ```
    `--halt-on-failure` matters here because a failed blocker corrupts everything downstream — the
    dep target never reaches `completed`, so its dependents sit `pending` forever, and the loop
    keeps running against a codebase where the blocker is half-done. Halting gives a clean recovery
    point: fix the blocker, then `ralph --resume-queue`.

  - **Flat queue (no deps):**
    ```bash
    ralph --process-queue
    ```
    Without deps, one failure doesn't orphan anything else. Halting wastes the parallelism the queue
    gives you. If you'd rather halt anyway (e.g. a failure implies a structural problem like a broken
    tool permission), add `--halt-on-failure` yourself.

Do not run the loop yourself, and do not close or modify the source issues.
