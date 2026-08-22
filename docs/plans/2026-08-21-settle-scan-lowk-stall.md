# Proposal — settle-scan operating-point selection causes low-k dead-chain rejects (2026-08-21)

**Status:** proposal for Rod's approval. RED acceptance tests first, then implement, then re-run k sweep.

## The question

Rod asked: *why would a LOWER k_mppt make the seed stall? That makes no sense.* It doesn't —
it isn't a stall. It's a settle-scan artifact that produces a **silent dead-chain state**.

## Evidence

k sweep (`scripts/results/k_sweep_daisy_5kw.csv`) and re-traces on current physics:

| k | settle ω_eq | λ_eq | cp_eq | P_aero(kW) | P_gen(kW) | margin | status |
|---|---|---|---|---|---|---|---|
| 0.5 | 19.36 | 8.00 | 0.138 | 3.99 | 3.63 | 10% | reject, P=0 |
| 3.0 | 13.95 | 5.76 | 0.285 | 8.28 | 8.14 | 2% | reject, P=0 |
| 4.0 | 12.74 | 5.26 | 0.307 | 8.92 | 8.28 | 8% | reject, P=0 |
| 5.39 | 11.54 | 4.77 | 0.306 | 8.89 | 8.28 | 7% | **ok, P=7.15 kW** |

Trace of the window (ω_gnd first → last): k=0.5: 19.4 → 11.2; k=3.0: 14.6 → 10.7;
k=4.0: 13.7 → 10.4; k=5.39: 12.4 → 10.1. **Every case spins; only k=5.39 transmits.**

Rejected rows report `P=0.0, FoS=Inf` — the evaluator's P is `τ_gen·ω_gnd` with τ_gen
carried by rope twist, so **P=0 + ω_gnd≈11 + FoS=Inf (no tension) = the chain is slack
and disengaged**, not a stalled rotor.

## Root cause

**The machine never stalls — the reject telemetry zeroes the truth.**

`settle_to_operational_state` (src/initialization.jl) picks the operating point by
scanning ω from 60 rad/s **downward**, taking the FIRST ω where the simplified
power balance holds:

    P_aero(ω) = 0.5·ρ·v³·A_annulus·cp(λ)·cos(β)^2.65
    P_gen(ω)  = k·ω³
    first ω where P_aero > P_gen  →  ω_eq

For LOW k the crossing lands at HIGH ω (k=0.5 → ω=19.4 = λ=8.0, the cp TABLE
EDGE) — a knife-edge start with ~10% margin in the settle model that the real
ODE (rope drag, bearing/orbital damping) erases. The ODE then relaxes to its
true equilibrium (~10–11 rad/s for every k) and transmits P = k·ω³ there:

| k | settle ω_eq | true ω_gnd eq. | true P = k·ω³ | window result |
|---|---|---|---|---|
| 0.5 | 19.4 (λ=8.0, table edge) | ~11.2 | ~0.7 kW | reject, P=0, FoS=Inf |
| 3.0 | 14.0 | ~10.7 | ~3.4 kW | reject, P=0, FoS=Inf |
| 4.0 | 12.7 | ~10.4 | ~4.5 kW | reject, P=0, FoS=Inf |
| 5.39 | 11.5 (λ=4.8, near peak) | ~10.1 | ~5.5–6.0 kW | **ok, 7.15 kW** |

The reject is the **5 kW power floor doing its job** — low k genuinely makes
low power (the classic MPPT curve: lower k → slightly higher ω, much lower
P = k·ω³). But `mass_min_fitness` returns Inf below the floor, and the
evaluator then calls `rejected_eval(ω_eq)` which **zeroes P_mean, P_end,
FoS_min and T_lift**. The k sweep therefore read "0.0 kW, FoS=Inf" = "stall"
when the machine was actually transmitting 0.7–4.5 kW with healthy chain
state (trace evidence: ω_hub ≈ ω_gnd, twists 2–4° vs 30–78° limits, tension
600–1260 N, τ_rope 431–748 N·m, tip ≤ 65 m/s vs 100 ceiling).

## Secondary finding — the k sweep is stale

