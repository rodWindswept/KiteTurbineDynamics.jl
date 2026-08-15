# Rotor power realism — cp falloff, per-rotor Betz, no freewheel decoupling

**Date:** 2026-08-14
**Status:** PROPOSAL — awaiting Rod's mechanism choice on §C before implementation.
Physics-model change → acceptance tests RED on master first, then code, then DECISIONS entry.
Campaigns 18.0/21.2/25.0 are STOPPED until this lands.

## What Rod asked (and why the 100 m/s ceiling is not enough)

> "What's to stop it just spinning every ring to 100 m/s every time? Surely we have to limit the
> rotor output power within real Betz potential and its own aero characteristics? There should
> never be a way for the rotor to decouple from the rest of the TRPT chain."

A tip-speed ceiling is a threshold, and the DE parks on thresholds (n_lines=16, Do_top, density —
all boundary-parked already). A machine flying every ring at 99 m/s would pass it. The physics
itself must prevent overspeed and decoupling.

## Source-confirmed defects

1. **`cp_at_tsr` feeds power at any spin speed.** `src/aerodynamics.jl:287` (`_interp_bem`):
   above λ=8 the table CLAMPS to the last entry — **Cp = 0.1376 at λ = 10⁸⁵**. A real blade at
   extreme TSR has its angle of attack gone negative: it is a spinning drag brake (cp → 0, then
   negative — propeller-brake regime). The model instead feeds the rotor positive power forever.
   This is the energy source of the ω→1e66 divergence.
2. **The chain coupling saturates.** Rope torsional restoring torque ∝ sin(Δα) — bounded.
   Once a rotor's aero torque exceeds the chain's maximum restoring torque, nothing holds it:
   the rotor freewheels away from the chain. This is Rod's "decoupling" — coupling exists but
   has finite capacity, and the model integrates through the capacity limit as if the chain
   never broke.
3. **Twist crossing is observer-only.** δα* rejects designs after the fact; the ODE integrates
   62+ revolutions of crossed lines. The collapse has no model consequence.

## Proposed fix (three parts)

### A. cp_at_tsr high-TSR falloff (physics, uncontroversial)

Beyond the table (λ > 8): linear ramp from Cp(8)=0.1376 to **0 at λ=9**, then linear to a
**drag-brake floor of −0.05 by λ=10**, held negative beyond. Justification: at λ≈9–10 the
blade's local angle of attack is negative across the span (TSR 9 with design pitch ≈ 0° means
α ≈ atan(1/λ) − twist ≈ −6° at the tip); the rotor is braking. The exact ramp points are
calibratable; the physics direction (cp → 0 then negative, bounded) is not negotiable.

### B. Per-rotor Betz potential check (instrument, belt-and-braces)

In `evaluate_windowed` and the gate: for EACH rotor (hub + every expansion rotor), the rotor's
own extracted aerodynamic power must be ≤ 1.1 × Betz potential of its own swept area
(0.593·½ρAᵢv³, Aᵢ = rotor's own annulus, banked). Violation → hard reject. This is the explicit
"limit the rotor output power within real Betz potential" guarantee — with (A) it should be
nearly redundant, which is exactly what makes it a good detector of future model regressions.

### C. No freewheel decoupling — mechanism choice needed (Rod decides)

With (A) in place the rotor cannot self-accelerate: at TSR where cp < 0 the aero torque brakes
it, so freewheel divergence dies at the source. The remaining question is what the MODEL does
when a segment's twist exceeds δα* (the chain's torque capacity is genuinely exceeded — the
Tulloch collapse):

- **C1 (minimal, recommended):** keep the observer rejection as the design-level consequence
  (twist detector rejects the eval) AND clamp the transmitted rope torque at its saturation
  value consistently at every segment — the chain transmits what it physically can, nothing
  more. With (A), post-crossing states remain numerically bounded (no 1e66). Rationale: we do
  not model entanglement physics (flailing lines, kite falls) — a crossed machine is BROKEN,
  and the evaluator must reject it, not simulate its wreckage.
- **C2 (mechanistic):** at crossing, cut torque transmission through that segment to zero and
  let the rotor side spin down through its own drag (broken machine coasts to a stop).
  More physical mid-failure, but invents a failure transient we have no data to calibrate.
- **C3 (status quo + A/B):** keep integrating past crossing (with sin(Δα) restoring) — rejected
  by Rod ("should never be a way to decouple") and by the 22,425° evidence.

**Recommendation: A + B + C1.** The rotor is bounded by its own aero reality (A), every rotor's
power is verified against its own Betz potential (B), the chain transmits no more than its
physical capacity (C1), and anything that exceeds the collapse limit is rejected by the
evaluator, never simulated as a working machine.

## Acceptance tests (`test/test_rotor_power_realism.jl`, RED on master)

| # | Test | Expected |
|---|------|----------|
| P1 | `cp_at_tsr` falloff | cp(8.5) < cp(8.0); cp(9.5) ≈ 0; cp(10.0) < 0; cp(1e6) ≤ 0 (bounded). Master: cp(1e6) = 0.1376 ❌ |
| P2 | Torque sign at extreme TSR | net rotor torque at λ=12 is NEGATIVE (braking) → a free rotor at λ=12 decelerates (dω/dt < 0). Master: positive ❌ |
| P3 | Per-rotor Betz check | synthetic rotor with extracted power > 1.1×Betz(own area) → rejected. Master: no check exists ❌ |
| P4 | No freewheel (end-to-end) | an in-bounds inverted-taper design (r_hub=0.7, r_bot=1.0, n_active=1) runs 30 s without ω_hub exceeding the 100 m/s tip ceiling — no divergence, no NaN freeze. Master: this family diverged to 1e66 ❌ (verify: the 0.47/0.67 winners are now out of bounds, so this test uses a fresh in-bounds proxy) |
| P5 | Saturation cap | segment torque never exceeds the chain's physical saturation value in the ODE (unit: constitutive function). |

## Blast radius

- `cp_at_tsr` is THE rotor power coefficient — every simulation, dashboard, settle, BEM scan,
  and historical comparison changes. New physics era required; past CSVs become
  non-reproducible under the new model (provenance stamps must mark the era boundary).
- The tip-speed ceiling (100 m/s) REMAINS as a numerical-divergence backstop; it is no longer
  the primary defense — (A) is.
- DECISIONS entry on approval; DECISIONS.md physics-era bump.

## Decision needed from Rod

1. §C mechanism: C1 (recommended) / C2 / other.
2. §A ramp points: λ=9 → cp 0, λ=10 → −0.05 floor acceptable, or different calibration?
