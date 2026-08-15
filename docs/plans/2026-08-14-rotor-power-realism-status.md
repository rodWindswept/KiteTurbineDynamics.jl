# Rotor power realism — implementation status + the fling finding

**Date:** 2026-08-14
**Proposal:** `docs/plans/2026-08-14-rotor-power-realism.md` (Rod approved A2 + C1)

## Landed and verified

- **A2 — cp falloff beyond the table** (`src/aerodynamics.jl`): the blade's own
  terminal slope continues to the derived zero crossing (λ=9.61 = 1.85× design
  TSR 5.2), then cosine-blends into the flat-plate drag brake cp = −k·λ³
  (k = 2.69e-4, table-derived). P1/P2 green: cp(8.5)=0.095 < cp(8)=0.138,
  cp(9.61)≈0, cp(10)=−0.089, cp(1e6)=−2.69e14 (finite), brake grows cubically.
- **B — per-rotor Betz potential** (`rotor_betz_ok`, exported; hard reject in
  `evaluate_windowed` reading `ef.rotor_aero_power` per rotor vs 1.1×Betz of
  its own disk). P3 green.
- **C1 — per-segment rope torque saturation** (`src/rope_forces.jl`): TRPT
  segment shaft torques accumulated, clamped at the crossing-limit capacity
  τ_sat = n_lines·T·r²·sin(δα*)/chord with sign preserved. No effect at
  healthy twist (identical dynamics — suite 1901/1901).
- Suite: **1901/1901 green** with all three changes.

## P4 RED — and it overturned the mechanism again

The old 18 m winner still reaches ω_hub = 3.5405e69 — the **exact same value**
before and after A2/C1. `scripts/diag_where_diverges.jl` localised it:

- Post-settle: ω = 16.35 rad/s everywhere (healthy)
- Within 5 s of MPPT: ω_hub = 3.54e69, ω_gnd = 16.41, alpha_hub integrates
  EXACTLY linearly (+3.54e69 rad/s each second) → **torques[hub] ≡ 0**: a
  genuine torque-equilibrium fixed point, not a NaN freeze.
- At that ω the aero brake is ≈ −10¹³⁵ N·m, so the rope torque must be
  ≈ +10¹³⁵ N·m → line tension ≈ 10¹³⁵ N → the hub ring's POSITION was flung
  far outward and the lines stretched astronomically.
- The winner has the thinnest possible rings (t_over_D=0.005, Do_top=0.0285,
  both on bounds) — a light ring flung by rotor thrust becomes a balloon on a
  string with a spinning top, and the stretched-line torque cancels the brake.

## What is missing (next proposal — pending Rod)

1. **Rope break physics.** The spring law integrates unbounded strain; real
   Dyneema fails at ~3–4% strain. A break limit (T > T_break → segment fails,
   machine loses transmission, evaluator rejects) would collapse the
   balloon state into a physical failure.
2. **The 5-second fling itself.** Whether the light-ring fling is a genuine
   structural instability (thrust vs ring mass) or a numerical artifact of the
   bearing/orbital damping on light rings needs a dedicated investigation —
   the two must be told apart before any model change.

Campaigns remain STOPPED until P4 goes green — the freewheel family is still
reachable through the translational route.