The sweep that selected k=5.39 ran at 20:59 on **pre-Gate-1c physics** (m_blade
0.420 kg, lifter mass included: T_lift=305.6 N, m_airborne≈19.5 kg). The campaign
launched 21:15 on **post-Gate-1c** (m_blade 0.210 kg, lifter excluded: T_lift=205.4 N,
m≈13.1 kg). Re-check on current physics: **k=4.0 now rejects** (sweep CSV says ok,
6.61 kW). Only k=5.39 survives. The knee moved; the selection was tuned on a machine
that no longer exists.

## Fix (implemented 2026-08-21, in working tree)

1. **Honest reject telemetry (the real fix).** The fitness-seam reject no longer
   calls `rejected_eval(ω_eq)` (which zeroes P_mean/P_end/FoS/T_lift). It now
   returns `status=:reject, fitness=Inf` **carrying the measured window
   statistics**, so the k sweep and campaign telemetry read "4.5 kW, below the
   5.0 kW floor" instead of a fabricated "0 kW stall". Status and fitness are
   unchanged — gates and the DE behave identically; only the recorded numbers
   are truthful.
2. **Settle scan clamp to the cp peak.** The ω scan now starts at
   `min(ω_rated_max, λ_peak·v/R)` (λ_peak ≈ 5.2 from the BEM table) instead of
   60 rad/s, so low-k settles never park on the falling flank / table edge
   (λ=8.0). The ODE still finds its own equilibrium; the healthy k=5.39 case
   is bit-identical (its crossing at λ=4.8 is already below the peak).
3. **Re-run the k sweep** on current physics (post-Gate-1c) so the knee is
   measured on the machine that will run.

### Why the clamp is safe

- The settle's job is to hand the ODE a *productive* starting state; the ODE then
  finds its own equilibrium. Starting near the cp peak gives maximum torque surplus.
- k=5.39 crossing (λ=4.77) is already ≤ λ_peak → **bit-identical for the working case**.
- High-k overloads (crossing below λ_peak with no margin) still reject as before.

## Acceptance tests (RED on current master first)

1. **A1 — low-k chain engages.** Daisy seed (5 kW, L=18.8 m, cold start), k=0.5:
   expect `P_mean > 0` (currently 0.0) — the machine must transmit, not coast.
   Reject may still happen at the 5 kW power floor (honest low-power reject), but
   the dead-chain signature (P=0, FoS=Inf, ω_gnd>5) must NOT appear.
2. **A2 — k=4.0 works on current physics.** Same seed, k=4.0: expect P_mean > 0
   (currently 0.0; pre-Gate-1c sweep claimed 6.61 kW).
3. **A3 — k=5.39 unchanged (bit-identical guard).** Same seed, k=5.39: expect
   P_mean = 7.15 kW (exact value from the 21:15 run's seed row and my repro) —
   the clamp must not perturb the healthy case.
4. **A4 — status taxonomy.** The evaluator exposes `:dead_chain` distinctly from
   `:reject`; a unit test asserts the new classification path.

## Files

- `src/initialization.jl` — settle scan range clamp (fix 1)
- `src/objective_evaluator.jl` — dead-chain classification (fix 2)
- `test/acceptance_runtests.jl` + new `test/test_dead_chain.jl` (A1–A4)
- `scripts/sweep_k_mppt_5kw.jl` — re-run after fix (fix 3)

## Blast radius

- Only the cold-start settle scan range changes; warm-start and dashboard paths
  untouched (they call `settle_to_equilibrium`, not the ω scan).
- k=5.39 / healthy seeds: bit-identical guard A3 proves no regression.
- Low-k behavior changes from "silent dead chain" to either transmitting
  (low power) or a distinct dead-chain reject — both more honest than the
  current indistinguishable P=0.

## Evidence saved

- `/tmp/diag_lowk_trace.log` — ω traces per k
- `/tmp/diag_chain_state.log` — segment twist/tension/τ traces k=4.0 vs 5.39
- `scripts/diag_settle_scan_probe.jl`, `scripts/diag_lowk_trace.jl`,
  `scripts/diag_chain_state.jl`, `scripts/diag_repro_masslift_death.jl`
