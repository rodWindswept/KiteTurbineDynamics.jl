# Session Handover — 2026-08-12: Damping Fix & 5kW Baseline

**Status:** 5kW ODE viability confirmed. 57-variant consistency sweep running.  
**Key artifact:** 5kW seed produces 2.69 kW in ODE (target: 5 kW).  
**Next:** Graduate to 7kW rung after consistency gate passes.

---

## What was accomplished

### 1. ζ damping fix (root cause of reverse torque)
- **Found:** `zeta = 1.5` in `initialization.jl:97` — 30-150× physical Dyneema
- **Mechanism:** `max(0.0, EA·ε + c_damp·v)` rectifier in `rope_forces.jl:19`
  creates DC bias from inflated damper → reverse torque at all ω
- **Fix:** ζ promoted to `SystemParams.zeta` field, default 0.05
- **Verified:** Orbital damping exonerated (ΔL_z ~0). c_damp=0 test confirmed.
- **Handover:** `handovers/handover-2026-08-12-zeta-damping-fix.md`
- **1902 tests green.** ODE now spins up and sustains.

### 2. Graduated DE ladder plan (5→50 kW)
- 7 rungs: 5, 7, 10, 15, 25, 35, 50 kW
- Seeds from scaled V10 50kW structural proportions, 5kW n_lines=6 (Daisy-informed)
- Tight bounds per rung via `scripts/compute_seeds.jl`
- Plan: `.hermes/plans/graduated-de-ladder-3kw-to-50kw.md`

### 3. 5kW static evaluator failure (diagnosed)
- **Static evaluator (`evaluate_design_v5`):** all designs fail torsional FoS (< 1.5)
- **Root cause:** τ_cap = T_total × r_min²/√(L²+2r_min²) — bottom ring r_min too small
  at 5kW scale. Daisy 1.5kW (real system that worked) also scores tors=0.22
- **Ramp evaluator (`objective_v12_ramp`):** `solve_equilibrium_self_consistent`
  returns `nothing` at 5kW — equilibrium solver doesn't converge at this scale
- **Conclusion:** Static gates are calibrated at 50kW; false negatives at 5kW

### 4. ODE-based gate (working)
- New approach: `settle_to_operational_state` + `run_canonical_sim!` (5s window)
- Seed produces **2.69 kW at ω=11.14 rad/s** — system is physically viable
- 57-variant perturbation sweep running (±10%, ±20% on all 14 dims)
- Script: `scripts/diag_5kw_ode_gate.jl`

### 5. Campaign script generalized
- `scripts/run_v10_campaign.jl` now accepts `--power N` for any N
- Power-aware DE defaults, `--tight` mode uses compute_seeds.jl bounds
- `--seed`, `--popsize`, `--islands`, `--generations` flags added
- All `params_v5_50kw()` references replaced with `mass_scale(params_10kw(), 10.0, kw)`

### 6. Active campaign: V12 cold-start 5kW (`scripts/run_v12_5kw.jl`)
- **Why V12 not V10:** V10 static campaign produced 0.48 kg junk — mass-minimisation with
  no power gate shrank designs to bounds. V12 measures real ODE P/FoS/stationarity.
- **Config:** cold-start mode (`start_mode=:cold` — warmstart equilibrium solver fails
  at 5kW), 5s relax + 10s window, scaled ObjectiveConfig (floor 2.5 kW, ceiling 5 kW).
- **DE:** 10 pop × 3 islands × 30 gen, seeded population (known-good seed + 9 random),
  eval cache, GC between evals, per-generation best-genome saves (crash-proof).
- **Observed:** gen 0 best = -0.38; gen 1 = -2.10; gen 13 = -3.58 (first run, lost to
  reboot). ~65s/eval. ~12 min/gen. 12h timeout covers ~islands 1-2.
- **Output:** `scripts/results/v12_5kw_coldstart/` — convergence.csv (progressive),
  island_N_best.csv + _meta.txt (per-generation).

### 7. ODE gate verdict — V12 fitness ≠ gate ranking (2026-08-13)

