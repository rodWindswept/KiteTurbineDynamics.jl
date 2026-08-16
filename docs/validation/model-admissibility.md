# Model Admissibility Checklist — the campaign launch gate

**Status: ADOPTED as a launch gate (2026-08-15, retrospective).** No DE
campaign launches unless every gate below is either ACTIVE (verified by its
acceptance test on the current HEAD) or explicitly waived here by Rod with a
recorded reason.

Companion ledgers: `docs/agents/instrument-trust-log.md` (measurement
faults), `docs/agents/exploit-register.md` (DE exploits and fixes),
`DECISIONS.md` (physics decisions).

---

## The gates

| # | Gate | Enforces | Implemented at | Acceptance test | Calibration evidence | Status |
|---|---|---|---|---|---|---|
| 1 | **Power read at the ground ring** | P_gen = τ_gen·ω_gnd, never ω_hub (the 6.34 kW false positive) | `get_generator_torque` (ring_forces.jl) + gate | test_gate_v13 (seed 4.12 kW @ ω_gnd) | island-1 winner: 6.34 kW hub = 1.57 kW ground | ACTIVE |
| 2 | **Sustained power, not transient** | fitness uses mean of last 5 window samples (`P_end`), not the hot-settle transient | evaluator v13 `:tail5` | B2 (flywheel design rejected) | v12 flywheel winners decayed to ~0 kW | ACTIVE |
| 3 | **Per-rotor Betz** | each rotor's extracted aero power ≤ 1.1× Betz of ITS swept area | `rotor_betz_ok` (objective_evaluator.jl) | P3 | Betz 1 m disk @ 11 m/s = 1.519 kW | ACTIVE |
| 4 | **Cp falloff / drag brake** | no positive Cp beyond λ=9.61; cubic drag brake past the zero | `_interp_bem` (aerodynamics.jl) | P1, P2 | NACA4412 table: peak 0.309 @ λ=5.2, zero 9.61, k=2.69e-4 | ACTIVE |
| 5 | **Rope break (SK99 3.5%)** | line-path strain > 3.5% → zero tension + immediate disqualification | rope_forces.jl + evaluator `line_broken` | R1-R3 | Dyneema SK99 ultimate strain; 18 m fling winner breaks @ ~44 kN elastic | ACTIVE |
| 6 | **Twist crossing hard-reject** | per-segment Δα vs geometric crossing limit δα* | `twist_collapse_check` | B1, B5 | island-1 winner: 169× limit, torsional collapse | ACTIVE |
| 7 | **Tip-speed ceiling** | every ring rim AND every rotor tip ≤ 100 m/s | `tip_speed_sanity_ok` | B7a-c | design point ~44 m/s @ TSR4/11 m/s; ceiling ~2.3× headroom | ACTIVE |
| 8 | **C1 torque saturation** | segment transmits ≤ crossing-limit torque, action-reaction | rope_forces.jl post-loop clamp | suite (bit-identical healthy designs) | wound segments cannot pump rings | ACTIVE |
| 9 | **r_hub floor 0.7 m** | no tiny-hub inverted-taper exploit | compute_seeds bounds | R2/P4 (18 m winner at floor is sound) | Daisy 1.5 kW: r_hub 1.52 m; void winners 0.47-0.67 m diverged | ACTIVE |
| 10 | **t_over_D floor 0.010** | no 0.14 mm-wall rings (58 g, flung by 5.7 kN) | compute_seeds bounds | P4 (winner breaks lines, stays finite) | seed's own value — no thinner than the starting design | ACTIVE |
| 11 | **Clearance + Betz preflight** | tip-to-ground clearance, swept-area Betz budget before eval | gate_design preflight | ladder 15 kW cells (clearance-limited) | 12 m designs fail clearance; 25 kW seed stalls (40 m² vs 19.3 kW ceiling) | ACTIVE |
| 12 | **Settle discipline** | breaks disabled during settle's exploratory transients; operational ω from settled state | `breaks_enabled` latch | R3 (healthy seed never breaks) | settle over-strains lines momentarily (340% artifact exposed) | ACTIVE |
| 13 | **Static structural FoS gates** (b) | ring/torsional/buckling capacity vs load, small-scale threshold | currently DISABLED ≤ 7 kW | none current | seed scores 0.56 vs 1.5 target; Daisy 0.22 — threshold, not physics, is wrong | **NEEDS WORK — Monday's (b)** |
| 14 | **Orbital-damping fling interaction** (Q1/c) | operator contributes no energy to light-ring fling | lin_damp=0 comparison | Q1 verdict (diag_q1_lindamp.jl) | break at 5.0 s with AND without the operator — fling is mass/thrust physics, not numerics | **RESOLVED — (c) OUT** |
| 15 | **Rapid-evaluator calibration** (W3) | rapid fitness maps to ODE verdicts within tolerance | parked | none | telemetry has rapid results only; needs 50-100 ODE evals | **PARKED by Rod** |

---

## Pre-launch procedure (run before ANY campaign)

1. `julia --project=. test/runtests.jl` → 1900/1900.
2. Acceptance suites green: `test_rope_break.jl` (R1-R3),
   `test_rotor_power_realism.jl` (P1-P4), `test_evaluator_v13.jl` (B1-B7),
   `test_gate_v13.jl`.
3. Every gate rows 1-12 ACTIVE on the HEAD being launched; any NEEDS WORK /
   PENDING row requires Rod's recorded waiver.
4. Seed genome inside bounds (compute_seeds) — verify with
   `scripts/probe_map.jl` style checks at the campaign's length/rung.
5. Results folder: fresh (no prior run), provenance note with git hash +
   physics era + geometry fingerprint at launch.

## Waiver log

| Date | Gate | Waiver | Reason |
|---|---|---|---|
| 2026-08-15 | 13, 14, 15 | campaigns at 5 kW launched with (b)/Q1/W3 open | Rod: "model better than anything else out there, might prove something" — winners re-gated green on gates 1-12 |
