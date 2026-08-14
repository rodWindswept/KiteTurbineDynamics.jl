# Gate re-instrumentation: generator-side power + per-segment twist collapse detector

**Date:** 2026-08-13
**Status:** implementing (approved by Rod — "not convinced that'll make the difference
and detect all torsional collapse failures, but let's try it")
**Scope:** `scripts/ode_gate_v13.jl` (new), `test/test_gate_v13.jl` (new). No `src/` physics changes.

## Problem

The V12 ODE gate computes power as `P = k·ω_hub³` (e.g. `gate_length_winners.jl:57`),
but the generator extracts torque from the **ground ring**: Mode 0 MPPT is
`τ_gen = k·max(ω_gnd,0)²·payout_scale` (`src/ring_forces.jl:70-73`). During the
2026-08-13 torsional collapse of the 5 kW island-1 winner, ω_hub stayed ~9–15 rad/s
while ω_gnd fell to zero — the gate reported "6.34 kW sustained" for a machine
whose generator output was zero after t≈50 s.

A power metric alone cannot catch all collapse failures: at t=20 s the same
collapsing design still showed ω_gnd=9.32 rad/s (P_gen≈1.5 kW) — a short-window
power check would pass it while the chain winds up to 22,425° of twist at the
top segment.

## Change

Two instruments, both reading the ODE's own state:

1. **Generator-side power.** `P_gen = τ_gen·ω_gnd` where `τ_gen` comes from
   `get_generator_torque` — the exact function the ODE uses. Replaces `k·ω_hub³`.
2. **Per-segment twist collapse detector.** After the gate window, for every
   segment *i* between ring *i* and *i+1*:
   - `Δα_i = |α[i+1] − α[i]|` (twist states `u[6N+1:6N+Nr]`, free-integrated, no wrap)
   - per-segment crossing limit `δα*_i = 2·asin(L_seg/√(2(L_seg²+2r_seg²)))`
     with `r_seg = max(r_i, r_{i+1})` (conservative: smallest allowed twist)
   - **fail if any segment exceeds its limit** — direct physical collapse test,
     independent of power readings and window length.

Window: 30 s in 5 s chunks after settle (ceiling 60, 30k ops). Unchanged gates:
clearance ≥ 1.5 m, power bar P_gen ≥ 2.5 kW, ω_gnd > 0.5 rad/s.

## Acceptance tests (RED on master, GREEN after)

| # | Test | Expected |
|---|------|----------|
| A1 | Gate the 5 kW island-1 winner (`results/v12_5kw_coldstart/island_1_best.csv`, L=21.2) | **FAIL** — master's hub gate passed it (6.34 kW) |
| A2 | Twist report from A1 | Flags top-segment crossing: `Δα > δα*` on the worst segment |
| A3 | Detector at post-settle state (before MPPT window) | **No flag** (`Δα≈0`, max ratio < 1) — detector is not trivially always-on |
| A4 | Unit consistency | Reported `P_gen == τ_gen·ω_gnd` as recomputed from `get_generator_torque` + ground-ring ω |

## Blast radius

- `scripts/ode_gate_v13.jl` is a new standalone gate; `gate_length_winners.jl` and
  `ode_gate_5kw_winner.jl` stay as historical record (marked superseded if reused).
- Campaign evaluator (`run_v12_5kw_v3.jl` `eval_v12`) still uses the 10 s window —
  it must be re-instrumented with the same two metrics in a follow-up before any
  new campaign (otherwise DE keeps ranking hub-freewheel designs).
- No `src/` change: physics untouched. The static torsional FoS gate re-enable
  for ≤7 kW rungs is a separate proposal (it was confirmed correct by the ODE).

## DECISIONS entry (drafted, pending green tests)

> **2026-08-13 — ODE gate reads generator-side power and per-segment twist.**
> The V12 gate's `P = k·ω_hub³` metric measured freewheel power during torsional
> collapse (hub ~9 rad/s, ground ring 0 rad/s). Gate power is now
> `τ_gen·ω_gnd` via `get_generator_torque` (same function as the ODE), and a
> per-segment twist check fails any design whose segment twist exceeds the
> geometric crossing limit `δα* = 2·asin(L/√(2(L²+2r²)))`, r = max(r_i, r_{i+1}).
> Consequences: all 2026-08-12/13 5 kW "sustained power" verdicts are void
> (hub freewheel, not transmitted power); no verified 5 kW winner exists.

## Verification

`julia --project=. test/test_gate_v13.jl` — expect A1–A4 green after implementation,
then run the gate on the 18 m/25 m winners and the island-1 winner for verdicts.
