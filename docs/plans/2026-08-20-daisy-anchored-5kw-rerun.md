# Daisy-anchored 5 kW re-run — plan (2026-08-20)

**Status:** config assembled; launch pending smoke + Rod's go.
**Runner:** `scripts/run_v13_5kw_masslift.jl` (reconfigured; rename to v14 at commit).
**Seed/bounds:** `scripts/compute_seeds.jl` (now Daisy-anchored).

## Why this re-run exists

The prior 5 kW "winners" were produced under four compounding model faults —
50 kW blade mass, a phantom 5 m rotor radius, a full-disk (not annulus) swept
area, and a mass-blind power-scoring objective — all now fixed. This re-run
finds the first honest 5 kW designs: lightest machine that reliably makes
rated power at FoS ≥ 2.5.

## The anchor (measured, not extrapolated — Rod 2026-08-20)

From the Tulloch thesis (`docs/validation/tulloch-prototype-configurations.md`):
ring 1.52 m, tips 1.22/2.22 m (70/30 annulus ≈ 11.2 m²), solidity 7.5%,
NACA 4412, blade 420 g + 2 carbon rods + 3D fuselage, **<2 kg at >1.5 kW
(φ ≈ 1.3 kg/kW)**, flown TRPT lengths 6.7–10.3 m (config 8 = 10.3 m),
Cp_sys 0.15–0.18. The NZTC 50 kW BOM is explicitly NOT an anchor.

## Re-run configuration

| Item | Value | Note |
|---|---|---|
| Objective | `mass_min_fitness` | score = true physics mass; hard floors below |
| FoS floor | **2.5** at all points | until field trials/breakages (Rod) |
| Power floor | **5.0 kW** | the rung rating (hard reject below) |
| Length | **18.8 m** | 10.31 m × √(5/1.5), Daisy-up |
| Seed r_hub | 2.78 m | 1.52 × √(5/1.5) |
| Seed n_lines | 6 | Daisy-proven |
| Seed blade_scale | 1.0 | full-span reference |
| r_hub bound lo | 0.7 m | annulus feasibility r_ring ≥ 0.3·span enforced by `rotor_annulus_ok` |
| Lift | mass-aware constant-tension, 1.5× m·g | unchanged |
| Physics era | post-annulus + λ² mass + rung-scaling | fast suite 1918/1918 green |

## Expected outcome (sanity check)

Daisy φ ≈ 1.3 kg/kW → a 5 kW machine ≈ 4–7 kg airborne (φ ≈ 0.8–1.4); the
fixed model already lands φ ≈ 1 kg/kW. The DE should find designs near that
region, delivering 5 kW at 11 m/s with FoS ≥ 2.5, twist/tip-speed/break gates
green. The exact winners replace every prior 5 kW claim (which is void).

## Validation sequence

1. **Smoke: DONE (2026-08-20) — the Daisy seed STALLS.** One `evaluate_windowed`
   on the Daisy seed (r_hub 2.78 m, 6 lines, blade_scale 1.0, L=18.8 m) with
   the mass-min config returned `status=:reject`, P_mean = 0.0 kW (rejected on
   the power floor, not the FoS gate — FoS_min = Inf because no structural
   loads landed on the stalled branch). **The seed does not self-start /
   sustain rotation under the current settle + k_mppt.** Do NOT launch the
   full campaign yet. Candidates to diagnose (in order): (a) `params_at_length`
   still theory-scales `k_mppt` and `i_pto` from `params_10kw` — the Daisy
   operating point (τ = k·ω², ω ≈ 15 rad/s at 146 rpm, ~0.3–0.4 N·m·s²) is not
   yet anchored; (b) `kickstart_s=0` + ζ=0.05 may not spin the seed up from
   cold; (c) the seed's r_rotor (BEM theory at TSR 4.1) vs the measured
   Cp_sys 0.16 mismatch.
2. **One length** (18.8 m): short DE (1 island, few gens) — after the seed
   stall is resolved.
3. **Full re-run**: 10 pop × 3 islands × 30 gen (~930 evals, ~1–3 min/eval →
   ~15–30 h). Then re-baseline the acceptance suite on the new winners.

## Open items before launch

- **Resolve the seed stall** (above) — the Daisy-anchored base must actually
  spin and produce power before the DE can explore around it.
- Confirm the **mass exponent** assumption (φ ≈ 1.3 kg/kW anchor; field tests
  measure the true exponent).
- Confirm **power floor 5 kW** vs the prior 2.5 kW floor.
- Replace `params_at_length`'s theory anchor (tether diameter, k_mppt, i_pto)
  with Daisy-anchored values (tether 2 mm; k_mppt from the Daisy operating
  point ω ≈ 15 rad/s).
