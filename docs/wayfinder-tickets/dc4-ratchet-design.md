# dc4 — Ratchet design

> Part of [Decisions Conformance Audit](../wayfinder-decisions-conformance.md) · `wayfinder:grilling` · **blocked by dc2**

## Question

What makes a decision checkable, and what enforces it?

Prose tells. A test enforces. dc2 produces the list of rulings that are **untested**,
and that list is the input here. The question is what to do with each one, and what
convention stops the next ruling from arriving untested.

## Decisions to take

1. **Which rulings earn a guard.** A guard costs a test and a maintenance tail. FoS
   floors, load-path topology, and the annulus sizing rule protect money and safety.
   A tooling preference does not. Propose the cut, and let Rod rule it.
2. **Guard form.** Candidates, with prior art in this repo:
   - An assertion in `test/test_documented_claims.jl`, which already guards
     externally-quoted numbers and states that a failure means a claim went stale.
   - A unit test beside the code, as `test_blade_mass_law.jl` does for the mass law.
   - A pre-commit sensor in `.githooks/pre-commit`, which blocks on STE and provenance
     breaches and now **warns** on a `src/` change with no test change
     (`check-tdd-evidence.py`, v0.2.0, 2026-09-24).
   - A line in `docs/agents/stale-phrases.md`, which the currency sweep scans.
3. **The declaration convention.** A ruling should declare its own check at the moment
   it is written: the invariant, the test that holds it, and the record it replaces.
   Decide the field names and where they live.
4. **Warn or block.** The TDD cue warns, because a pure refactor legitimately touches
   `src/` alone. Decide the same question per guard.

## Prior art to fold in

The parallel session of 2026-09-24 built a test-first loop and a sensor for it. Use it,
do not duplicate it:

- `docs/reports/2026-09-24-tdd-application-audit.md` — the four-element frame, and its
  verdict that the two load-bearing elements (a dynamic test list, an observed RED) were
  missing.
- `docs/agents/test-first-loop.md`, `docs/plans/test_list.md`, `scripts/ktd-test-one`.
- `.githooks/pre-commit` v0.2.0 and `check-tdd-evidence.py`.

Its element 1, the dynamic test list, is the same idea as this ticket's element 3: a
place where required behaviour is written before it is built.

## Output

A short design note, `docs/agents/decision-guards.md`, plus the first guard landed and
watched to fail for the right reason.

## Sizing

One session, after dc2 reports.
