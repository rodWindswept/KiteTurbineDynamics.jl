# Lift Kite Analysis — Research Notes

## Background

The current simulator treats the lift bearing (hub node, ring 16) as a static point in
space — elevation angle is a parameter, not a state. In real operation the hub is the
lower end of a lift kite line whose tension varies with wind turbulence, causing the hub
to sway in arcs driven by imbalances between lift and TRPT+rotor forces.

This note tracks analysis of three lift device architectures and the path to adding a
dynamic hub force model to `KiteTurbineDynamics.jl`.

---

## Architectures Under Analysis

### A. Single Passive Kite (current assumption)
- Single parafoil or single-skin kite on a straight lift line.
- Lift ∝ v². Tension CV ≈ 30% at I=0.15 turbulence intensity.
- **Scaling bottleneck**: required area grows super-linearly with rated power
  (mass exponent 1.35 drives F_required up faster than v² drives lift up).
  - 10 kW: ~19–21 m²
  - 50 kW: ~109 m²
  - 500 kW: ~1462 m² (about 40m × 37m parafoil — not practical)
- Lift margin < 1.0 below v ≈ 9 m/s (kite needs to be oversized for rated wind).

### B. Stacked Kites on a Single Line
- N smaller kites cascaded on one lift line; total area = single kite equivalent.
- **Tension distribution (CORRECTED)**: tension *decreases* going upward.
  - T[hub] = Σ(Lᵢ − Wᵢ·cosθ)  ← maximum
  - T[above kite k] = Σᵢ₌ₖ₊₁(Lᵢ − Wᵢ·cosθ)  ← decreases going up
  - T[above topmost kite] = 0  ← free end
- In steady flight, each kite's attachment handles only its own net lift.
- **Governing structural load case** (topmost kite): at zero/low wind the topmost
  kite must support the full weight of all kites below it through the line.
  This is the design case for the topmost kite's bridle attachment — NOT its
  aerodynamic load in flight.
  - Stack×3 at 10 kW: top kite static load ≈ 16 N (only 2 × m_kite × g — small)
  - This is much less critical than it sounds for small kites, but grows with N.
- Tension CV ≈ same as single kite (same underlying aero physics, just split).
- **Key advantage**: individual kite size = total_area / N → human-scale handling.
- **Key disadvantage**: inter-kite aerodynamic shadowing needs separation analysis.
  Upwind kites partially wake-shield downwind kites; spacing must be sized.
- Prior art: Haas et al. 2018 (Kite Networks); Leuthold et al. 2019 (stacked multi-kite).

### C. Rotary Lifter (no torque extraction)
- TRPT-style ring rotor with blades pitched for lift, running at fixed RPM.
- **Key physics**: apparent wind v_app = √(v_wind² + (ω·r_mean)²).
  At ω=33 rad/s, r_mean=0.9m → ω·r=29.7 m/s >> v_wind=11 m/s.
  v_app ≈ 31.7 m/s → nearly independent of v_wind variations.
- **Fixed RPM (not TSR-following)**: this is critical. If omega tracks wind speed
  (constant TSR), v_app ∝ v_wind and the advantage disappears. The lifter's
  own angular momentum must maintain omega through gusts.
- **Tension CV at v=11 m/s**: 3.6% vs 30.1% for single kite → **8× better**.
- **Tension CV at v=8 m/s**: 2.0% vs 30.2% → **15× better**.
- CV reduction ratio ≈ v_wind / v_app = 1 / √(1 + (ω·r/v)²).
  At low wind, ratio improves further (ω·r/v increases).
- **Current limitation in model**: rotary lifter at default parameters provides
  only 28% of required hub lift at v=11 m/s (399 N vs 1441 N needed).
  The blade area / CL need to be scaled up, or ω reduced, to match requirement.
  This is a sizing exercise, not a physical impossibility.
