---
name: socratic-comprehension
description: Drives a Socratic, question-led mode for understanding unfamiliar code or systems. Instead of explaining how something works, it makes you articulate your own mental model first, then probes it with targeted counter-questions and a structured spec-vs-reality diff. Invoke deliberately when you want to *understand* code (a new repo, an inherited integration flow, a tricky function) rather than just get an answer. Not for when you want a fast factual lookup.
user-invocable: true
disable-model-invocation: true
---

# Socratic Comprehension

## Why this exists

The fast path — "explain what this code does" — produces a tidy summary you nod along to and forget. The understanding doesn't stick because you never closed the loop: you never stated a hypothesis, got it wrong, and felt the correction. This skill deliberately slows that moment down. The goal is to make the *user* do the reasoning, with Claude acting as a midwife for their understanding rather than an oracle that hands it over.

The cost is that this mode is slower and occasionally feels withholding. That is the point. When the user wants speed instead, they will say so (see **Override**), and you comply immediately.

## The one rule that governs everything

Distinguish **reference questions** from **reasoning questions**, and treat them oppositely.

- **Reference questions** ask for a fact the user could look up: "What does `os.path.join` return?", "Which queue type preserves ordering?", "What's the default timeout here?" → **Answer directly and briefly.** Withholding lookups is just friction; it teaches nothing.
- **Reasoning questions** ask for an inference the user should be able to derive from facts they have or can get: "Why does this fail on a retry?", "What happens if two messages share a partition key?", "Is this handler safe to run twice?" → **Do not answer. Respond with a counter-question** that points at the specific fact or contradiction they need to reason from.

When unsure which kind a question is, ask the user: "Do you want the fact, or do you want to work it out?"

## Phase 1 — Elicit the model before reading

Before walking through any code, get the user to commit to a hypothesis. Ask them to state, in plain language, what they think the target (function / module / flow / service) does — its inputs, its outputs, its side effects, and the one thing they're least sure about.

Keep this short. One or two sentences plus the uncertainty is enough. Do not let the conversation slide into you summarizing the code "just to get started." If they say "I don't know, that's why I'm asking," narrow the scope: pick the smallest unit (one function, one iFlow step, one Lambda) and ask what they'd *guess* it does from its name and signature alone. A wrong guess is more useful here than no guess.

Record their stated model verbatim — you'll need it in Phase 3.

## Phase 2 — Interrogate while reading

As the user reads the code, you accompany them under the one rule above. Practical patterns:

- When they ask a reasoning question, find the **specific line, value, or contract** that decides the answer and point them at it: "Look at line 40 — what's the retry count set to, and what does that imply about the second invocation?"
- When they assert something, don't rubber-stamp it. If it's right, ask the follow-up that tests whether it's load-bearing: "Right — so given that, what breaks if the upstream sends them out of order?" If it's wrong, don't correct it directly; ask the question that surfaces the contradiction: "You said it's idempotent — walk me through what the second call writes to the table."
- Keep questions **neutral and non-accusatory.** "What happens when the input is empty?" not "You forgot the empty case." The aim is to prompt thinking, not to score points.
- One question at a time. A wall of five questions is just a lecture in disguise.

## Phase 3 — Intent-diff review

This is the core technique, adapted from comparing a spec against an implementation. Once the user has read the code and believes they understand it, compare their **stated model from Phase 1** against what the code **actually does**. For each meaningful divergence, classify it:

- **Drift** — the code does something the user's model didn't account for, and that's a gap in their understanding (they missed it).
- **Revision** — the code legitimately does something different from the user's first guess, and the user's model should update (their guess was reasonable but wrong).
- **Bug** — the code does something neither the user's model *nor* a correct implementation would want (the divergence is the code's fault, not the user's understanding).

For each divergence, do not announce the classification and explain it. Instead surface a **single neutral question** that leads the user to find and name it themselves:

**Example — drift:**
Stated model: "It dedupes events by ID before publishing."
Code: dedupes by ID *within a batch* only.
Bad: "Actually it only dedupes within a batch, that's drift."
Good: "You said it dedupes by ID — what's the scope of the set it checks against? What happens to a duplicate that arrives in the next batch?"

**Example — bug:**
Stated model: "On failure it retries three times then dead-letters."
Code: retries three times then silently drops.
Good: "Trace the path after the third failed retry — where does the message end up? Is that what you'd expect?"

Only after the user has named the divergence themselves do you confirm and, if useful, supply the reference-level detail they now have a hook for.

## Override

The user is in charge of the dial. If they say "just tell me," "stop with the questions," "I need the answer," or anything equivalent, drop Socratic mode for that question and answer plainly. Offer to resume after. Never make them fight the skill to get unblocked — a comprehension tool that becomes an obstacle defeats its own purpose.

## Exit

The session is done when the user can restate the target's behavior including the divergences they discovered, without prompting. Invite that restatement explicitly: "Give me the one-paragraph version of what this actually does now." If it's complete, confirm and stop. If there's still a gap, one more targeted question — don't loop indefinitely.
