# Regate verdict — 5 kW rotorcount campaign, corrected mass model (len 18.8 m)

**Date:** 2026-09-02
**Campaign dir:** `scripts/results/v13_5kw_masslift_len18.8_rotorcount/`
**Git era (launch):** `cb12183` — post mass-model fix (2 mm wall, per-ring sum,
ring knuckles), settle-blocking fix, `appropriate_mass_fitness`, Do `[0.03, 0.16]` m,
n_lines `[3, 9]`.
**Instruments:** `scripts/ode_gate_v13.jl` (independent 30 s ODE window,
decode-aligned), evaluator rows from per-island `telemetry.csv` (40 s window,
tail5).

## Question

Does this campaign produce a valid 5 kW design under the corrected physics?
Per runbook §6: re-gates clean with finite FoS ≥ 2.5, P ≥ 5 kW, clearance
≥ 1.5 m, no twist crossing, tip sanity — **and** the mass now passes a by-hand
sanity check (the failure mode of the previous, VOID campaign).

## Results (per island winner, gen 30)

| island | fitness kg | n_active | n_lines | r_hub m | P kW (eval) | FoS | clear. m | gate |
|---|---|---|---|---|---|---|---|---|
| 1 (global best) | 18.49 | 1 | 3 | 4.32 | 5.41 | 17.19 | 5.73 | PASS |
| 2 | 23.83 | — | — | — | — | — | — | not re-gated |
| 3 | 37.23 | — | — | — | — | — | — | not re-gated |

## Winner detail (island 1, global best)

- **Genome:** `0.03, 0.0277, 0.788, 0.984, 4.32, 0.863, 2.799, 3.0, 0.698, 1.38, 19.95, 6.69, 0.70, 1.0`
- **Form:** single rotor (`n_active = 1`), **n_lines = 3** (triangle), 6 rings,
  r_hub 4.32 m (at the hi bound), r_bottom 0.86 m, Do_top 0.03 m (at the lo
  bound), t/D 0.0277, Do_scale_exp 0.98.
- **Re-gate (ode_gate_v13.jl):** P_gen 5.47→5.62 kW over 5–30 s (stable),
  ω_gnd 13.5 rad/s, twist ratio 0.5 (worst segment 41° vs 78.8° limit),
  tip sanity ok, clearance 5.73 m → **PASS**.
- **Evaluator:** P_mean 5.41 kW / P_end 5.42 kW, **FoS_min 17.19**, status ok.

## Mass sanity (the point of this re-run)

No-lifter airborne mass **10.94 kg**, broken down:

| component | mass |
|---|---|
| hub ring (30 mm OD / 2 mm wall, 3 × 7.5 m) | 6.32 kg |
| 5 transmission rings (6.2 mm OD / 2 mm wall) | 0.95 kg |
| blades | 3.11 kg |
| knuckles (blade + ring) | 0.19 kg |
| tether | 0.57 kg |

The 2 mm wall floor is doing its job — the previous VOID winner's toothpick
2.3 mm / 0.06 mm transmission rings are now real 6.2 mm / 2 mm tubes.  Raw mass
with the 5 kg lifter is 15.94 kg; the 18.49 kg fitness includes ~2.5 kg of
penalties (the machine is slightly over-rated at 5.4 kW, which
`appropriate_mass_fitness` correctly charges).

## Verdict

- **The corrected mass model closes the exploit.** The winner is the SAME
  corner as before (single rotor, n_lines = 3, r_hub at max, Do at min) but now
  at a defensible 10.9 kg instead of a bogus 4.4 kg — a ~2.5× correction driven
  by the 2 mm wall floor + per-ring sum + ring knuckles.
- **Re-gate passes.** Power, FoS, clearance, twist and tip speed all clean.
- **Single rotor + triangle dominates again.** `n_lines = 3` is allowed (only
  `n_lines = 2` is flown-unstable per Rod), but the winner landing on a triangle
  is flagged for review.
- **FoS 17 is well above the 2.5 floor.** Suggests the 30 mm OD / 2 mm wall
  baseline is over-conservative for 5 kW; noted, not re-run.

## Disposition (pending Rod)

1. Review the `n_lines = 3` triangle form (accept or constrain).
2. Acceptance re-baseline on this winner (next step).
3. Note FoS 17 → possible relaxation of the 30 mm / 2 mm baseline (future).
4. Results push to origin (repo convention keeps telemetry untracked).
