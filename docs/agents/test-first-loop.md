# The test-first loop

Applies to every behaviour change in this repo. The suite split (fast unit tests
against slow acceptance tests) stays as DECISIONS.md [2026-08-20] set it.

## 1. Write the test list first

`docs/plans/test_list.md` holds the live list for the current item. Add a row for
each behaviour before the first test. Update the list at the end of each cycle with
the edge cases and the unstated requirements that the cycle found.

The list is the spec. The written tests are not. A passing suite proves only that
the existing tests pass. The audit of 2026-09-08 found 8 of 48 test files asserting
code that the v13 chain never calls, and those files were green.

## 2. Watch the test fail

A new guard is not red until it fails for the expected reason. Run one file:

```bash
scripts/ktd-test-one test_blade_mass_law
```

That takes seconds. The full fast suite takes about 3.5 minutes. The high cost of
one file is why a failing test was often written without ever being watched.

Record the first failure line in the test list row. That line is the evidence.

## 3. Then make it pass

Change only enough code to pass the test. Run the one file again. Run the fast
suite before the commit.

## 4. Refactor the new hunks

Ruling of 2026-09-24: this repo runs the refactor step inside the loop, after
GREEN. The `tdd` skill puts refactoring at the review stage, and this file
overrides it.

Read the hunks this cycle added. Name any smell from the `code-review` baseline
that is present in them: duplication, a long function, a mysterious name, high
coupling, a primitive standing in for a concept. Fix the one you named. Keep the
tests green.

Scope the pass to the new hunks. A wider refactor is its own commit and its own
cycle.

## 5. A re-baseline is a decision

A test changed to match new behaviour needs a DECISIONS.md entry that states the
reason. An unexplained re-baseline is a moved goalpost. The audit of 2026-09-08
named that class.

## 6. The commit carries the evidence

When a `src/` change lands with no test change, say why in the commit body. A pure
refactor or a comment fix is a good reason.

## Where each piece lives

| Piece | Path |
|---|---|
| The live test list | `docs/plans/test_list.md` |
| One-file runner | `scripts/ktd-test-one` |
| Commit-time cue | `check-tdd-evidence.py`, wired in `.githooks/pre-commit` |
| Edit-time cue | `~/.hermes/agent-hooks/tdd-cue.py`, a `pre_llm_call` shell hook |
| Playbook for both cues | Hermes skill `habit-hook-tdd` |
| The audit behind this file | `docs/reports/2026-09-24-tdd-application-audit.md` |
