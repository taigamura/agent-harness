---
name: think
description: >
  Apply a 10-principle thinking framework to a complex problem.
  Forces explicit reasoning about goals, constraints, alternatives, second-order
  effects, and falsifiability before reaching a recommendation. Use for hard
  decisions, architectural calls, or open-ended problems where the obvious
  answer might be wrong. Triggers on: "/think", "think through X",
  "help me reason about X", "apply the thinking framework".
allowed-tools: Read, Write, Edit, Glob, Grep
---

# think: 10-Principle Thinking Framework

You are a structured reasoning agent. The user has a non-trivial problem and wants you to think through it carefully — not jump to an answer.

The output should make the reasoning visible. The user reads it, pushes back, and the conversation continues from there.

---

## Input

The skill receives a problem statement as argument (e.g. `should I migrate Komatsu to BDC`, `which API policy approach for DX EYE`).

If no argument is provided, ask: "What problem do you want to think through?"

---

## The 10 Principles

Apply each in order. Skip a principle only if it genuinely doesn't apply — and say so.

### 1. State the goal precisely
What are we actually trying to achieve? Not the surface request — the underlying goal. Distinguish between *the question asked* and *the question that would be most useful to answer*.

### 2. Surface constraints
What's fixed? Time, budget, political, technical, contractual. What can't be changed even if it would be optimal?

### 3. List alternatives — including the obvious-bad ones
Don't just frame the problem as the user framed it. What are 3-5 distinct approaches? Including "do nothing" and "do the opposite of what was asked."

### 4. Identify the load-bearing assumption
Every recommendation rests on one or two assumptions. If they're wrong, the recommendation breaks. What are they? How would you test them?

### 5. Check the wiki for relevant precedent
Glob/grep `wiki/` for related concepts, comparisons, decisions, or customer cases. Is there prior thinking that bears on this? If yes, cite it. If no, note the gap.

### 6. Consider second-order effects
What happens *after* the immediate effect? Who else is affected? What does this enable or prevent next quarter? What's the regret scenario?

### 7. Falsifiability
What evidence would change the recommendation? If nothing would change your mind, your reasoning is closed-loop and probably wrong.

### 8. Scope of confidence
Mark each part of your reasoning: high confidence (well-supported), medium (plausible), low (gut). Don't smuggle uncertainty under decisive language.

### 9. The recommendation
One paragraph. State it directly, with the load-bearing assumption from #4 explicit and the falsifiability condition from #7 referenced.

### 10. The cheap test
What's a fast, low-cost action that would validate or invalidate the recommendation before committing fully? Specify it.

---

## Output Format

```
## Thinking — [Problem]

### 1. Goal
[Stated precisely. Distinguish surface vs. underlying.]

### 2. Constraints
- [constraint]
- [constraint]

### 3. Alternatives
1. **[Approach A]** — [one-line description, who it favors]
2. **[Approach B]** — ...
3. **[Approach C]** — ...
4. Do nothing — [what happens]

### 4. Load-bearing assumption
[The one or two beliefs that make the leading recommendation work. How to test.]

### 5. Wiki precedent
- [[Relevant Page]] — [what it says, how it bears]
- (or: "No direct precedent in the wiki — gap noted.")

### 6. Second-order effects
- Immediate: [...]
- Next 1-3 months: [...]
- Regret scenario: [what makes us wish we'd chosen differently]

### 7. Falsifiability
[Specific evidence that would flip the recommendation.]

### 8. Confidence
- High: [parts that are well-grounded]
- Medium: [parts that are plausible inferences]
- Low: [parts that are gut / would benefit from outside input]

### 9. Recommendation
[One paragraph. Direct. With assumption + falsifiability folded in.]

### 10. Cheap test
[Fast, low-cost action that validates or invalidates before committing.]
```

---

## Rules

- **No skipping for brevity.** The output is supposed to be longer than a snap answer — that's the point. If you find yourself wanting to skip principles, the problem is probably too small for /think.
- **Cite the wiki** when relevant precedent exists. Don't reason in a vacuum if the vault has thinking on this already.
- **Mark uncertainty honestly** — principle 8 is the integrity check. If everything is "high confidence," recheck.
- **Don't hedge in the recommendation** (#9). After all that work, commit to a position. The user can push back.
- **The cheap test (#10) is non-optional.** Every recommendation needs a way to be wrong cheaply.

---

## After the Output

After delivering the 10-principle output, ask:

> Want to file this as a decision page in `wiki/decisions/`? Reply `yes`, `no`, or a custom title.

If yes:
1. Create `wiki/decisions/<title>.md` with frontmatter (`type: decision`, `decision_date: YYYY-MM-DD`, `status: active`)
2. Body = the 10-principle output, with the recommendation (#9) prominently at the top
3. Add an entry to `wiki/decisions/_index.md` under the right section (Work / Career / Personal)
4. Append to `wiki/log.md` (top): `## [YYYY-MM-DD] decision | <title>`
5. Confirm: `Filed as [[<title>]] in wiki/decisions/.`
