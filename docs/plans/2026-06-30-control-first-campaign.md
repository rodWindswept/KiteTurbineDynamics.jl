# Plan: Control-First Design Campaign — Finding a Viable TRPT Structure

**Date:** 2026-06-30
**Status:** Work initiation — Phase 1 building
**Depends on:** `scripts/hunt_kmppt_bisect.jl` (to be written)

## Motivation

The DE campaign from V2–V10 used a static equilibrium solver that assumes instant, lossless torque propagation through the TRPT. Two independent proofs (2026-06-28) confirm this is fundamentally wrong:

1. **V10 Tight:** No k_mppt simultaneously gives P ≥ 50 kW AND FoS ≥ 1.5. At k=550, power hits 50 kW but FoS=0.75 with progressive buckling. At k≤350, FoS≥1.5 but only ~27 kW.
2. **Conservative DE campaign:** A 60.8 kg design optimised under static constraints produces only 8.6 kW dynamically (17% of rated).

Root cause: the static solver under-predicts the dynamic k_mppt by 3–4×. The DE optimiser evaluates candidates against the wrong physics. This plan replaces the static solver with dynamic simulation in the objective function.

---

## TRPT Control-Space Physics — Why Simpler Models Fail

### 1. The TRPT is a Transmission Line, Not an Equilibrium Point

The static solver does `find ω where P_aero(ω) = k·ω³` — one equation, one unknown, instant torque propagation.

The dynamic multibody ODE is a distributed torsional spring-damper chain:

```
Rotor → [ring₂, ring₃, ..., ringₙ] → Generator
         ↑ k_sec, c_s per pair ↑
```

Each ring pair has its own torsional stiffness `k_sec` and damping `c_s`. Torque propagates as a wave — the generator only "sees" rotor torque after the wave travels the full shaft length. This is impedance-matching through a flexible transmission line, not a simple equilibrium.

### 2. The P(k) Curve Has Two Flanks — and the TRPT Smears Both

Generator load law: τ_gen = k·ω². On a rigid-shaft turbine, P(k) is a single hump: left flank (dP/dk > 0), peak, right flank (dP/dk < 0).

For the TRPT, shaft compliance smears this curve:
- At high k: shaft winds up, rotor slows, but torsional load on bottom rings increases
- At low k: rotor overspeeds (low generator resistance), thrust and aero torque spike → rings fail from thrust

The V10 Tight data shows both failure modes:

| k_mppt | P | ω_hub | FoS | Failure mode |
|--------|---|-------|-----|--------------|
| 62 | 132 kW | 123 rpm | 0.43 | Overspeed — too little generator load |
| 550 | 49→21 kW | 52→32 rpm | 0.75→0.26 | Torsional — shaft buckles progressively |

**Both modes destroy the structure. There is no k that works for V10 Tight.**

### 3. The Taper Is Structurally Backwards

Torque ACCUMULATES downward — ring 1 (lowest airborne) carries the full torque from all rotors. The taper goes small-at-ground → large-at-hub:

```
Ring 1 (ground):  r = 1.33m, sees FULL accumulated torque
Ring 22 (hub):    r = 1.58m, sees only the hub rotor's torque
```

Ring buckling FoS ∝ r². The smallest ring takes the biggest load. The reinforced V10 test (cylindrical 3m, r_bottom_scale=1.30) proves flipping this solves the problem: 55 kW, FoS≥2.3, zero rings failing.

### 4. Why Bisection, Not a Grid

The P(k) curve crosses P_rated at TWO points: left flank (low k, high ω, high thrust) and right flank (high k, low ω, high torsion). For the TRPT, the right-flank crossing is the structurally dangerous one.

Grid-based hunts fail because:
- At low k the overshoot is huge → `argmin(|P-P_rated|)` picks the overshoot
- The overshoot-penalty band-aid (5× multiplier) is fragile across wind speeds

Bisection is correct: bracket the crossing, converge to ±0.5 kW. Must handle the case where P(k) NEVER reaches P_rated.

### 5. The FoS Gate is Multi-Dimensional

Minimum across:
- All rings: Euler buckling FoS ≥ 1.5
- All inter-ring segments: Tulloch collapse margin (δα* − |Δα|) > 5°
- All tethers: tension FoS ≥ 3.0

AND must hold at ALL operating wind speeds (5, 7, 9, 11, 13, 15 m/s), not just rated.

### 6. Why Canonical 10 kW is the Validation Case

