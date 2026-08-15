# Pending fixes: queue completion gate + default sandbox (from a real ralph-queue run)

**Status:** open, actionable by a separate session.
**Source:** a 9-issue `ralph --process-queue` run (nibble-app) that halted on the *first*
item despite that item being fully, correctly implemented with a green verify gate. Root-caused to
harness bugs, not agent behaviour. Details and exact line references below.

---

## BUG 1 (primary) — queue completion gate counts the *whole* fix_plan.md, failing genuinely-complete items

### Where
`ralph/ralph_queue.sh`, the post-run completion check (installed copy: `~/.ralph/ralph_queue.sh:452-466`).

```bash
# ~/.ralph/ralph_queue.sh (installed)
# 449:  # signals: the per-item fix_plan.md's task box still unchecked, or a
#       human-gate.md entry that changed during this run. ...
452:    local unchecked=0
...
457:    unchecked=$(grep -c '^- \[ \]' "$RALPH_DIR/fix_plan.md" 2>/dev/null)
458:    [[ -z "$unchecked" ]] && unchecked=0
...
463:    if [[ "$unchecked" -gt 0 || "$gate_after" != "$gate_before" ]]; then
464:        mark_issue_status "$id" failed "gated: loop exited 0 but left ${unchecked} unchecked fix_plan item(s) ... (see agent-harness#14)"
```

### The defect
The comment on line 449 states the intent: fail the item only if **its own task box** is still
unchecked. The implementation on line 457 instead does a **raw full-file grep** for `^- [ ]`,
counting *every* unchecked checkbox anywhere in `fix_plan.md` — including forward-looking notes the
agent legitimately wrote about **other** queue items.

This is also **inconsistent with the exit gate** in `ralph/ralph_loop.sh`, which already solved this
class of problem for Issue #239 via `_count_blocking_unchecked()` + `OPTIONAL_SECTIONS`
(`Optional,Future,Future Enhancements,Nice to Have`). The queue gate does not use that function, so
the two gates disagree about what "done" means.

### Observed failure (real)
The agent finished queue item `github-2`, marked its own task `- [x]`, and passed the full gate
(`tsc --noEmit` clean, `jest` 10/10). But it also appended a helpful preview:

```markdown
## Next up (not started)
- [ ] GitHub issue #3 — Real place data …
- [ ] GitHub issue #5 — Rating flow …
- [ ] GitHub issue #7 — Collection & history …
- [ ] GitHub issue #9 — Anonymous-first auth …
```

The gate counted `unchecked=4`, marked `github-2` **failed** with
`error_message: "gated: loop exited 0 but left 4 unchecked fix_plan item(s) … (see agent-harness#14)"`,
and `--halt-on-failure` stopped the entire run. The completed, correct, tested work was flagged as a
failure purely because the agent wrote checkbox-shaped notes about *future* items.

> Note: `agent-harness#14` (closed) is the change that made gated items fail instead of silently
> completing. This report is a **regression/over-correction on top of #14**, not #14 itself — the
> gate now over-counts and produces false negatives.

### Fix (recommended)
1. Replace the raw `grep -c '^- \[ \]'` on line 457 with the existing
   `_count_blocking_unchecked "$RALPH_DIR/fix_plan.md"` so the queue gate honours `OPTIONAL_SECTIONS`
   (Issue #239) — unify the two gates on one counting function.
2. Better still, scope the count to the **current item's own section**. The per-item `fix_plan.md`
   ralph writes has a single `## Current Task` block for the active item; the gate should only look
   at that block's checkbox(es), not the file. Forward-looking `## Next up` / `## Learnings`
   sections must never contribute to the completion count.
3. Add `Next up`, `Not started`, `Learnings`, `Notes` to the default `OPTIONAL_SECTIONS` as a
   belt-and-suspenders, and/or fix the per-item `fix_plan.md` **template** so it does not invite the
   agent to add checkbox-shaped forward-looking lists.

### Acceptance
- A queue item whose own task box is `[x]` and whose verify gate is green is marked `completed`,
  even when `fix_plan.md` contains unchecked lines under non-current sections.
- The queue gate and the loop exit gate agree on the unchecked count for the same file.
- Add a regression test with a `fix_plan.md` that has one checked current task + several unchecked
  "Next up" items → item completes, does not fail.

---

## BUG 2 — default sandbox strands multi-issue queues (no `gh`, no `npx`, just-in-time spec sync)

### Where
The generated `.ralphrc` `ALLOWED_TOOLS` allowlist (installer / `harness-init`), plus the
spec-sync timing in `ralph-queue`.

### The defect
Two things compound:
- The generated `ALLOWED_TOOLS` contains **no `gh` and no `npx`** (only `git` subcommands, `npm`,
  `pytest`). An agent therefore cannot fetch a GitHub issue body or run a bundler/one-off tool.
- `ralph-queue` materialises `.ralph/specs/issue-<N>.md` **just-in-time**, only when it starts
  processing item N. Items further down the queue have no local spec yet.

When an agent finishes its current item early and (reasonably) glances at the queue to see what's
next, it finds the next item has **no spec and no way to fetch one**, and concludes it is
permanently blocked. In the observed run the agent spent ~6 idle loops re-reporting
"BLOCKED on #3: missing spec, `gh` not invocable" (and burned ~$1+ of model time) before exiting —
even though `ralph-queue` would have synced #3's spec itself once it advanced.

### Fix (recommended)
- **Pre-sync all queued specs up front** when the queue is built (`ralph-queue add`), not
  just-in-time — so no queued item is ever spec-less mid-run.
- **and/or** add read-only `Bash(gh issue view *)` to the default `ALLOWED_TOOLS` so an agent can
  self-serve issue context. (Also consider `Bash(npx *)` — the agent hit `npx expo export` being
  blocked and had to work around it.)
- Reinforce in the default `PROMPT.md` that an agent works **one queue item per invocation** and
  should exit cleanly when its single item's gate is green rather than looking ahead.

### Acceptance
- A multi-issue queue runs to completion without any item reporting "missing spec" for a
  not-yet-started downstream item.
- An agent that finishes its item early exits promptly instead of idling for multiple loops.

---

## BUG 3 (minor) — ralph runs multiple loops per queue item after the task is already done

Even with one queue item, `ralph_loop.sh` kept iterating after the item's task was complete and the
gate was green, giving the agent nothing to do but re-scan and (in the observed run) manufacture
forward-looking notes — which then tripped BUG 1. Consider an early-exit: once the current queue
item's own task box is `[x]` and the verify gate passes, stop looping that item and let the queue
advance.

---

## Repo/installed drift (for whoever picks this up)

The failing gate string (`"reported success but did not finish"`, `"treating as gated"`) exists in
the **installed** `~/.ralph/ralph_queue.sh` but not in this repo checkout at the time of writing —
the checked-out `ralph/` appears to be behind the installed version. Reconcile before patching:
confirm which `ralph_queue.sh` is the source of truth and that the completion-gate block
(lines ~439-466 installed) is present in-repo, then apply the BUG 1 fix there.
