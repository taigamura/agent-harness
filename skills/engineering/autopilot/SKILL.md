---
name: autopilot
description: Fly the whole post-grilling pipeline on its own — PRD → issues → queue/fix-plan → launch ralph — accepting each step's own recommendation without stopping to ask.
argument-hint: "[model alias: haiku | sonnet | opus | fable] — forwarded to the ralph loop"
disable-model-invocation: true
---

# Autopilot

You have just finished grilling a design (via `/grill-me` or `/grill-with-docs`) and the
conversation holds a fully-resolved plan. Autopilot takes it from there: it runs the rest of the
main flow — `/to-prd` → `/to-issues` → (`/to-queue` **or** `/to-fix-plan`) → the ralph loop —
back-to-back, **without pausing at the human gates**. Where a step would normally stop and quiz the
user, autopilot accepts that step's own recommendation and keeps going.

Use this when the design is already settled and you want the pipeline run AFK. If the design is
*not* settled, stop and tell the user to grill first (`/grill-me` or `/grill-with-docs`) — autopilot
does no interviewing and invents no requirements.

## The model argument

If the user passed an argument, treat it as a model alias (`haiku` / `sonnet` / `opus` / `fable`, or
a full model ID) and **forward it to the ralph loop only** via `ralph --model <alias>`. The planning
steps (`/to-prd`, `/to-issues`, `/to-queue`/`/to-fix-plan`) run on the current session model — a
skill cannot switch the live session model, so the argument changes only the AFK loop that ralph
spawns. If no argument was passed, launch ralph without `--model` (it uses its configured default).

## Process

Run these steps in order, in one unbroken context window. Do **not** clear or compact between them —
the PRD, issues, and task file all build on the same thinking from the grilling session.

### 1. `/to-prd` — synthesise the PRD

Invoke `/to-prd`. It synthesises the conversation into a PRD and publishes it to the issue tracker.

Its process asks you to confirm the test seams. **Do not stop for the user** — review the seams
yourself against the codebase (prefer existing seams, highest seam possible, fewest seams) and
proceed with the best choice. Note the seam decision in a one-line summary so the user can see what
was chosen, then continue.

### 2. `/to-issues` — break into vertical slices

Invoke `/to-issues`. It breaks the PRD into tracer-bullet vertical slices, assigns each a priority
(`P0`/`P1`/`P2`) and `Blocked by` references, and publishes them.

Its process runs an iterate-until-approved quiz on the breakdown. **Do not stop for the user** —
accept the granularity, priorities, and dependency graph that `/to-issues` proposes, publish the
issues with their priority labels, and continue. Print the proposed breakdown as a summary so the
user can see what was published.

### 3. Follow the downstream recommendation — `/to-queue` or `/to-fix-plan`

`/to-issues` ends by recommending a downstream skill based on the dependency graph it just built:

- **Any slice has a real `Blocked by: #N`** → it recommends `/to-queue`. Invoke `/to-queue`.
- **All slices `Blocked by: None` (flat set)** → it recommends `/to-fix-plan`. Invoke `/to-fix-plan`.

**Follow that recommendation** — do not second-guess it or ask the user which to use. Let the chosen
skill build its task file (`.ralph/queue.json` or `.ralph/fix_plan.md`) and its guardrails.

Both downstream skills stop at "here is the launch command" and deliberately do not run the loop.
Autopilot picks it up from there.

### 4. Launch ralph

Launch the ralph loop yourself — this is the one place autopilot goes past where the individual
skills stop. Pick the command from what step 3 built:

- **After `/to-queue` (graph has dependencies):**
  ```bash
  ralph --process-queue --halt-on-failure
  ```
  `--halt-on-failure` matters with deps: a failed blocker never reaches `completed`, so its
  dependents would sit `pending` forever while the loop runs against a half-done codebase. Halting
  gives a clean recovery point (`ralph --resume-queue`).

- **After `/to-fix-plan` (flat, local source):**
  ```bash
  ralph
  ```

If a model argument was passed, insert `--model <alias>` right after `ralph`:

```bash
ralph --model <alias> --process-queue --halt-on-failure   # queue
ralph --model <alias>                                      # fix_plan
```

Before launching, do the preflight the downstream skills already assume: `ralph` (and, for queues,
`ralph-queue`, `gh`, `jq`) on PATH, and the current directory is a ralph-enabled git repo
(`.ralphrc` present). If preflight fails, stop and point the user at the fix (`./install.sh`,
`ralph-enable`, or `harness-init`) rather than launching a broken loop.

## What autopilot does NOT do

- **No grilling.** The design must already be resolved. Autopilot starts at `/to-prd`.
- **No inventing work.** Every step synthesises what is already in context or in the issues.
- **No closing or modifying source issues.** Same as the skills it drives.
