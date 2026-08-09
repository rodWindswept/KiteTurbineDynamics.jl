# Handover — 2026-08-09: V12 Objective for Desktop Campaign

**Commit:** `5c6e94e` (laptop → origin/master)
**Physics era:** V11 warmstart (unchanged) + V12 scoring

---

## 1. What Changed

### New objective: `v12_fitness` in `src/objective_v12.jl`

The V11 objective had no mass penalty and no power floor above 1 kW. The DE
found the "correct" answer to the wrong question: structurally-safe designs
producing 2–3 kW (FoS=142 paperweights) or powerful designs with FoS=0.05
(glass cannons). Never both simultaneously.

V12 fixes the question:

| Constraint | Implementation |
|------------|---------------|
| FoS < 1.5 | Hard reject (1e9) |
| FoS = 3.0 | Ideal — no penalty |
| FoS > 3.0 | Linear penalty (gentle — wasteful) |
| FoS < 3.0 | Quadratic penalty (steep — safety) |
| P < 25 kW | Quadratic penalty (floor) |
| P > 50 kW | Quadratic penalty (ceiling) |

```julia
fitness = -P / (power_window × fos_target)
```

### Rescore of current campaign's 5 "feasible" designs:

| P (kW) | FoS | V11 score | V12 score | What changed |
|--------|-----|:---------:|:---------:|--------------|
| 27.6 | 37.6 | −27.6 | **−16.3** ← best | Least overbuilt, rises to top |
| 58.3 | 142 | −58.3 | −14.6 | FoS=142 → ×3.78 penalty |
| 36.8 | 163 | −36.8 | −8.8 | FoS=163 → ×4.20 |
| 41.8 | 201 | −41.8 | −8.4 | FoS=201 → ×4.96 |
| 25.5 | 287 | −25.5 | −3.8 | FoS=287 → ×6.68 |

**A hypothetical P=35kW, FoS=3.0 design would score −35** — 2× better than
the best current feasible. That is the new attractor.

### Tunable weights (all Refs — no recompilation needed):

```julia
V12_W_FLOOR[]      = 4.0    # P < 25 kW: quadratic weight
V12_W_CEILING[]    = 2.0    # P > 50 kW: quadratic weight
V12_W_FOS_BELOW[]  = 4.0    # FoS < 3.0: steep quadratic
V12_W_FOS_ABOVE[]  = 0.02   # FoS > 3.0: gentle linear slope
V12_FOS_HARD[]     = 1.5    # hard rejection floor
V12_P_FLOOR[]      = 25.0   # kW
V12_P_CEILING[]    = 50.0   # kW
V12_FOS_TARGET[]   = 3.0    # ideal FoS
```

---

## 2. What The Desktop Needs To Do

### Step 1: Pull

```bash
git pull --rebase
```

### Step 2: Switch campaign to V12

In `scripts/run_feasibility_phase_a.jl`, change ONE function:

**Before (line 70):**
```julia
return KiteTurbineDynamics.warmstart_with_k_bracket(
    x, BEAM, P_BASE;
    power_W=POWER_W, v_rated=V_RATED, spoke=SP, lift_device=LIFT_DEVICE)
```

**After:**
```julia
return KiteTurbineDynamics.warmstart_with_k_bracket_v12(
    x, BEAM, P_BASE;
    power_W=POWER_W, v_rated=V_RATED, spoke=SP, lift_device=LIFT_DEVICE)
```

Rename `f_v11` → `f_v12` throughout the script (search-replace). The CSV
column and return tuple shapes are identical to V11 — no schema change needed.

The `objective_feasibility` tier classification is unchanged (it does
simple thresholding, not fitness scoring). Keep it for tier labelling.

### Step 3: Verify before launching full campaign

```julia
using KiteTurbineDynamics
# Smoke test: V12 fitness on a few known points
v12_fitness(30, 3.0)    # → -30.0  (ideal)
v12_fitness(10, 3.0)    # → -4.1   (power floor penalty)
v12_fitness(30, 1.4)    # → 1e9    (hard reject)
v12_fitness(30, 142)    # → -7.9   (FoS penalty)
```

### Step 4: Run campaign

Same POP/GEN config as before. Expect:
- The DE will steer DOWN from high FoS (waste penalty) and UP from low FoS
  (safety penalty), toward FoS≈3.0
- Designs below 25 kW will be penalized — the DE must find actual power
- The Pareto front is still harsh — expect few survivors, but the survivors
  will be honest designs

### Step 5: Tune if needed

If the DE can't find ANY designs scoring better than ~−15, the penalty
slopes may be too steep. Relax `V12_W_FOS_ABOVE` (try 0.01) or
`V12_W_FLOOR` (try 2.0). If FoS=287 designs still dominate, tighten
`V12_W_FOS_ABOVE` (try 0.05).

---

## 3. What This Does NOT Fix

The underlying physics constraints are unchanged:
- **Zero stationary genomes** — V12 inherits V11's stationarity problem.
  Power values are transient-weighted means, not steady-state.
- **Monolithic tube ring model** — even with V12 scoring, the ring topology
  may not be able to deliver P≥25kW AND FoS≥3.0 simultaneously. If the
  campaign produces zero designs above the power floor with FoS≥1.5, the
  answer is honest: the current ring model can't do it.
- **Ring mass** — uses average-radius approximation (one `m_ring_design`
  for all rings via `MaterialSpec`). Fine for DE ranking, rough for absolute
  mass.
- **ODE speed** — unchanged. Same 25–30 min per warmstart eval.

---

## 4. Campaign Config Recommendation

```
POP=6, MAX_GENS=4       # 24 evals max
DECAY_P_THRESHOLD=1.0   # abort below 1 kW at 30s
P_FLOOR=25.0            # match V12 power floor
FOS_DESIGN=1.5          # match V12 hard gate
```

The V12 fitness already penalizes low P and low FoS, so the decay checkpoint
and tier labels are supplementary — the DE will self-reject bad designs
through the fitness landscape.

### Quick-start (paste into Julia REPL after pull):

```julia
using KiteTurbineDynamics
# Seed: V10 winner only (post-A1-A5 — known feasible geometry)
# The DE fitness function is v12_fitness inside warmstart_with_k_bracket_v12
# All weights are live-tunable:
V12_W_FOS_ABOVE[] = 0.02   # adjust before or during campaign
include("scripts/run_feasibility_phase_a.jl")
```