> **SUPERSEDED (2026-08-13, same day):** the "gate-passing" 6.34 kW was
> hub freewheel power, not transmitted power. The island-1 winner's
> torsional chain COLLAPSES at the top segment (Δα=22,425° at t=60s),
> ω_gnd→0, generator output zero. The gate reads ω_hub but the generator
> extracts k·ω_gnd³. The static torsional gate (0.31, "collapses") was
> CORRECT. See `scripts/results/v12_5kw_coldstart/ode-power-budget-collapse-finding-2026-08-13.md`.
> No verified 5kW winner exists. Historical record follows:

The campaign completed (12h timeout, island 3 partial). ODE gating the
winners REVERSED the ranking:

| Design | V12 fitness | Gate P_final (20s) | Verdict |
|--------|------------|--------------------|---------|
| Island 2 winner | -4.67 (best) | 1.71 kW | ❌ fails |
| **Island 1 winner** | -3.58 | **6.34 kW** | ✅ winner |
| Island 3 partial | 0.84 | 2.62 kW | ✅ barely |
| Original seed | — | 4.86 kW | ✅ |

**Mechanism:** island 2's genome collapsed to n_active=1 (single rotor) —
it scores well in the 10s V12 window via the flywheel effect (extracting
settle energy) but decays to 1.71 kW by 20s. The 10s window is too short
to catch late decay. The 20s gate does.

**5kW rung winner (verified):** island 1 genome — n_lines=16, rings=9,
n_active=3, r_hub=0.65m — sustains 6.34 kW at 20s (above rated 5 kW).
Genome: `scripts/results/v12_5kw_coldstart/island_1_best.csv`.

**Pipeline lesson:** use a 20s+ ODE gate and require the winner to pass it
before seeding the next rung — V12 fitness alone picks flywheel designs.
Next rung seeds with the island-1 winner, not the fitness-best island-2.

## Files changed

| File | Change |
|------|--------|
| `src/parameters.jl` | +zeta field (0.05 default) |
| `src/initialization.jl` | `zeta = p.zeta` |
| `scripts/run_v10_campaign.jl` | Generalized power scaling, tight bounds, new flags |
| `scripts/compute_seeds.jl` | Seed/bounds generator for all 7 rungs |
| `scripts/bounds_audit.jl` | Full 14-dim bounds audit |
| `scripts/diag_5kw_ode_gate.jl` | ODE fitness function + consistency sweep |
| `handovers/handover-2026-08-12-zeta-damping-fix.md` | Damping fix writeup |
| `.hermes/plans/graduated-de-ladder-3kw-to-50kw.md` | Ladder plan |

## Diagnostic scripts (artifacts)

| Script | Purpose |
|--------|---------|
| `scripts/diag_orbital_damping_Lz.jl` | ΔL_z at high ω |
| `scripts/diag_orbital_damping_Lz_lowomega.jl` | ΔL_z at low ω |
| `scripts/diag_cdamp_zero.jl` | c_damp=0 isolation |
| `scripts/diag_zeta_005.jl` | ζ=0.05 confirmation |
| `scripts/diag_zeta_validate.jl` | End-to-end ODE validation |
| `scripts/diag_ramp_reject.jl` | Ramp evaluator failure trace |

## 5kW bounds (final, Rod-approved)

| # | Parameter | Seed | [Lo, Hi] |
|---|----------|------|-----------|
| 1 | Do_top (m) | 0.019 | [0.009, 0.028] |
| 2 | t_over_D | 0.010 | [0.005, 0.015] |
| 3 | beam_aspect | 0.880 | [0.440, 1.320] |
| 4 | Do_scale_exp | 1.000 | [0.400, 1.600] |
| 5 | r_hub (m) | 0.914 | [0.200, 2.200] |
| 6 | r_bottom (m) | 0.632 | [0.316, 0.949] |
| 7 | target_Lr | 2.988 | [1.000, 4.183] |
| 8 | n_lines | 6 | [3, 16] |
| 9 | density | -0.11 | [-0.80, 0.80] |
| 10 | rotor_mask | 18.56 | [0, 19] |
| 11 | bank_top (°) | 15 | [0, 22] |
| 12 | bank_bottom (°) | 15 | [0, 22] |
| 13 | λ_top | 0.519 | [0.104, 1.0] |
| 14 | λ_bottom | 0.100 | [0.050, 1.0] |

## Pending

- 57-variant consistency sweep (running)
- Wire ODE fitness into campaign script for 5kW rung
- Launch 5kW DE campaign once consistency confirmed
- Graduate to 7kW rung
