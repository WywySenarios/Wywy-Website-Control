---
name: debug
description: Disciplined debug loop for bugs and performance regressions. Use when the user asks to debug, reports a bug, says something is broken/failing/throwing, describes a performance regression, or when the user asks to "diagnose this".
---

# Debug

A discipline for bugs.

When exploring the codebase, use the project's glossary to get a clear mental model of the relevant modules, and check ADRs in the vicinity.

## Step 1: Feedback loop

Finding a fast, deterministic, agent-runnable pass/fail signal for the bug is the HIGHEST PRIORITY. Use bisection, hypothesis-testing, and instrumentation to find that signal. Looking at the code is **NEVER** enough.

This is the MOST important part of debugging. **You should spend 90%+ of your effort here.**

### Constructing a feedback loop. Try them in this order
1. Create a **failing test**: unit, integration, e2e.
2. **cURL script** against a dev server
3. **CLI invocation with a fixed input**, comparing stdout against a known-good snapshot
4. **Headless browser script** (playwright)
5. **Replay a captured trace.** Save a real network request/payload/event log to disk and replay it through the code path in isolation.
6. **Throwaway harness.** Spin up a minimal subset of hte system (one service, mocked deps) that exercises the bug codepath with a single function call
7. **Fuzz test.** If a bug does not always appear, run 999 random inputs and look for the failure mode.
8. **Bisection.** If a bug appears between two known states (commit, dataset, version), automate "boot at state X, check, repeat" so you can bisect the bug.
9. **Human-in-the-loop bash script.** Last resort. If a human must click, drive them with `./hitl.sh` so the loop is still structured. Captured output feeds back to you.

### Iterate on the loop itself
Treat the loop as software. Once you have a working loop, ask:

* Can I make it faster?
* Can I make the signal sharper?
* Can I gain more detailed information?
* Can I make it more determinstic?

### Non-deterministic bugs

The goal here is to maximize reproduction rate. Loop the trigger 99 times, parallelize, add stress, narrow timing, ijnect sleeps. A 50% bug is debuggable, 1% is not. Keep raising the rate until it is debuggable.

### When you cannot build a loop

Stop and say so explicitly. List what you tried. Ask the user for: (a) access to whatever environment reproduces it, (b) a captured artifact (HAR file, log dump, core dump, screen recording with timestamps), or (c) permission to add temporary production instrumentation. Do not proceed to hypothesise without a loop.

Do not proceed to Phase 2 until you have a loop you believe in.

## Step 2: Reproduce

Run the loop. Watch the bug appear.

Confirm:

- [ ] The loop produces the failure mode the **user** described — not a different failure that happens to be nearby. Wrong bug = wrong fix.
- [ ] The failure is reproducible across multiple runs (or, for non-deterministic bugs, reproducible at a high enough rate to debug against).
- [ ] You have captured the exact symptom (error message, wrong output, slow timing) so later phases can verify the fix actually addresses it.

Do not proceed until you reproduce the bug.

## Step 3: Hypothesise

Generate **3–5 ranked hypotheses** before testing any of them. Single-hypothesis generation anchors on the first plausible idea.

Each hypothesis must be **falsifiable**: state the prediction it makes.

> Format: "If <X> is the cause, then <changing Y> will make the bug disappear / <changing Z> will make it worse."

If you cannot state the prediction, the hypothesis is a vibe — discard or sharpen it.

**Show the ranked list to the user before testing.** They often have domain knowledge that re-ranks instantly ("we just deployed a change to #3"), or know hypotheses they've already ruled out. Cheap checkpoint, big time saver. Don't block on it — proceed with your ranking if the user is AFK.

## Step 4: Instrument

Each probe must map to a specific prediction from Step 3. **Change one variable at a time.**

Tool preference:

1. **Debugger / REPL inspection** if the env supports it.
2. **Targeted logs** at the boundaries that distinguish hypotheses.
3. Never "log everything and grep".

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup at the end becomes a single grep. Untagged logs survive; tagged logs die.

**Perf branch.** For performance regressions, logs are usually wrong. Instead: establish a baseline measurement (timing harness, `performance.now()`, profiler, query plan), then bisect. Measure first, fix second.

## Step 5: Fix + regression test

Write the regression test **before the fix** — but only if there is a **correct seam** for it.

A correct seam is one where the test exercises the **real bug pattern** as it occurs at the call site. If the only available seam is too shallow (single-caller test when the bug needs multiple callers, unit test that can't replicate the chain that triggered the bug), a regression test there gives false confidence.

**If no correct seam exists, that itself is the finding.** Note it. The codebase architecture is preventing the bug from being locked down. Flag this for the next phase.

If a correct seam exists:

1. Turn the minimised repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 feedback loop against the original (un-minimised) scenario.

## Phase 6 — Cleanup + post-mortem

Required before declaring done:

- [ ] Original repro no longer reproduces (re-run the Phase 1 loop)
- [ ] Regression test passes (or absence of seam is documented)
- [ ] All `[DEBUG-...]` instrumentation removed (`grep` the prefix)
- [ ] Throwaway prototypes deleted (or moved to a clearly-marked debug location)
- [ ] The hypothesis that turned out correct is stated in the commit / PR message — so the next debugger learns

**Then ask: what would have prevented this bug?** If the answer involves architectural change (no good test seam, tangled callers, hidden coupling) hand off to the `/improve-codebase-architecture` skill with the specifics. Make the recommendation **after** the fix is in, not before — you have more information now than when you started.
