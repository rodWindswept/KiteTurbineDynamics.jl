# RESTART_INSTRUCTIONS.md

## Current state (2026-04-30)

**v4 and v5 campaigns are COMPLETE.** Both sets of 60 islands finished.

**In progress:** `TRPT_AWE_Forum_Report_v3.docx` is being built from v4/v5 results
for external presentation. All campaign figures committed to master (see below).

---

## Campaign results summary

| Campaign | Status    | 10 kW winner | Key change from previous              |
|----------|-----------|--------------|---------------------------------------|
| v2       | Complete  | 2.808 kg     | Euler buckling only — torsionally infeasible |
| v3       | Complete  | 15.435 kg    | Torsional FOS ≥ 1.5 added; cylindrical forced |
| v4       | Complete  | 10.587 kg    | Geometric L/r ring spacing; taper free |
| **v5**   | **Complete** | **11.470 kg** | BEM-coupled rotor radius (self-consistent R from n_lines/Cp) |

n_lines = 8 selected unanimously across all 120 islands (v4 + v5), both 10 kW and 50 kW.

Canonical system: β = 30°, L = 30 m, R ≈ 5 m (fixed in v2–v4), 5.12 m (v5 BEM-derived), n_lines = 5 (canonical) / 8 (optimised), 50 kW rated.

---

## Figures committed to master

**`figures/report/`** (10 figures for the Forum Report):
- `fig_trpt_system.png` — system overview diagram
- `fig_elevation_angle_trade.png` — β vs mass/power trade-off
- `fig_structural_efficiency_profile.png` — FOS profile along shaft length
- `fig_tulloch_wacker_chart.png` — torsional stability criterion visualisation
- `fig_cp_contour.png` — BEM Cp contour over TSR × solidity space
- `fig_nlines_mass_curve.png` — shaft mass vs n_lines (v4 and v5 overlaid)
- `fig_campaign_geometry_evolution.png` — winning geometry across v2–v5
- `fig_campaign_progression.png` — mass progression v2 → v3 → v4 → v5
- `fig_design_space.png` — feasible region in (r_hub, r_bottom) space
- `fig_fos_landscape.png` — Euler + torsional FOS landscape

**`figures/`** (6 additional analysis figures):
- `fig_k_beam_profile_mass.png` — mass by beam profile (circular / elliptical / airfoil)
- `fig_k_nlines_v4_v5.png` — n_lines preference: v4 vs v5 comparison
- `fig_k_Lr_sensitivity.png` — mass sensitivity to target_Lr parameter
- `fig_k_taper_vs_mass.png` — taper ratio vs mass scatter (v4 islands)
- `fig_k_torsional_binding.png` — torsional FOS binding frequency across islands
- `fig_k_v4_v5_mass_comparison.png` — v4 vs v5 mass side-by-side

---

## Regenerating the Forum Report

```bash
# Regenerate TRPT_AWE_Forum_Report_v3.docx from committed figures + data
python3 scripts/produce_awes_forum_report.py

# Or regenerate older reports from their saved CSVs:
python3 scripts/produce_report.py                    # TRPT_Dynamics_Report.docx
python3 scripts/produce_trpt_optimization_report.py  # TRPT_Sizing_Optimization_Report.docx
python3 scripts/produce_cartography_report.py        # TRPT_Design_Cartography_Report.docx
```

---

## What was done: campaign history

### v2 — Phase C–H (April 2026, complete)

60 islands, 12-DoF search, Euler buckling only. Results in `scripts/results/trpt_opt_v2/`.

Post-hoc torsional check: 54/60 islands infeasible. Lightest 10 kW winner (2.808 kg) has
torsional FOS = 0.069 — fails by 22×. All lightweight v2 designs are physically invalid.

### v3 — Phase I (2026-04-22, complete)

60 islands, same grid as v2. Added torsional FOS ≥ 1.5 as hard gate. All 60 designs converged
to `taper_ratio = 1.0` (cylindrical) — torsional constraint forces cylindrical geometry under
uniform ring spacing. Results in `scripts/results/trpt_opt_v3/`.

10 kW winner: 15.435 kg. 50 kW winner: 145.88 kg.

### v4 — Phase J (2026-04-25, complete)

60 islands, 9-DoF. Key change: geometric-series ring spacing (`ring_spacing_v4`) with
constant target L/r ratio. Taper restored as a design variable. Results in
`scripts/results/trpt_opt_v4/`.

10 kW winner: 10.587 kg (−31.4 % vs v3). n_lines = 8 unanimous. target_Lr = 2.0.

Code added:
- `src/ring_spacing.jl` — `ring_spacing_v4()`, `TRPTDesignV4`, `evaluate_design(TRPTDesignV4)`
- `test/test_ring_spacing_v4.jl` — 368 tests, all passing

### v5 — Phase K (2026-04-30, complete)

60 islands, same geometry as v4. Key change: rotor radius R derived self-consistently from
n_lines via BEM Cp model (`src/bem_cp_model.jl`). Closes the aerodynamic coupling loop.
Results in `scripts/results/trpt_opt_v5/`.

10 kW winner: 11.470 kg (−25.7 % vs v3, +8.3 % vs v4). n_lines = 8 unanimous.
The +8.3 % vs v4 is the cost of aerodynamic self-consistency. n_lines = 8 is robust but
requires CFD validation at n > 6 (strip theory validity limit).

---

## Open questions for v6

1. **CFD/panel-method validation of n_lines = 8 Cp** — strip theory not validated above n = 6.
   Blade-to-blade wake interference, solidity blockage unmodelled. Priority before hardware.
2. **Joint β + structural optimisation** — β fixed at 30° throughout v2–v5. Cold-start and
   lift-kite analysis suggest optimum β ≈ 26°. v6 should free β alongside structural params.
3. **Dynamic torsional loading / fatigue** — all campaigns size against static peak envelope.
   Cyclic 1P/2P tether tension loading and S-N fatigue not modelled.

---

## Code reference

| File | Purpose |
|------|---------|
| `src/ring_spacing.jl` | v4/v5 ring spacing, TRPTDesignV4, evaluate_design |
| `src/bem_cp_model.jl` | v5 BEM Cp(σ, TSR) surface + self-consistent R |
| `src/trpt_axial_profiles.jl` | Torsional collapse constraint (v3+) |
| `src/trpt_optimization.jl` | EvalResult struct; v2/v3 objectives |
| `test/test_ring_spacing_v4.jl` | 368 tests for ring_spacing_v4 |
| `scripts/run_v4_campaign.jl` | v4 60-island DE campaign |
| `scripts/run_v5_campaign.jl` | v5 60-island DE campaign |
| `scripts/torsional_collapse_check.jl` | Standalone v2 post-hoc torsional check |
| `scripts/results/trpt_opt_v3/` | v3 results (committed) |
| `scripts/results/trpt_opt_v4/` | v4 results (committed) |
| `scripts/results/trpt_opt_v5/` | v5 results (committed) |
| `DECISIONS.md` | Full derivation and rationale for all campaigns |
