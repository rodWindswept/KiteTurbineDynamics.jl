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
| 10 | The tether drag coefficient is a per-case setting (Ruling 3). Three named values with the printed meaning of each, a reader that returns the name with the value, an unknown name refused, and the drag linear in the coefficient in both the ODE and the screen (the 7.5:1 increment ratio). | `test/test_trpt_drag_coefficient.jl` | GREEN 2026-09-26 | `scripts/ktd-test-one test_trpt_drag_coefficient` |

Found in this cycle: the authority needs a per-segment tether length at every call site.
The placed state carries it as `chord`. The ODE carries it as `line_restlen`. The
state-form gate carries neither and must read it from the system.

## Current item (2026-10-02): project the Betz ceiling onto the wind-normal plane

Ruling: @aero-worker, 2026-10-02 (bank is not elevation; one cos per projection in
the ceiling, cos^2.65 kept in the power). Code verified against the working tree by
@aero-validator; two gate sites, not one (@software-worker found the inlined fifth
site). Test: `test/test_betz_ceiling_projection.jl`.

| # | Behaviour under test | Test file | Colour | Evidence |
|---|---|---|---|---|
| 1 | `main_rotor_bank_projected_area(sys)` is the offset-form projected annulus (`BEM.annulus_area` with the rotor's bank), and the un-fold reproduces the decoder's own `r_hub` to 1e-9. | `test_betz_ceiling_projection.jl` | GREEN 2026-10-02 (§1 geometry) | `scripts/ktd-test-one test_betz_ceiling_projection` — measured r_hub error -4.4e-16 (10-D winner) / 0.0 (14-D winner) |
| 2 | `betz_wind_normal_area(sys, p)` = (projected main + expansion annuli) · cos(elevation) — ONE cos per projection, never summed into an exponent. | `test_betz_ceiling_projection.jl` | RED 2026-10-02 | same run — `betz_wind_normal_area — UndefVarError: UndefVarError` (testset 7 / testset 4 `@test false`) |
| 3 | The per-rotor Betz gate charges the projected area: the inlined `π*(sys.rotor.radius^2-sys.rotor.blade_hub_radius^2)` at `objective_evaluator.jl:871` is retired, and both aggregate ceilings route through the contract. | `test_betz_ceiling_projection.jl` | RED 2026-10-02 | same run — testset 6: `!(occursin("π*(sys.rotor.radius^2-sys.rotor.blade_hub_radius^2)", flat))`, `count("betz_wind_normal_area", flat) >= 2` |
| 4 | `main_rotor_swept_area` stays raw and bank-agnostic — the four call sites (`ring_forces.jl:205/220/285`, `initialization.jl:1323`) are bit-identical before and after. | `test_betz_ceiling_projection.jl` | GREEN 2026-10-02 | same run — testset 5, 2/2 pass on HEAD (the regression pin, not the RED) |
| 5 | The published A_ZY reconciles: `main_rotor_swept_area · cos(30°)` = 30.1175 m² for the island-3 winner, and the correct ceiling basis is 29.5559 m². | `test_betz_ceiling_projection.jl` | GREEN 2026-10-02 | same run — testset 4, 6/7 pass |

Measured leniency of the current gate (raw annulus vs wind-normal projection):
bank-derate winner (bank 10.7399°) **1.9 %** from bank alone, **17.7 %** with the
30° elevation term; pre-derate winner (bank 19.9469°) **6.8 %** / **23.3 %** — the
"~23 %" quoted in the room is the 20°-bank machine. Neither winner has expansion
rotors, so both `A_total`s are the main annulus alone.

## Discovered, not yet written

_Findings from the last cycle that are not rows yet: edge cases, API quirks,
unstated constraints. Move each one to a row above or to an issue before the item
closes._
