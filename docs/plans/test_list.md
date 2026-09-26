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

**Correct the TRPT over-twist criterion to Tulloch (4.34).**
Plan: `docs/plans/2026-09-25-trpt-tulloch-criterion-correction.md`.
Audit: `docs/validation/2026-09-25-trpt-tulloch-model-crosscheck.md`.

| # | Behaviour under test | Test file | Colour | Evidence |
|---|---|---|---|---|
| 1 | δcrit is (4.34). It reproduces Fig 5.25, the 90° asymptote and the 180° boundary. | `test_trpt_twist_limit.jl` | GREEN 2026-09-25 | `scripts/ktd-test-one test_trpt_twist_limit` |
| 2 | The δcrit angle is the torque maximum of the operating curve. | `test_trpt_twist_limit.jl` | GREEN 2026-09-25 | same run |
| 3 | A tether shorter than the sum of its ring radii has no limit at all. | `test_trpt_twist_limit.jl` | GREEN 2026-09-25 | same run |
| 4 | Capacity follows (4.31) at δcrit, in both held-quantity forms. | `test_trpt_twist_limit.jl` | GREEN 2026-09-25 | same run |
| 5 | The ODE torque ceiling equals the authority on a wound segment. | not written | RED | WP2 owes this test |
| 6 | An ODE window holds 70-100° twist with no ceiling. | not written | RED | WP3b. This test decides the ϕ < 2 rule |
| 7 | The moment of a force about the shaft axis, against hand cases. | `test_trpt_drag_torque.jl` | GREEN 2026-09-26 | `scripts/ktd-test-one test_trpt_drag_torque` |
| 8 | The tether drag moment reaches the ring spin. Every intermediate ring gains it, it opposes the rotation, and it grows with the square of the spin rate. | `test_trpt_drag_torque.jl` | GREEN 2026-09-26 | same run |
| 9 | The drag torque at the operating point: it reaches the spin, opposes the rotation, stays below the rotor torque, and sits in the large-radius rings. Baseline −22.771 N·m, 7.8 % of the rotor torque, ω 13.452 rad/s. | `test/test_trpt_drag_torque_balance.jl` | GREEN 2026-09-26 | `scripts/ktd-test-one test_trpt_drag_torque_balance`, and in `test/acceptance_runtests.jl` |

Found in this cycle: the authority needs a per-segment tether length at every call site.
The placed state carries it as `chord`. The ODE carries it as `line_restlen`. The
state-form gate carries neither and must read it from the system.

## Discovered, not yet written

_Findings from the last cycle that are not rows yet: edge cases, API quirks,
unstated constraints. Move each one to a row above or to an issue before the item
closes._