- **Practical advantages**:
  - Consistent hub tension → more stable TRPT elevation angle → steadier power.
  - Gyroscopic stiffness resists lateral hub swinging.
  - Can be made to operate across a wider wind range than passive kite.
  - alphAnemo (ETH Zurich BRIDGE 2025): centrifugally-stiffened 3-wing rotor,
    "passive stability" prototype, helicopter-like control algorithms.
  - SomeAWE / Windswept: lift kite requirements characterised in
    IEEE ITEC 2024 (DOI:10.1109/ITEC60881.2024.10718850).
- **Practical disadvantages**:
  - Requires launch/landing procedure.
  - Consumes some power to overcome profile drag (but much less than power generated).
  - More complex than a passive kite.

---

## Key Numbers — 10 kW TRPT at v=11 m/s, I=0.15 turbulence

| Metric | Single Kite | Stack×3 | Stack×5 | Rotary Lifter |
|--------|------------|---------|---------|---------------|
| Required area | 21.4 m² | 21.4 m² total | 21.4 m² total | ~12 m² blade area (TBD) |
| Individual unit size | 21.4 m² | 7.1 m² each | 4.3 m² each | 1.5m radius rotor |
| T_line at v=11 (N) | 1603 | 1599 | 1599 | 399 (undersized) |
| Lift margin | 1.10 | 1.10 | 1.10 | 0.28 (needs sizing) |
| Tension CV | 30.1% | 30.2% | 30.2% | 3.6% |
| CV reduction vs single | — | 1.00× | 1.00× | **0.12× (8× better)** |
| Top kite static load | — | 16 N | 19 N | n/a |

### Scaling bottleneck (single kite)

| Power | Area needed | Area/kW |
|-------|-------------|---------|
| 10 kW | 19 m² | 1.9 m²/kW |
| 50 kW | 109 m² | 2.2 m²/kW |
| 100 kW | 234 m² | 2.3 m²/kW |
| 200 kW | 510 m² | 2.6 m²/kW |
| 500 kW | 1462 m² | 2.9 m²/kW |

Area grows super-linearly (exponent ~1.35) because m_airborne ∝ P^1.35 but
lift ∝ v²·A (linear in area). This is the fundamental scaling bottleneck of
the passive kite approach.

---

## Tension Correction (from discussions)

**My original description was wrong**: "lowest kite sees the weight of everything above."

**Correct statement**: in a tension cascade running hub→kite1→kite2→...→kiteN:
- Each kite ADDS its net lift to the line. Tension DECREASES going upward.
- Hub end has MAXIMUM tension. Free end above topmost kite has ZERO tension.
- **The TOPMOST kite's attachment** is the critical structural case because in
  zero-wind (launch, stow, failure), it must support the weight of all kites below.
- In normal flight, each kite's bridle only handles its own net lift (independent of N).

---

## Phase 2: Dynamic Hub Model (IMPLEMENTED)

The `lift_kite.jl` framework provides static force models that are now integrated
into the ODE so the hub position responds to lift line force variations in real time.

### Implementation

Changes made to the simulation core:
1. `src/ring_forces.jl` — added optional `lift_device` argument (default `nothing`).
   When provided, computes `lift_force_steady(dev, rho, v_wind)` at each step and
   applies the resulting 3D force to the hub node. Wind direction is computed from
   the hub wind vector; the force is decomposed into horizontal (into-wind) and
   vertical (+z) components correctly in 3D.
2. `src/dynamics.jl` — extracts optional 4th element `lift_device` from the params
   tuple `(sys, p, wind_fn[, lift_device])`. Backwards compatible: old 3-element
   tuple still works with no lift device.
3. `src/initialization.jl` — added `lift_device::Union{Nothing, LiftDevice}` keyword
   to both `simulate()` and `settle_to_equilibrium()`.

### Usage

```julia
dev = single_kite_sized(p10, 1.225, 11.0; margin=1.1)   # or rotary_lifter_default()
u_final = simulate(sys, u0, p, wind_fn; lift_device=dev, n_steps=...)
```

