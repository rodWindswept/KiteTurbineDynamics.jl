# Handover — KTD Calibration Session 2026-08-11

## Session goal

Calibrate the Kite Turbine Design Evolution Optimiser against:
- Prior truth from 1.5kW Daisy campaign data
- Physics validation up to 50kW
- Coherent objectives, bounds, and evaluator consistency

## What was done

### Code changes (committed to local desktop, NOT pushed)

| File | Change |
|------|--------|
| `src/objective_evaluator.jl` | Added `fos_cap=16.0` to `ObjectiveConfig`, `P_available(v)` Betz gate, `min_ring_fos()` helper |
| `src/objective_v12.jl` | FoS hard cap at 16 (returns `Inf`), added `objective_v12_ramp()` adapter |
| `src/objective_evaluator_ramp.jl` | **New file** — `evaluate_ramp()` using RampController IDLE→RAMPING→HOLDING |
| `src/KiteTurbineDynamics.jl` | Include + export for ramp evaluator |
| `test/test_objective_v12.jl` | 6 new tests for FoS cap behavior |
| `CONTEXT.md` | Fixed left-flank claim, updated DLF entry, added P_available gate, ramp evaluator |
| `DECISIONS.md` | 3 new entries: FoS cap, Betz gate, ramp evaluator |
| `docs/plans/dashboard-objective-config-prd.md` | **New file** — PRD for exposing ObjectiveConfig in dashboard |
| `scripts/daisy_ramp_test.jl` | Daisy ramp test attempts (all blocked — see below) |
| `scripts/daisy_ramp_settle.jl` | Settle-based ramp test (blocked) |

**Test suite:** 1902 assertions, all pass after revert of wrong all-rings braking fix.

**NOT pushed to remote.** These are desktop-local changes pending Rod's laptop review.

### Key physics findings

1. **DLF = 1.2 is a lumped envelope**, not a magic constant. Computed from ODE stats (`DLF_peak × 1.10`) in `trpt_optimization.jl`, calibrated on 10kW system across 6 load scenarios. The value provides ~60% margin over worst aero-only case. Rod identified that `F_inward = DLF × T_line_axial` is an odd proxy — what we really need is ring beam compression (N_comp), not a lumped factor based on axial line tension. The DLF assumes proportionality that doesn't hold at zero twist.

2. **FoS steering**: Current V12 uses FoS target 3.0 (gentle linear above, steep quadratic below) and FoS hard floor 1.5 (Inf rejection). New FoS hard cap at 16 (Inf rejection above) replaces the old "same penalty as at cap" approach — Rod's directive: FoS > 16 should EXCLUDE the design from progressing, not just give same penalty.

3. **k_mppt controller consistency**: The DE evaluator (`with_k_bracket`) uses a 3-point k bracket with fixed k during the scoring window. The dashboard uses RampController (IDLE→RAMPING→HOLDING) with dynamic k. They are different k-selection paths. The new `evaluate_ramp()` bridges this gap by using the RampController in the evaluator.

4. **`settle_to_operational_state` vs `run_canonical_sim!` mismatch** (CRITICAL FINDING): Diagnostic shows `settle_to_operational_state` produces a state where `multibody_ode!` computes ω_dot up to 61.7 rad/s² — the system was never at ODE equilibrium. The settle uses an analytical equilibrium scan + analytical preload that doesn't match the ODE's force model. For 50kW the mismatch is manageable; for Daisy (1.5kW) it's catastrophic (ω collapses from 234→3 rpm within 2 seconds).

5. **Daisy calibration**: Sweep shows consistent ~20% under-prediction vs Tulloch reference across 5-11 m/s. This is systematic bias, not random — the simulation tracks the v³ power curve shape correctly but is offset. The under-prediction is likely from the static equilibrium solver (known to under-predict by ~3.3× per CONTEXT.md) combined with high CDt=2.7 tether drag.

6. **Semi-implicit braking** (commit `d285139`): Ground-ring-only fix for k·ω² instability is correct physics — only the ground ring has a generator. "Extending to all rings" would be an artificial mid-air brake. The residual torsional chain instability noted in the commit message remains unaddressed.

### Ramp controller evaluator architecture

```
evaluate_ramp(x, beam_profile, p, cfg; fitness_fn)
  → decode 14-D genome (k_mppt NOT in genome)
  → warm pre-solve (static equilibrium + settle_to_equilibrium)
  → RampController chunked loop (2s ODE chunks, update_ramp!)
  → 60s scoring window (ramp continues, k never frozen)
  → Betz gates + stationarity + fitness_fn → ObjectiveResult
```

V12 adapter: `objective_v12_ramp(x, beam_profile, p; cfg=..., spoke=...)`

### What's blocked

- **Daisy ramp test**: Cannot test `evaluate_ramp` on Daisy because the Daisy builder produces a system directly (no genome vector). Would need to encode Daisy as a 14-D genome to use the evaluator API. All standalone test scripts failed because they used `settle_to_operational_state` instead of the warm-start protocol.

- **`run_canonical_sim!` torsional chain fix**: Diagnosed but not implemented. The fix needs to address the settle/ODE equilibrium mismatch or add damping to the torsional modes. This is a separate engineering task.

## Next session: 50kW ramp calibration campaign

### Objective
Run 10-50 genome evaluations through `evaluate_ramp` to:
1. Validate the ramp evaluator produces sensible results
2. Capture ramp-converged k_mppt values
3. Compare ramp vs bracket results to calibrate the λ²-scaling factor
4. Establish the baseline for fast-bracket DE campaigns

### Script: `scripts/ramp_calibration_campaign.jl`

See separate file. Launch with:
```bash
julia --project=. scripts/ramp_calibration_campaign.jl
```

Output: `scripts/results/ramp_calibration/ramp_campaign_v1.csv` with provenance headers.

### Expected runtime
~10-30 minutes per eval × 10-50 evals = 2-25 hours. Use `background=true` + `notify_on_complete`.

### Git state reminder
Desktop has uncommitted changes. Rod's laptop is authoritative. Pull + review before pushing any desktop changes.
