# ODE Power Budget & Torsional Collapse Finding — 2026-08-13

Provenance note for the power-budget instrumentation and the resulting
finding that overturns the "5kW is viable" conclusion.

## Provenance

- **Scripts:** `scripts/diag_power_budget2.jl`, `scripts/diag_chain_state.jl`,
  `scripts/diag_long_window.jl`
- **Date:** 2026-08-13
- **Design:** 5kW campaign island-1 winner (`island_1_best.csv`) — n_lines=16,
  rings=9, n_active=3, r_hub=0.65m, inverted taper (r_ground≈2.5m > r_hub)
- **Git era:** post-ζ-fix (DECISIONS.md [2026-08-12])
- **Method:** direct calls to `compute_ring_forces!`, `get_generator_torque`,
  `compute_rope_forces!` on the live ODE state; twist-angle survey across
  the chain at 30/40/50/60s.

## Finding

1. **The 60s decay is torsional chain collapse, not aero decay.**
   ω_gnd → 0 at t≈50s while ω_hub stays ~9-10 rad/s. brake_engaged=false
   throughout — not a mechanical latch.
2. **Twist concentrates catastrophically in the TOP segment** (ring 10→hub):
   Δα = 9,203° at t=30s growing to 22,425° at t=60s — 62 full revolutions,
   far beyond the 42.6° collapse limit. The lines have crossed.
3. **Root geometry:** inverted taper (r_ground 2.49m > r_hub 0.65m). τ_cap ∝
   r_min² → the narrow hub end is the weakest segment; the DE shrank r_hub
   (cheap mass) and created the collapse point.
4. **The gate/evaluator read the WRONG ring:** gate P = k·ω_hub³, but the
   generator extracts k·ω_gnd³. The "6.34 kW gate pass" measured the
   freewheeling hub, not generator output (which is zero after t≈50s).
5. **The static torsional FoS gate was RIGHT.** It scored this design 0.31
   (<1.5, "collapses") and the ODE confirms collapse. The gate is not
   over-conservative at 5kW — it is the correct instrument, and the ODE
   gate must measure ω_gnd to see the same failure.

## Consequences

- All 5kW "sustained power" results from 2026-08-12/13 (island-1 winner
  6.34 kW, the three length-variant campaigns) measured hub freewheel
  power, not transmitted power. The 5kW rung has NO verified winner.
- The V12 fitness window and ODE gate must be re-instrumented to read
  P_gen = k·ω_gnd³.
- Design fix: torsional capacity at the top segment — r_hub must not be
  shrunk below the τ_cap limit; the static torsional gate should be
  RE-ENABLED as a hard gate at all scales (it was right at 5kW).

## Disposition (pending Rod)

- Re-instrument gate/evaluator (ω_gnd) — proposal + acceptance tests +
  DECISIONS entry per standard.
- Reconsider the torsional gate removal for ≤7kW rungs.
- Settle-drag-alignment proposal: drag terms were a minor term (~26W tether
  at 10 rad/s); the real settle-vs-ODE gap is the collapse. Proposal to be
  revised — drag inclusion may still stand as correct physics, but test A's
  20% target is unreachable until the chain transmits.
