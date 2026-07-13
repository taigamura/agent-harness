# Engineering

Skills I use daily for code work.

## User-invoked

Reachable only when you type them (`disable-model-invocation: true`).

- **[ask-matt](./ask-matt/SKILL.md)** — Ask which skill or flow fits your situation. A router over the user-invoked skills in this repo.
- **[autopilot](./autopilot/SKILL.md)** — Fly the whole post-grilling pipeline on its own — PRD → issues → queue/fix-plan → launch ralph — accepting each step's own recommendation without stopping to ask. Pass a model alias (`/autopilot haiku`) to forward it to the ralph loop.
- **[grill-with-docs](./grill-with-docs/SKILL.md)** — Grilling session that also builds your project's domain model, sharpening terminology and updating `CONTEXT.md` and ADRs inline.
- **[triage](./triage/SKILL.md)** — Move issues through a state machine of triage roles.
- **[improve-codebase-architecture](./improve-codebase-architecture/SKILL.md)** — Scan a codebase for deepening opportunities, present them as a visual HTML report, then grill through whichever one you pick.
- **[setup-matt-pocock-skills](./setup-matt-pocock-skills/SKILL.md)** — Configure this repo's issue-tracker choice, triage label vocabulary, and domain doc layout, so the engineering skills that depend on these conventions apply the right ones. Run once per repo.
- **[prototype](./prototype/SKILL.md)** — Build a throwaway prototype — a runnable terminal app for state/logic questions, or several toggleable UI variations.

## Model-invoked

Model- or user-reachable (rich trigger phrasing so the model can reach for them).

- **[to-prd](./to-prd/SKILL.md)** — Turn the current conversation into a PRD and publish it to the issue tracker.
- **[to-issues](./to-issues/SKILL.md)** — Break any plan, spec, or PRD into independently-grabbable issues using vertical slices.
- **[to-fix-plan](./to-fix-plan/SKILL.md)** — Turn ready-for-agent issues into a frankbria ralph `.ralph/fix_plan.md` checklist (the `local` task source the AFK loop works top-to-bottom). The bridge from HITL planning to the ralph loop when the graph is flat.
- **[to-queue](./to-queue/SKILL.md)** — Turn ready-for-agent issues into a frankbria ralph `.ralph/queue.json` — dependency-aware task source for `ralph --process-queue`. Use when the graph has real blockers.
- **[diagnosing-bugs](./diagnosing-bugs/SKILL.md)** — Disciplined diagnosis loop for hard bugs and performance regressions: reproduce → minimise → hypothesise → instrument → fix → regression-test.
- **[tdd](./tdd/SKILL.md)** — Test-driven development with a red-green-refactor loop. Builds features or fixes bugs one vertical slice at a time.
- **[domain-modeling](./domain-modeling/SKILL.md)** — Actively build and sharpen a project's domain model — challenge terms, stress-test with scenarios, update `CONTEXT.md` and ADRs inline.
- **[codebase-design](./codebase-design/SKILL.md)** — Shared discipline and vocabulary for designing deep modules: small interfaces, clean seams, testable through the interface.
