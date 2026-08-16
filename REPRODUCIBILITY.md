# REPRODUCIBILITY — the 5 kW rung proof (KiteTurbineDynamics.jl)

**For:** the AWES community — anyone who wants to check, repeat, or extend
this work. Everything here is runnable from a fresh clone. If a command here
does not produce what this document says, that is a bug — open an issue.

**What we claim (2026-08-15):** on the corrected physics model (commit
`1d0a38a` and its ancestors), a differential-evolution campaign finds
TRPT kite-turbine designs that transmit **7.7–8.3 kW of sustained mechanical
power at the ground ring** across 18–25 m tether lengths, with coherent
chain rotation, no torsional crossing, no line break, and tip speeds inside
the ceiling. The corrected model also *denies* seed-class designs above
15 kW (swept area too small for the Betz budget) — the ladder table below.

---

## 1. What / Why / When in one paragraph each

- **What:** a Julia multibody simulation of the Tensioned Rotary Power
  Transmission (TRPT) — a chain of spinning rings on Dyneema lines driving a
  ground generator — coupled to a differential-evolution design search.
- **Why:** to prove or deny that this AWE topology scales from 5 kW upward,
  with every design checked against physical limits (Betz, blade Cp falloff,
  rope strength, twist-crossing torque, tip speed, ground clearance).
- **When:** model corrections and physics decisions 2026-08-13 → 2026-08-14
  (see `DECISIONS.md`); ladder sweep and campaigns 2026-08-15. Full cycle
  history: `docs/plans/retrospective-2026-08-17.md`.

## 2. Prerequisites

- Linux desktop; Julia **1.12.x** (`juliaup` recommended).
- Clone the repo at the recorded commit:

```bash
git clone https://github.com/<org>/KiteTurbineDynamics.jl
cd KiteTurbineDynamics.jl
git checkout 1d0a38a
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Recorded reproducibility commit: **`1d0a38a`** (physics era: A2 + per-rotor
Betz + C1 + rope break SK99 + tip-speed ceiling 100 m/s + r_hub ≥ 0.7).

## 3. Step 1 — verify the model (tests)

```bash
julia --project=. test/runtests.jl            # expect: 1900/1900 pass
julia --project=. test/test_rotor_power_realism.jl   # expect: ALL ACCEPTANCE TESTS PASS (P1-P4)
julia --project=. test/test_rope_break.jl     # expect: ALL ACCEPTANCE TESTS PASS (R1-R3)
julia --project=. test/test_evaluator_v13.jl   # expect: ALL ACCEPTANCE TESTS PASS (B1-B7)
julia --project=. test/test_gate_v13.jl       # expect: all green (4/4)
```

P4 is the key one: the old 18 m winner (a design that previously "won" by
freewheeling to ω ≈ 3.5×10⁶⁹ rad/s) must now break its lines and stay
finite — expect `max |ω| over 30s ≈ 17.9 rad/s`.

## 4. Step 2 — the ladder (seed-class scalability envelope)

```bash
julia --project=. scripts/ode_ladder_v13.jl
```

42 ODE gate runs (7 rungs × 6 lengths), ~1 hour, writes
`scripts/results/ladder_v13.csv`. Expected key rows:

| rung | design length | P_gen at ground | verdict |
|---|---|---|---|
| 5 kW | 18–30 m | 3.2–4.9 kW | pass |
| 7 kW | 18–21.2 m | 5.9–6.6 kW | pass |
| 10 kW | 18–21.2 m | 6.9–7.9 kW | pass |
| 15 kW | 18–25 m | 3.4–8.7 kW | pass (clearance-limited elsewhere) |
| 25–50 kW | all | ≈0 kW | **denied — stall** (swept area 40 m² vs Betz ceiling 19.3 kW) |
| any | 40 m | — | twist crossing |

## 5. Step 3 — a campaign (the 5 kW rung)

```bash
julia --project=. scripts/run_v13_5kw.jl --length 18.0   # or 21.2, 25.0
```

~10 hours per length (3 islands × 30 generations, full-genome telemetry).
Outputs per length in `scripts/results/v13_5kw_len<L>/`:
`island_1_best.csv` (winner genome), `convergence.csv`, `telemetry.csv`
(every evaluation: genome, fitness, rejection reason), `regate_verdict.md`.

## 6. Step 4 — re-gate the winner (the honest verdict)

```bash
julia --project=. scripts/regate_winner_v13.jl scripts/results/v13_5kw_len18.0/island_1_best.csv --length 18.0
```

Expected (recorded) verdicts:

| length | P_gen at ground | ω_gnd / ω_hub | twist | break | verdict |
|---|---|---|---|---|---|
| 18.0 m | 7.68 kW | 15.81 / 15.83 | 0.17 | none | PASS |
| 21.2 m | 8.24 kW | 16.18 / 16.18 | 0.25 | none | PASS |
| 25.0 m | 8.32 kW | 16.24 / 16.22 | 0.24 | none | PASS |

The gate reads power at the **ground** ring (not the hub), checks per-segment
twist against the geometric crossing limit, rope break (Dyneema SK99,
3.5% strain), tip speed ≤ 100 m/s on every ring and rotor, and ground
clearance.

## 7. Reading the physics (where the model comes from)

- `DECISIONS.md` — every physics decision, newest first: cp falloff (A2),
  per-rotor Betz (B), torque saturation (C1), rope break, tip-speed ceiling.
- `CONTEXT.md` — the TRPT physics primer.
- `docs/agents/instrument-trust-log.md` — the measurement faults we found
  and fixed (gate read the wrong ring; flywheel-window bias; NaN filtering).
- `docs/agents/exploit-register.md` — every way the DE cheated the model,
  and the fix. The DE is the model's auditor.

## 8. Known annotations (honest margins)

- Sampled line tension peaked at 105 kN against a 44 kN elastic break force:
  the excess is the damper's viscous regularization, which does not stretch
  the line (see R2 in `test/test_rope_break.jl`).
- Seed ω_gnd moved 12.85 → 13.18 rad/s when C1 began engaging on the real
  TRPT chain topology — still inside the seed's known band.
- All three winners share one design family: single rotor, r_hub at the
  0.70 m floor, line count growing with length (12/14/16). Whether
  single-rotor dominance is a 5 kW fact or a model preference is an open
  question (see the pool analysis in the wayfinder plan).

## 9. Cost and time to reproduce

| step | wall time |
|---|---|
| tests (all suites) | ~15 min |
| ladder | ~1 h |
| one campaign | ~10 h |
| re-gate | ~1 min |
| **total** | **~11 h single-machine** |
