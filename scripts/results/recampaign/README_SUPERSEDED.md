# anchors_SUPERSEDED_2026-07-21.csv — DO NOT USE

This file was produced by the overnight 5h47m anchor batch (2026-07-21) and is
superseded due to three compounding instrument faults in src/objective_v11.jl:

1. **FoS sign inversion** (lines 211/214, 356/357):
   `fitness = -P_mean * fos_penalty` rewarded structural failure.
   Fixed → `fitness = -P_mean / fos_penalty`.

2. **Missing orbital-velocity init** (line 310):
   Ring angular velocities set to ω_eq but node translational velocities left
   at zero. The ODE resolved the kinematically impossible state violently,
   producing spurious FoS collapse (0.03–0.08 band) and power overshoot
   (260 kW above a ~97 kW Betz ceiling). All FoS values measure
   initialization shock, not structural adequacy.
   Fixed → tangential velocity block from recheck_12gon_convergence.jl:74-84.

3. **Warm-start never replaced** (recampaign_anchors.jl:100):
   The batch called warmstart_with_k_bracket — the flawed fast path —
   instead of the full-protocol fallback. Compounded faults 1 and 2.

**Status:** Retained as evidence for all three root-cause findings.
Do not use for discrepancy modeling, anchor selection, or any downstream
analysis. A replacement batch will be run after the long trace validates
the fixed instrument.

— Rod Read, 2026-07-21
