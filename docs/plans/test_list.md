# test_list.md — the live test list

**Rule.** Write this list before the first test. Update it at the end of every
cycle with the edge cases and the unstated requirements that the cycle found. The
list is the spec for the current item. The written tests are not.

**Scope.** One item at a time, named below. When the item lands, the ticked list
stays in git history and this file resets for the next item.

**Colour.**

- `TODO` — the row exists, the test does not.
- `RED` — the test exists and fails. The row carries the failure reason.
- `GREEN` — the test passes. The row names the command that proves it.

| # | Behaviour under test | Test file | Colour | Evidence |
|---|---|---|---|---|
| 1 | _example row: a non-finite FoS cannot pass the hard floor_ | `test_fos_guard.jl` | GREEN 2026-08-22 | `scripts/ktd-test-one test_fos_guard` |

## Current item

_Name the item from `docs/plans/ACTIVE.md`. No rows yet._

## Discovered, not yet written

_Findings from the last cycle that are not rows yet: edge cases, API quirks,
unstated constraints. Move each one to a row above or to an issue before the item
closes._
