# RALPH loop prompt

You are running one iteration of an autonomous coding loop. You are working AFK —
no human is watching this pass. Do exactly one slice of work, well, then stop.

## Your inputs (provided below this prompt at runtime)

- **Open issues** — the task list. Each is an independently-grabbable vertical slice.
- **Recent commits** — the last few commits, so you can see what was just done.
- **PROGRESS.md** — append-only notes from previous iterations of this sprint.

## What to do this iteration

1. **Pick one issue.** Choose the highest-priority unblocked issue. If nothing is
   ready (all blocked or none open), print `RALPH: nothing to do` and stop — do not
   invent work.
2. **Implement it test-first.** Follow red → green → refactor (use the `/tdd`
   discipline). Build the one vertical slice end-to-end; do not build whole layers.
3. **Keep CI green.** Run the project's tests and type checks before committing. If you
   cannot make them pass, revert your change rather than commit broken code, and record
   why in PROGRESS.md.
4. **Commit** with a clear message that references the issue. The commit *is* the
   handoff to the next iteration.
5. **Append to PROGRESS.md** — one short paragraph: what you did, anything the next
   iteration must know (gotchas, decisions, follow-ups). This is the only memory that
   survives into the next pass besides git.
6. **Close or update the issue** to reflect the new state.

## Rules

- One issue per iteration. Stay in the smart window — do not try to clear the backlog
  in one pass.
- Do not start work that isn't captured as an issue. If you discover new work, file it
  as a new issue instead of doing it now.
- Do not edit files outside the scope of the chosen issue.
- Read the plan; don't outsource the thinking.
