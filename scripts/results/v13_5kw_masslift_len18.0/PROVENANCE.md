# PROVENANCE — v13_5kw_masslift_len18.0

- **Campaign:** 5 kW v13 DE, mass-aware constant-tension lift REDO
- **Runner:** scripts/run_v13_5kw_masslift.jl
- **Physics era:** post-428f491_mass-aware-const-tension_ON
- **Launch git HEAD:** unknown
- **Regime:** `lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true)`
  — vertical lift = 1.5 × m_airborne × g, m_airborne = expansion_airborne_mass(sys, p)
  per genome; line tension = F_vert / sin(70°), FLAT at all wind speeds
  (modulated lifter, no v² scaling). Lift kite mass NOT in the tension calc.
- **Baseline (fixed-rotary regime):** scripts/results/v13_5kw_len18.0/
  + lift_tension_retrospective.csv (rotary_lifter_default(), wind-dependent tension)
- **Identical to first campaign:** seeds (seed_genome(5.0)), RNG (Random.seed!(42+island-1)),
  tight bounds, v13 ObjectiveConfig (tail5, no ceiling penalty, FoS 1.5/1.5,
  kickstart 0, k_mppt = p.k_mppt), length 18.0 m, DE sizing 10×3×30.
- **Gate alignment:** ode_gate_v13.jl uses lift_for; regate + ladder inherit via gate_design.
- **Plan:** docs/plans/2026-08-18-5kw-mass-aware-lift-redo.md