5 lines, single rotor, FoS=38 at rated, k≈4. The shaft is so overdesigned relative to the 10 kW power level that the static-vs-dynamic gap is negligible — the TRPT behaves like a rigid shaft. This validates the methodology on a known-good system before applying it to the edge case.

---

## Architecture: Dynamic-Aware DE Campaign

```
For each candidate design vector x:
  ┌──────────────────────────────────────────────────┐
  │ 1. Build system from vector                       │
  │    sys, u0, p = builder(x)                        │
  │                                                    │
  │ 2. Hunt k_mppt at each wind speed                  │
  │    For v ∈ [5, 7, 9, 11, 13, 15] m/s:            │
  │      Bracket P(k) around P_rated                  │
  │      Bisect k ∈ [2, 5000] to within ±0.5 kW       │
  │      Run 60s verify at k*                         │
  │      Record: k*, P, ω, FoS, collapse_margin       │
  │                                                    │
  │ 3. Score the candidate                             │
  │    IF any FoS(v) < 1.5:                            │
  │      penalty = 1e6 × (1.5 − min_FoS)              │
  │      return mass + penalty                         │
  │    ELSE:                                           │
  │      P_score = mean(|P(v)−P_rated|/P_rated)       │
  │      return mass × (1 + 0.1 × P_score)             │
  └──────────────────────────────────────────────────┘
```

The control law k(v_wind) is an OUTPUT of the viability check, not a separate problem. A design that passes the hunt at all winds with FoS≥1.5 has both its geometry AND its control law solved.

---

## Implementation Phases

### Phase 1: Bisection Hunt Script

**File:** `scripts/hunt_kmppt_bisect.jl`

- Takes builder function, rated power, wind speeds
- For each wind speed: bracket, bisect, 60s verify
- Records per-ring FoS, per-segment collapse margin, tether tension
- Outputs CSV at `scripts/results/control_maps/<name>_control_map.csv`
- **Validate on canonical 10 kW:** expect k≈4 at 11 m/s, FoS≥38

### Phase 2: DE Objective Wrapper

**File:** `src/objective_dynamic.jl`

- Wraps the hunt script as a DE-compatible objective function
- Takes design vector → returns fitness score

### Phase 3: Campaign Runner

**File:** `scripts/run_dynamic_campaign.jl`

- 20 islands × 40 pop (validation), ~27 hours on 32 threads
- BlackBoxOptim DE: F=0.7, CR=0.9
- Incremental CSV checkpointing
- Bounds incorporating V10 lessons: bank≤25°, r_bottom≥r_hub×0.7, λ∈[0.05,1.0], n_lines≤12

---

## Design Bounds (Lessons from V2–V10)

| Parameter | Min | Max | Rationale |
|-----------|-----|-----|-----------|
| bank_angle | 5° | **25°** | Pitch depower blade-tip clearance at θ=65° |
| n_lines | 3 | 12 | Strip theory not validated above n=12 |
| λ (blade scale) | 0.05 | 1.0 | Below 0.05 = functionally rotorless |
| r_bottom | 0.5m | r_hub | Must carry 3× tether attachment geometry |
| r_hub | 2.0m | 6.0m | Practical rotor sizing for 50 kW |
| Do_top | 0.05m | 0.30m | Manufacturing floor to reasonable upper |
| t_over_D | 0.01 | 0.05 | Wall thickness ratio |
| n_expansion | 0 | n_lines | One blade per polygon vertex |
| target_Lr | 0.8 | 3.0 | Slenderness ratio |

---

## Validation Gates

1. **Canonical 10 kW:** Bisection hunt finds k≈4, FoS≥38 at 11 m/s — proves the methodology works
2. **V10 Tight:** Confirms NO k_mppt satisfies both P≥50 kW AND FoS≥1.5 — reproduces the known-dead result
3. **Reinforced V10:** Cylindrical 3m with r_bottom_scale=1.30 — should pass all gates (55 kW, FoS≥2.3)

---

## Key References

- `DECISIONS.md` — §2026-06-28 (static-vs-dynamic proof), §2026-06-29 (reinforced V10, builder disconnect)
- `docs/plans/2026-06-28-control-first-design.md` — original control-first concept
- `docs/plans/2026-06-29-dynamic-de-campaign.md` — dynamic-aware DE architecture
- `scripts/builders_util.jl` — V10 builders with keyword params
- `scripts/hunt_kmppt.jl` — existing grid-based hunt (reference, will be replaced)
- `src/sim_runner.jl` — build_rerun! (may be reusable for the hunt)
