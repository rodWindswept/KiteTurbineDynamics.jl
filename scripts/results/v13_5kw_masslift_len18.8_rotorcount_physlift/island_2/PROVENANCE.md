# PROVENANCE: v13_5kw_masslift_len18.8

- **Campaign:** 5 kW v13 DE, mass-aware constant-tension lift REDO
- **Runner:** scripts/run_v13_5kw_masslift.jl
- **Physics era:** post-4ce9fd0_daisy-anchored-5kw. Details (2026-08-22): Daisy-anchored base params. r_bottom clamp fix. Lifter mass excluded from tension. Annulus-aligned Betz gates. Span^3 blade-mass law (m = 0.420·(decoded span/1.0)^3) with the 420 g anchor. Hub double-model removed. Honest window relax 10 + window 40. k=2.24.
- **Launch git HEAD:** 1c9f9cbf4eac8f6d7909ab4d6cb5ee62417cb979
- **Run log:** .julia_depot/logs/v13_physlift_island_2.log. Runtime claims cite the `Campaign complete in Ns` line from this file.
- **Regime:** `lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true)`. Vertical lift = 1.5 × m_airborne × g. m_airborne = expansion_airborne_mass(sys, p; include_lifter=false) per genome. The lifter mass does NOT drive the tension (Rod 2026-08-21). Line tension = F_vert / sin(70°), FLAT at all wind speeds (modulated lifter, no v² scaling).
- **Base params:** params_daisy() (measured Tulloch anchor) scaled 1.5 → 5 kW via mass_scale.
- **Baseline (fixed-rotary regime):** scripts/results/v13_5kw_len18.8/ + lift_tension_retrospective.csv (rotary_lifter_default(), wind-dependent tension).
- **Identical to first campaign:** seeds (seed_genome(5.0)). RNG (Random.seed!(42+island-1)). Tight bounds. DE sizing 10×3×30. Length 18.8 m.
- **V13 rotor-geometry knobs (2026-08-25 re-seed):** rotor_count_mode=true (x10 = rotor count {1,2,3}). power_split=0.6 (top rotor fraction). cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=1.0. cylinder_cone=true (three-section TRPT: transmission cylinder + 22° cone + harvest cylinder).
- **ObjectiveConfig:** tail5, penalize_ceiling=false, fos_target=2.5, fos_hard=2.5, kickstart 0.0, k_mppt = K_MPPT_5KW_HONEST (2.24), NOT p.k_mppt (3.55).
- **Gate alignment:** ode_gate_v13.jl uses lift_for. Regate + ladder inherit via gate_design.
- **Evidence pack:** the logs/ subdirectory holds the island logs, re-gate logs and CSVs, and the forensics probes for this campaign.
- **Plan:** docs/plans/2026-08-18-5kw-mass-aware-lift-redo.md
