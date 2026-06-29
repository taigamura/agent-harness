---
name: to-fix-plan
description: Turn ready-for-agent issues (or a PRD/plan in context) into a frankbria ralph `.ralph/fix_plan.md` checklist — the local task source the AFK loop works top-to-bottom.
disable-model-invocation: true
---

# To Fix Plan

Convert the agent-ready issues into `.ralph/fix_plan.md`, the ordered checklist the
[frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) loop consumes as its
`local` task source. This is the bridge between HITL planning (`/to-prd` → `/to-issues` → `/triage`)
and the AFK loop (`ralph`).

Run this **after** the issues exist and are triaged. It does not interview and it does not invent
work — it synthesises issues you have already shaped into the format the loop reads.

> **When NOT to use this.** If you run ralph off the GitHub queue (`ralph-queue add --github-label
> …` + `ralph --process-queue`), the loop reads issues directly and you do not need a fix_plan. Use
> this skill when you drive the loop off the `local` source — i.e. `.ralphrc` has `local` in
> `TASK_SOURCES` — and you want a single curated, ordered, scope-fenced plan file.

## Why a curated fix_plan beats a raw queue import

A queue is a flat label-filtered list. `fix_plan.md` lets you express the things that make an AFK
session safe: **ordering** (do these first, defer those), an explicit **out-of-scope fence**, and a
**definition of done** every item inherits. Preserve that — it is the whole point.

## Process

### 1. Gather the source material

In priority order, use whichever is present:

1. **Triaged issues** — fetch the issues labelled `ready-for-agent` (or the project's configured
   agent label; the frankbria default in `.ralphrc` is `GITHUB_TASK_LABEL="ralph-task"`) from the
   issue tracker. Read each issue's body and its "Blocked by" field. This is the normal path.
2. **An argument** — if the user passes an issue reference, label, PRD path, or plan file, start from
   that.
3. **Conversation context** — if a PRD or plan was just produced in this session, use it.

If none of these exist, stop and tell the user to run `/to-issues` (and `/triage`) first.

> Note: a root `PROMPT.md` or hand-written backlog is fine as *input* here, but the ralph loop does
> **not** read root `PROMPT.md` — it reads `.ralph/PROMPT.md` and `.ralph/fix_plan.md`. Fold any such
> backlog into the fix_plan; don't leave it as a second source of truth.

### 2. Read the existing fix_plan (do not clobber progress)

If `.ralph/fix_plan.md` already exists, read it. **Preserve every `- [x]` completed item and its
note verbatim** in a `## Completed` section — the loop and `lib/github_lifecycle.sh` report progress
by counting checked vs unchecked boxes. You are only adding/reordering the unchecked work.

### 3. Order the work

- **Blockers first.** Sort by the issues' dependency relationships so the single-highest-unchecked
  item is always unblocked.
- **Then by tracer-bullet priority** (mirror the loop's own preference): critical bugfixes → dev
  infrastructure (tests/types/scripts) → tracer-bullet feature slices → polish/quick wins →
  refactors.
- Map that onto frankbria's three buckets: **High Priority**, **Medium Priority**, **Low Priority**.

### 4. Write each item as one actionable, self-contained line

The loop does **one item per loop** and re-reads the file cold each time, so each item must stand
alone:

- Start with `- [ ]`.
- One concrete, demoable/verifiable unit of work — a vertical slice, not "the whole API layer".
- **Cite the issue**: end the line (or its lead sentence) with `(#N)` so humans and the loop can
  trace it back. Citing the issue keeps the durable spec in the tracker and the line short.
- Enough detail to act without opening five files, but avoid brittle line numbers / code snippets
  that go stale — point at the issue for those.

### 5. Carry scope and the definition of done into the header

Above the priority sections, write a short scope paragraph and a one-line-per-item **Definition of
done** (e.g. the project's verify gate is green, one commit, revert-and-report if you can't). Add an
**Out of scope this session** fence listing what the loop must NOT touch. This is what stops an AFK
agent from wandering. Pull this language from the PRD / `CLAUDE.md` / `.ralph/AGENT.md`.

### 6. Emit `.ralph/fix_plan.md` in frankbria's layout

Use exactly these section headings so the loop and progress tooling parse it:

```markdown
# Ralph Fix Plan

<one-paragraph scope statement>

**Definition of done (every item):** <the verify gate + one-commit + revert-on-red rules>.

## High Priority
- [ ] <task> (#N)

## Medium Priority
- [ ] <task> (#N)

## Low Priority
- [ ] <task> (#N)

## Out of scope this session
<what the loop must not touch — deferred to a supervised pass>

## Completed
- [x] <preserved verbatim from the previous fix_plan, with its note>

## Notes
- One focused change per loop; one commit; never leave the verify gate red.
```

Omit a priority section only if it would be empty (keep `## Completed` even if it just has the
`Project enabled for Ralph` line).

### 7. Confirm and point at the next step

Summarise to the user: how many items in each bucket, which issues map where, and what's fenced as
out of scope. Then remind them of the loop entry point:

```bash
ralph --dry-run        # HITL verify pass — confirm task selection, no API calls
ralph                  # run the loop off the local fix_plan
```

Do not run the loop yourself, and do not close or modify the source issues.
