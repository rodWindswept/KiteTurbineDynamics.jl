# Handover — closed-form TRPT beam sizing (2026-09-07)

**Status:** the "shed structure" plan is inverted and corrected; a closed-form
beam-sizing architecture is designed, partially implemented and regression-green.
Campaigns are **paused** — do not run one.

## What this session established (the physics, in one paragraph)

Re-gating the 5 kW winner under the **aligned** FoS model (wall floor →
`tube_wall_thickness`) showed the old "FoS 17.2" was an artifact of a
`5e-4/t_over_D` OD floor that inflated the 6.2 mm transmission rings to 18 mm.
The **true transmission-ring FoS is ≈ 1.2** (below the 2.5 floor) — the winner is
**under-strength**, not over-strength. The sizing load case is a **generator
load step** (`k_mppt × 2`, `F_helix ≈ 1278 N/vertex` on the hub segment); the
lull is benign under MPPT; high-wind feather is **deferred** (the ODE aero has
no feather term). The **hub ring is the load case** and is skipped by both
structural paths. Full reasoning: `docs/plans/2026-09-06-closed-form-beam-sizing.md`
(REV 2) and the `[2026-09-06]` entry in `DECISIONS.md`.

## Landed tonight (all in the working tree, uncommitted — see git status)

1. **FoS alignment** (wall floor → `tube_wall_thickness`, single authority):
   `src/trpt_optimization.jl`, `src/ring_element_analysis.jl`, `src/objective_evaluator.jl`,
   `src/types.jl`, `src/initialization.jl`. Fast suite green (2026/2026).
2. **`min_wall_m` swept knob** threaded through `ObjectiveConfig` →
   `build_system_from_v10` → `ring_beam_mass` → `tube_wall_thickness`.
   Runner flags added: `--min-wall-mm`, `--do-min`, `--gen`, `--tag`.
3. **Orientation fix (impl)** in `_evaluate_trpt_design_impl`
   (`src/trpt_optimization.jl`): radii are now treated **ground-first** — single
   rotor thrust/torque at the hub index, cumulative tension = "thrust above"
   (`reverse(cumsum(reverse(...)))`), torsion `tau_above = sum(tau[i+1:end])`.
   Single-rotor output verified **bit-identical** (N_comp 4786.7/24221.3, mass 2.762 kg).
4. **Orientation/off-by-one fix (caller)** in `src/objective_v10.jl` load build:
   reference thrust moved to the hub index; `radii[ri]` → `radii[ri+1]` etc.;
   cumulative reversed. **Known approximations left in place** (see below).
5. **`solve_ring_Do`** added to `src/trpt_optimization.jl` — Euler-buckling
   bisection (single wall authority + single end condition). Smoke: winner's
   measured axial load (73.5 N) → **7.49 mm OD** for FoS 2.5 (vs 6.15 mm giving
   FoS 1.2); the old DLF=1.2 load → 24.98 mm. Sane, end-to-end validated.
6. **Dashboard**: `--v13` flag (`scripts/interactive_dashboard.jl`),
   `"V13 5kW mass-aware winner"` in the V1 dropdown (`src/visualization.jl`),
   and the V1 `n_seg = sys.n_ring - 1` fix.

## ⚠️ Known approximations / gaps to resolve (in priority order)

1. **`objective_v10` caller still has two deeper approximations** (not fixed
   tonight — flagged, not blocking the single-rotor path):
   - the hub rotor is counted once as "reference thrust" *and* once in
     `expansion_params` (double-count);
   - `cumulative_thrust` is computed once *before* the loop, so each rotor's
     `T_above` uses only the hub thrust (stale) — the higher rotors' `F_axial`
     is not folded in.
   Fix these when the multi-rotor structural path is next exercised, and add a
   stacked-rotor tension-monotonicity regression.
2. **`segment_inward_force` is dead code** (`src/trpt_optimization.jl:279`); the
   impl uses unsigned `DLF × T` and loses the signed kink (outward/tension) case
   at the cylinder→cone transition.
3. **Feather factor** in the ODE aero (`ring_forces.jl`) — deferred (separate work).
4. **Hub ring is skipped** by both `ring_element_analysis` (`ring_ids[2:end-1]`)
   and the closed form (`is_buckling_ring = i>1 && i<n`). Add it at `(T_peak, ω=0)`.
5. **Capacity models still differ** (closed form: pin-pin + 0.5 mm wall; FEA:
   fixed-fixed + 2 mm). `solve_ring_Do` defaults to `FixedFixedEnds` to match the
   FEA; the closed-form `evaluate_design` still uses `PinPinEnds` — unify and record ONE K.

## Next steps (REV 2 §8, remaining)

1. `size_beams_closed_form(dec, p_base, cfg)`: reproduce the `objective_v10`
   per-ring load build (thrust → tension → `N_comp`) **on the v5 geometry, with
   the fixed orientation**, then call `solve_ring_Do` per ring. Use the measured
   effective DLF ≈ 0.18 (torque-helix) rather than `DLF = 1.2`.
2. Wire the solved `Do` back into `sys` (drag model + verification FEA see the
   same tube), and **drop the free beam genes x1–x4** from `evaluate_windowed`
   (10-D genome).
3. Re-baseline: fast suite + acceptance suite + a short campaign (runner now has
   `--gen`). One-time FEA verification on the winner **including the hub ring**.

## Key artifacts

- Plan/proposal: `docs/plans/2026-09-06-closed-form-beam-sizing.md` (REV 2).
- Decision: `DECISIONS.md` `[2026-09-06]`.
- Scratch (evidence, not shipped): `scratch/verify_minwall.jl`,
  `scratch/verify_load_split.jl` (axial/bending split + effective DLF),
  `scratch/scenario_sweep.jl` (lull/gust/load-step; feather gap documented),
  `scratch/beam_sizing_proto.jl` (closed-form evaluator + Do_top bisection).

## Suggested skills for the next agent

`ktd-simulation-workflow`, `ktd-headless-analysis`, `ktd-controller-analysis`,
and `tdd` before touching the evaluator wiring.
