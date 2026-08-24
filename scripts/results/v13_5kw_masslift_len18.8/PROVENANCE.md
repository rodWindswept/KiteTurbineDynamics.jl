# PROVENANCE — v13_5kw_masslift_len18.8

- **Campaign:** 5 kW v13 DE, mass-aware constant-tension lift REDO
- **Runner:** scripts/run_v13_5kw_masslift.jl
- **Physics era:** post-4ce9fd0_daisy-anchored-5kw  (2026-08-22: Daisy-anchored base params, r_bottom clamp fix, lifter mass excluded from tension, annulus-aligned Betz gates, span^3 blade-mass law (m = 0.420·(decoded span/1.0)^3) with the 420 g anchor, hub double-model removed, honest window relax 10 + window 40, k=2.24)
- **Launch git HEAD:** edd7f5f720bb6959c41a83eae025ca003ecca871
- **Regime:** `lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true)`
  — vertical lift = 1.5 × m_airborne × g, m_airborne = expansion_airborne_mass(sys, p;
  include_lifter=false) per genome (lifter's own mass does NOT drive the tension,
  Rod 2026-08-21); line tension = F_vert / sin(70°), FLAT at all wind speeds
  (modulated lifter, no v² scaling).
- **Base params:** params_daisy() (measured Tulloch anchor) scaled 1.5 → 5 kW via mass_scale.
- **Baseline (fixed-rotary regime):** scripts/results/v13_5kw_len18.8/
  + lift_tension_retrospective.csv (rotary_lifter_default(), wind-dependent tension)
- **Identical to first campaign:** seeds (seed_genome(5.0)), RNG (Random.seed!(42+island-1)),
  tight bounds, v13 ObjectiveConfig (tail5, no ceiling penalty, FoS 1.5/1.5,
  kickstart 0, k_mppt = p.k_mppt), length 18.8 m, DE sizing 10×3×30.
- **Gate alignment:** ode_gate_v13.jl uses lift_for; regate + ladder inherit via gate_design.
- **Plan:** docs/plans/2026-08-18-5kw-mass-aware-lift-redo.md
