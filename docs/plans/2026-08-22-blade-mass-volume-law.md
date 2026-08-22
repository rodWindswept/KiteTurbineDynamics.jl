# Proposal — unified blade-mass law: m_blade = m_ref · λ³ (2026-08-22)

**Status:** APPROVED by Rod (2026-08-22). Implemented TDD-style: RED
acceptance/unit tests first, then the law, then full-suite verification,
then DECISIONS entry.

## The problem — three mutually inconsistent blade-mass models in one repo

| Path | Law | Where | Anchor |
|---|---|---|---|
| Main rotor (ODE build) | `m_blade = p_base.m_blade · λ_eff²` — AREA scaling | `src/objective_evaluator.jl:348-357` | rung base (Daisy 0.210 under Gate 1c) |
| Expansion rotors | `(0.3 + 0.1·tip)·λ³·(n_blades/3)` — CFRP-calibrated CUBE law | `src/expansion_rotor.jl:467-477` | 3-blade-era CFRP estimates |
| Rung scaling | `m ∝ P^1.35` (≈ R^2.7) | `src/parameters.jl:543-576` | "Mass Scaling PDF" empirical exponent |

Rod (2026-08-22): rigid-foam blades scale with VOLUME (λ³), not area (λ²).
The λ² main-rotor term and the CFRP `(0.3 + 0.1·tip)` constants are both
rejected. Also: the Daisy blade anchor is **420 g** (measured, both the
3-blade and 6-blade systems use the same 420 g wings/fuselages) — the
Gate 1c renormalisation to 210 g (so 6 blades × 210 g = the 3-blade's
1.26 kg/ring) is REVERSED: the 6-blade machine carries **6 × 420 g =
2.52 kg/ring**.

## The unified law

```
m_per_blade = m_ref · λ³        λ = total blade linear scale (genome blade_scale
                                × any builder dial); m_ref = rung reference
                                per-blade mass (0.420 kg at the Daisy rung)
m_assembly  = n_blades · m_per_blade
```

- Same law for main and expansion rotors. Kill the λ² main-rotor term and
  the CFRP constants.
- m_ref = `p_base.m_blade` (rung-scaled base): 0.420 kg for the Daisy rung
  itself, the mass_scale'd value for higher rungs. The λ³ law operates ON
  TOP of rung scaling — the rung scales the reference blade's geometry, λ
  scales within a rung.
- Per-blade knuckle floor: every blade node carries ≥ `OPT_KNUCKLE_MASS_KG`
  (0.050 kg, approved 2026-04-20). Added into `expansion_airborne_mass`
  (the DE score AND the lift sizing input). ODE-inertia knuckles are a
  flagged follow-on (the ODE rotor inertia stays `n_blades · m_blade`).

## Files

- `src/expansion_rotor.jl` — `expansion_blade_mass` = `n · m_ref · λ³`
  (n default 3 for backward-compatible signatures); `corrected_mass`
  toggle removed (dead under the unified law — the era-pin struct loses
  the field; legacy-reproduction scripts get the new law by decision).
- `src/parameters.jl` — `M_BLADE_REF_KG = 0.420`; `params_daisy`
  `m_blade` 0.210 → 0.420 (measured anchor restored).
- `src/builders_util.jl` — `expansion_params_from_rotors` gains
  `m_blade_ref` kwarg; expansion assembly mass = `n_lines · m_ref · λ³`
  with λ = `rotor.blade_scale · blade_scale`; `geometry_fingerprint`
  double-count fixed (`er.mass` is already the assembly total).
- `src/objective_evaluator.jl` — main-rotor `m_blade · λ_eff³` (was λ²).
- `src/objective_v10.jl` — the frozen copy of the CFRP sum in the mass
  estimate updated to the unified law (consistency, no new campaigns).
- `src/expansion_analysis.jl` — `expansion_airborne_mass` adds knuckles
  (main `n_blades` + Σ `er.n_blades`) × 0.050 and counts ALL airborne
  rings (`sys.n_ring − 1`, was `p.n_rings`, missing the hub ring).
- `_build_v10_tight` main-rotor `le²` → `le³` (display path).

## Verification

1. Unit tests (new `test/test_blade_mass_law.jl` + updated
   `test_physics_inertia_mass.jl`): RED on current HEAD, GREEN after.
2. Full fast suite green.
3. Seed consequences on the new law (diag): airborne mass rises
   (~19–20 kg expected), T_lift rises (~280–305 N at 1.5× margin),
   mass-min floor becomes honest.
4. k-sweep + seed verification re-run on the new law BEFORE the campaign
   relaunch (combined with the honest-window k re-sweep, 2026-08-21 open
   task).

## Open items (flagged, not blocking)

- ODE-inertia knuckles (initialization.jl:43 counts blades only).
- The 420 g anchor vs the decoder's span identity (span = 0.75·r_rotor·λ
  at λ=1 vs the Daisy 1.0 m span) — a geometry-calibration question for
  the Daisy rung, separate from the mass law.
- Rung mass exponent P^1.35 remains the empirical rung law (handover:
  "leave alone"); field tests measure the true exponent.
