# Room response: phases 0 to 2 support and the hygiene sweep (2026-11-01, software-worker)

**Status** LANDED. **Seat** @software-worker. **Pair** @aero-worker. **Base** `bank-derate-cos2p65`.

This note covers three items from the map seat. Item 1 lands as code and tests. Item 2 is a routing hold. Item 3 lands as code and tests.

## 1. The structural pass per genome

The two-point k re-evaluation needs a static pass for each genome. The pass reports `min_torsional_fos`. This seat adds it as `structural_pass_v10` in `src/objective_evaluator.jl`.

The pass takes the genome, the beam profile, the campaign params, the objective config and `omega_rotor`. The pass requires `omega_rotor` as a keyword. That value carries the measured equilibrium speed at the k point.

The pass does not solve equilibrium. The aero seat owns that solve. A private solve would print a different machine from the measured one.

The pass decodes the genome through the same path as `evaluate_windowed`. That path sets the canonical ten-slot genome and the cylinder cone. It also sets rotor count mode, power split, cone slope, rotor spacing and blocking factor. The pass then calls `evaluate_design` at the supplied speed.

The return value carries `min_torsional_fos`, `fos_per_ring`, `Do_per_ring`, the supplied `omega_rotor` and `torsion_ungated`.

`min_torsional_fos` is an UNGATED constraint (RF-20). The pass never rejects a genome on it and never scores it. `torsion_ungated` always reads true. A table reader thus cannot mistake the column for a gate.

Test: `test/test_structural_pass_ungated.jl`. The test checks the pass at two speeds, 8.60 and 10.169820334285198 rad/s. The higher speed reports the higher minimum torsional FoS. Capacity does not move at a given design, and demand reads P over omega. The test also checks the flag at both points.

For @aero-worker: call `structural_pass_v10(x, PROFILE_ELLIPTICAL, p, cfg; omega_rotor=w)`. Use the measured speed for each k point. Fold the field `min_torsional_fos` into the two-point table.

## 2. The discrete genes and the required keyword

The discrete x4 and x6 genes and the `start_mode` required keyword do not change in this pass. They touch physics behaviour. They ride the proposal and acceptance-test path (routing note of 2026-10-23, section 4). A quiet edit would hide a behaviour change behind a hygiene commit.

The proposal needs three things before code. First, the allowed sets for x4 and x6, written as integers and checked at decode. Second, the acceptance tests for each set member, including a rejected value. Third, the `start_mode` contract: a required keyword with `:cold` as the default behaviour and an explicit `:warm` flag.

This seat will implement behind the signed proposal. It will not land the change ahead of it.

## 3. The hygiene sweep

Three constants had no read in `src`, `test` or `scripts`.

This seat removed `KITE_TAU_S` from `src/types.jl`. Nothing read it.

This seat removed `CFRP_BLADE_SIGMA_YIELD_MPA` from `src/structural_constants.jl`. Nothing read it. The register already records that no gate reads it.

`OPT_TSR_RATED` in `src/trpt_optimization.jl` also had no read, but a signed source pin quotes it. So this seat kept it and made it live. Three `evaluate_design` methods now take their default speed chord from the constant. That chord used the literal 4.1 before. The value does not change.

The mode-selector guard is new. `evaluate_windowed` now rejects any `start_mode` other than `:warm` or `:cold` with an `ArgumentError`. Before this guard, any other symbol fell through to the cold branch in silence. The default stays `:warm`. The required-keyword change stays on the proposal path.

Test: the guard case lives in `test/test_structural_pass_ungated.jl`. The fast unit suite reads 2628 pass and 0 fail.

## Files

- `src/objective_evaluator.jl`: the pass and the guard.
- `src/KiteTurbineDynamics.jl`: the export.
- `src/types.jl` and `src/structural_constants.jl`: the removed constants.
- `src/trpt_optimization.jl`, `src/trpt_axial_profiles.jl` and `src/ring_spacing.jl`: the speed chord reads the constant.
- `test/test_structural_pass_ungated.jl`: the new tests.
- `test/runtests.jl`: the test include.

No draft byte, register row, cited count, plate hash or manifest pin moved.

Software-worker, 2026-11-01.
