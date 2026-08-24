# PROVENANCE — v13_5kw_masslift_len18.8

- **Campaign:** 5 kW v13 DE RE-RUN, mass-aware constant-tension lift, span³
  blade-mass era
- **Runner:** scripts/run_v13_5kw_masslift.jl
- **Physics era:** `post-807efa6_span3-honest-window` — Daisy-anchored base
  params (r_bottom clamp fix, lifter mass excluded from tension,
  annulus-aligned Betz gates), span³ blade-mass law
  (m = 0.420·(decoded span/1.0)³, 420 g Daisy anchor, ^3.0 exponent per Rod
  2026-08-22), hub double-model removed, honest window relax 10 + window 40,
  k = 2.24 (honest-window sweep on the corrected machine, below the
  generator clamp).
- **Launch git HEAD:** edd7f5f720bb6959c41a83eae025ca003ecca871
- **Regime:** `lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true)`
  — vertical lift = 1.5 × m_airborne × g, m_airborne = expansion_airborne_mass(sys, p;
  include_lifter=false) per genome (lifter's own mass does NOT drive the tension,
  Rod 2026-08-21); line tension = F_vert / sin(70°), FLAT at all wind speeds
  (modulated lifter, no v² scaling).
- **Base params:** params_daisy() (measured Tulloch anchor) scaled 1.5 → 5 kW via mass_scale.
- **Seed:** RE-SEEDED for the span³ law (commit edd7f5f: blade_scale 0.6,
  Do_top 0.025) — NOT the first-campaign seed (that campaign is VOID, λ³
  exploit, see handover 2026-08-22 §3c).  RNG Random.seed!(42+island-1),
  tight bounds, DE sizing 10×3×30.
- **ObjectiveConfig:** tail5, no ceiling penalty, **FoS 2.5/2.5**, kickstart 0,
  **k_mppt = 2.24**, relax 10 s + window 40 s (honest sustained-power window),
  length 18.8 m.
- **Gate alignment:** ode_gate_v13.jl uses lift_for; regate + ladder inherit
  via gate_design.  Gate operating point corrected to k=2.24 (2026-08-24 —
  was 5.39, a stale value from the superseded 20 s-window sweep).
- **Plan:** DECISIONS.md [2026-08-22] (span³ law, hub double-model, honest
  window) + handovers/handover-2026-08-22-validated-5kw-campaign-launched.md