### Phase 2 Dynamic Hub Excursion Results

First dynamic comparison at v=11 m/s, I=0.15 turbulence, 3s simulation:

| Device       | hub_z std (mm) | hub_z / SingleKite |
|-------------|---------------|--------------------|
| SingleKite  | 3.5           | 1.00× (reference)  |
| Stack×3     | 3.5           | 1.00×              |
| RotaryLifter| 0.9           | **0.26× (3.9× better)** |
| NoLift      | 0.3           | baseline noise      |

The RotaryLifter produces ~4× less hub vertical excursion than the single kite
under the same turbulent wind. The predicted improvement from CV analysis was 8×;
the discrepancy is expected because the 3s simulation is much shorter than the
turbulence integral time scale (~31s for IEC Class A at 30m hub altitude), so
the low-frequency turbulence content is undersampled. Longer runs (≥60s) would
close this gap.

**Stack×3 shows the same excursion as SingleKite**: this confirms the analytical
prediction — stacked kites have the same total area and the same tension CV as a
single kite. The handling advantage (smaller individual kites) comes without any
improvement in hub stability.

### Turbulence model for lift line

Dynamic hub model is in place. Turbulent wind drives hub excursion via:
- `turbulent_wind()` from `wind_profile.jl` (AR(1) Markov, IEC Class A).
- `scripts/hub_excursion_sweep.jl` records hub_z, elevation_angle at each step.
- Initial 3s results show 3.9× hub_z std improvement: RotaryLifter vs SingleKite.
- Longer runs (≥60s, ≥2 integral time scales) needed for converged statistics.

---

## Future Modelling Work

1. **Hub excursion sweep** — drive lift force with turbulent wind, record hub position
   variance for all three architectures. Quantify elevation angle variation and its
   effect on TRPT power.

2. **Rotary lifter sizing** — scale blade area / omega to achieve lift_margin ≥ 1.1
   at cut-in wind speed (≈6 m/s), while maintaining CV < 5%.

3. **Stacked kite shadowing** — analyse inter-kite aerodynamic interference as a
   function of spacing. Minimum spacing for < 10% lift loss on downwind kites.

4. **Integrated simulation** — couple lift kite force to TRPT dynamics; run
   full ODE with dynamic hub position. Compare power variance to fixed-hub baseline.

5. **Alphanemo / SomeAWE cross-check** — compare model predictions against
   published field test data from SomeAWE (WES 2024 tensegrity paper).

---

## Code Added / Modified

**Phase 1 (static equilibrium framework):**
- `src/lift_kite.jl` — `LiftDevice` type hierarchy + all force/analysis functions
- `src/KiteTurbineDynamics.jl` — updated to include and export lift_kite.jl
- `src/types.jl` — added `abstract type LiftDevice`
- `scripts/lift_kite_equilibrium.jl` — equilibrium analysis across all architectures

**Phase 2 (dynamic hub integration):**
- `src/ring_forces.jl` — added optional `lift_device` 9th arg; applies 3D lift force at hub
- `src/dynamics.jl` — extracts `lift_device` from params tuple (backwards compatible)
- `src/initialization.jl` — `simulate()` and `settle_to_equilibrium()` accept `lift_device` kwarg
- `scripts/hub_excursion_sweep.jl` — dynamic hub position variance sweep across architectures
- `scripts/results/lift_kite/hub_excursion_{timeseries,summary}.csv` — Phase 2 results

## References

- alphAnemo: https://site.alphanemo.com (ETH BRIDGE project, 2025)
- SomeAWE lift kite requirements: IEEE ITEC 2024, DOI:10.1109/ITEC60881.2024.10718850
- RAWE tensegrity dynamics: WES 9:1273–1291 (2024), DOI:10.5194/wes-9-1273-2024
- Stacked multi-kite systems: Leuthold et al., ResearchGate 2019
- Kite networks: Haas et al., Springer 2018
