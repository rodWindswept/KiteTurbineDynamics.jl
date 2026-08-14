# BEM/ODE Gap Resolution — ζ=1.5 Rope Damping Diagnosis

**Date:** 2026-08-12  
**Session:** Cross-session investigation spanning 2026-08-11 through 2026-08-12  
**Status:** Resolved — root cause identified and fixed

---

## Problem

Every KTD.jl ODE simulation — regardless of genome, k_mppt value, start-up strategy
(kickstart, cold start, manual ramp) — converged to a stable reverse-rotation state
at ω ≈ −0.2 rad/s. The static BEM scan predicted 22 kW peak at ω ≈ 12 rad/s for
the V10 Reinforced genome, but the ODE never produced sustained positive power.

Previous session (2026-08-11) made important infrastructure fixes (tether_diameter
in ObjectiveConfig, lift_device through all settle paths) and correctly identified
this as a force-level problem, not parameter tuning. But the source wasn't found.

## Hypothesis (from handover analysis)

Two asymmetries in the code were identified as candidates:

1. **Tension rectifier** (`rope_forces.jl:19`): `max(0.0, EA·ε + c_damp·v_proj)` —
   clips the damper term asymmetrically, creating a DC bias.

2. **Orbital velocity overwrite** (`initialization.jl:517-550`): destroys 95% of
   `v_osc` every step against an idealised reference field. Bypasses the force
   path entirely — no force instrumentation can see it.

## Diagnostic results

| Test | Result | Verdict |
|------|--------|---------|
| Orbital damping ΔL_z at ω=9.5 rad/s | cum +38.6, mean ~0 | ✅ Clean |
| Orbital damping ΔL_z at ω=2.0 rad/s | cum −8.55, mean −0.0003 | Tiny bias, swamped by aero torque — **not the source** |
| **c_damp = 0** (rope structural damping zeroed) | ω: 2.0→10.7 rad/s, no stall | ⚠️ **This IS the contributor** |
| ζ = 0.05 confirmation | ω: 2.0→10.56 rad/s, sustains under MPPT | ✅ **Fix confirmed** |

The orbital damping produces a tiny negative ΔL_z at low ω, but it's negligible
compared to the aero torque. With c_damp=0, the rotor spins up cleanly. With
ζ=0.05 (1/30th of the original 1.5), the system works correctly.

## Root cause

`src/initialization.jl:97` hardcoded `zeta = 1.5` for all rope sub-segments.
This value was used to compute the structural damping coefficient:
```
c_damp_s = 2.0 * zeta * sqrt(EA_single / sub_len_0_s * m_rope_sub_s)
```

At ζ=1.5, the damper term dominates the tension law. The `max(0.0, ...)` rectifier
in `rope_forces.jl:19` clips the damper contribution asymmetrically — adding tension
at full strength but blocking negative tension entirely. Over any oscillation cycle,
this rectification leaves a non-zero mean force (a DC bias) that manifests as a
persistent reverse torque.

The bias scales with how much the damper contributes relative to the spring term.
At ζ=1.5 the damper is 30× larger than physical Dyneema (ζ≈0.01-0.05), so the
rectified bias overwhelms the aero torque.

## Physics validation

Dyneema (UHMWPE) has intrinsic material damping of ζ ≈ 0.01-0.05. The value 1.5
was likely chosen for numerical stability headroom during early development, not
from material properties. At ζ=0.05:
- The damper is 30× smaller
- The rectifier's DC bias drops below the noise floor
- Aero torque dominates as it physically should
- The ODE remains numerically stable (tested at dt=4e-5, 250k steps)

## Fix (implemented 2026-08-12)

**Option 2 — Proper engineering:** Promoted ζ to a `SystemParams` field.

| File | Change |
|------|--------|
| `src/parameters.jl:160-164` | Added `zeta::Float64` field with documentation |
| `src/parameters.jl:207` | Default `0.05` in grouped-spec constructor |
| `src/initialization.jl:97` | `zeta = 1.5` → `zeta = p.zeta` |

All existing callers (builders, evaluators, dashboard) pick up ζ=0.05 automatically
through the grouped-spec constructor. `override_params()` auto-adapts via `fieldnames()`.

## Test suite

1902 assertions, all green. No regressions.

## Diagnostic scripts (artifacts)

- `scripts/diag_orbital_damping_Lz.jl` — high-ω L_z measurement
- `scripts/diag_orbital_damping_Lz_lowomega.jl` — low-ω L_z measurement  
- `scripts/diag_cdamp_zero.jl` — c_damp=0 isolation test
- `scripts/diag_zeta_005.jl` — ζ=0.05 confirmation (3 sub-tests)
- `scripts/diag_zeta_validate.jl` — end-to-end with run_canonical_sim!
- Output CSVs: `diag_*.csv` in repo root

## Key lesson

A hardcoded magic number (ζ=1.5) with no physical basis caused weeks of confusion
across multiple sessions. The orbital damping overwrite was correctly identified as
suspicious (it bypasses the force path), but it was the rope structural damper —
an even simpler mechanism — that was the actual root cause. The diagnostic approach
(measure ΔL_z, zero components one at a time) was effective and should be the
template for future force-level investigations.
