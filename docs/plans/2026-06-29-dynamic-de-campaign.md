# Plan: Dynamic-Aware DE Campaign — V10 50 kW Viable Structure
#
# **Date:** 2026-06-29
# **Status:** Ready to implement
# **Depends on:** `scripts/builders_util.jl` (keyword params), DECISIONS.md findings,
#   dashboard v2 framework (`src/dashboard_panels.jl`, `src/sim_runner.jl`)
#
# **Reference:** Parallel dashboard v2 work session handover at
#   `/media/rod/Stored/Windswept_Energy/SESSION_HANDOVER_2026-06-30.md`

## What we know (2026-06-29)

1. **Static solver is insufficient.** `settle_to_equilibrium()` + `solve_equilibrium_omega()`
   compute ω_eq from P_aero = k·ω³ — no TRPT torsional dynamics. The DE optimiser
   evaluates candidates against the WRONG physics. Two independent proofs confirm this:
   - V10 Tight: no k_mppt produces P≥50kW AND FoS≥1.5 simultaneously
   - Conservative DE campaign: best design produces 8.6 kW dynamically (17% of rated)

2. **Bottom rings are the bottleneck.** Per-ring `ring_element_analysis` confirms ring 1
   (lowest airborne ring) ALWAYS fails first. The taper goes 1.33m→1.58m (smallest at
   bottom) — structurally backwards for a torque-accumulating shaft.

3. **Control-first methodology works.** Sweep wind speeds, hunt k_mppt that hits P_rated,
   record FoS. Viable designs must have FoS≥1.5 everywhere. The canonical 10kW system
   validates the approach at 11 m/s (k=4→10.2kW, FoS=38).

4. **Reinforced V10 is viable.** Using `build_kite_turbine_system_v5` (ring_spacing_v4
   geometry) with r_bottom_scale=1.30 + 4mm tethers: all 20 rings pass FoS≥2.3,
   P=55kW at k=200. The builder supports keyword params for tether_diameter and
   r_bottom_scale.

5. **Controller improvements ready.** dP/dk sign detection, warm start, HOLDING
   unblocked, Kp slider, collapse margin slider all active.

6. **4mm tethers alone don't help.** Thicker tethers increase SWL but ring buckling
   (not line tension) is the limiting factor for V10 Tight.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  DYNAMIC-AWARE DE CAMPAIGN                                  │
│                                                             │
│  For each candidate design vector x:                        │
│    ┌──────────────────────────────────────────────────┐    │
│    │ 1. Build system from vector                       │    │
│    │    sys, u0, p = build_from_vector_v10(x)          │    │
│    │                                                    │    │
│    │ 2. Hunt k_mppt at each wind speed                  │    │
│    │    For v ∈ [5, 7, 9, 11, 13, 15] m/s:            │    │
│    │      k* = bisect k ∈ [2, 5000] such that          │    │
│    │           |P(k) − P_rated| < ε                   │    │
│    │      Run 60s verify at k*                          │    │
│    │      Record FoS(v), P(v), ω(v)                     │    │
│    │                                                    │    │
│    │ 3. Score the candidate                              │    │
│    │    IF any FoS(v) < 1.5:                             │    │
│    │      penalty = 1e6 × (1.5 − min_FoS)               │    │
│    │      return mass + penalty                          │    │
│    │    ELSE:                                            │    │
│    │      P_penalty = mean(|P(v) − P_rated|/P_rated)    │    │
│    │      return mass × (1 + 0.1 × P_penalty)            │    │
│    └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Implementation steps

### Phase 1: Bisection hunt (1 hour)

File: `scripts/hunt_kmppt_bisect.jl`

- Replace coarse grid hunt with proper bisection
- For each wind speed, bracket the crossing:
  - If P(k_min) > P_rated: searching right flank, seek k where P drops to target
  - If P(k_max) < P_rated: power deficit, best we can do
  - Bisect with tolerance ε = 0.5 kW
- Use 5s sims for bisection iterations
- 60s verify at final k*

### Phase 2: Control map script (1 hour)

File: `scripts/map_control_law.jl`

- Takes a builder function + label as arguments
- Uses Phase 1 bisection hunt
- Outputs CSV with per-ring FoS columns
- Generates control map figure (k(v) + FoS(v))

### Phase 3: Dynamic-aware objective (2 hours)

File: `src/objective_v10_dynamic.jl`

- Wraps the existing `design_from_vector_v10()` with dynamic evaluation
- Calls the control map for each candidate
- Returns mass + FoS penalty
- Compatible with the DE campaign framework (same vector format)

### Phase 4: Small validation campaign (launch overnight)

- 20 islands × 40 population
- Target: find first viable V10 geometry (FoS≥1.5, ~50kW)
- Expected: 27 hours compute
- If successful, scale to full 60-island campaign

### Phase 5: Analysis

- Plot control map for the winning design
- Compare headless vs dashboard verification
- Export k(v_wind) control law table
- Per-ring FoS heatmap showing structural margin across wind speeds
- Publishable figure: control map + structural envelope

## Pitfalls

- **Bisection needs the RIGHT flank at high wind.** k>100 produces P≈0 in 2s sims —
  the settle finds a heavily-braked equilibrium. Need 5s+ sims for accuracy.
- **Overshoot penalty needed.** Without it, the hunt picks k→0 (overspeed) because
  the raw error is smaller than the stall-side alternative.
- **System rebuild per candidate.** The DE evaluates thousands of candidates;
  building the system and running 6 wind-speed sweeps per candidate is expensive.
  Need profiling to see if culling infeasible candidates early saves time.
- **`build_kite_turbine_system_v5` needed for structural consistency.**
  The standard linear-taper builder produces ~1.33m rings; the design evaluates
  at ~3m. v5 matches. But v5 changes ring count — expansion rotor placement
  needs verification at each candidate.

## Timeline

| Phase | Duration | When |
|---|---|---|
| 1. Bisection hunt | 1h | Next session |
| 2. Control map script | 1h | Next session |
| 3. Dynamic objective | 2h | Next session |
| 4. Small campaign | 27h | Overnight |
| 5. Analysis | 1h | Morning after |

**Total: 5 hours coding + 27 hours compute.**
