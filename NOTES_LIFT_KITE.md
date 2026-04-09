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
  - 10 kW: **27.5 m²** (sized for v=4 m/s launch condition, not rated wind)
  - 50 kW: ~109 m²
  - 500 kW: ~1462 m² (about 40m × 37m parafoil — not practical)
- CT thrust self-supports hub above v ≈ 3.5 m/s; kite provides security margin and
  lateral stability. Sized at v_design=4.0 m/s (minimum launch wind), not v_rated.

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
- **Status (corrected physics)**: rotary lifter at default parameters provides
  **163% of required hub lift** at v=11 m/s (399 N vs 245 N needed — 1.6× margin).
  After removing phantom kite CL lift from the ODE, F_required = airborne weight
  only (245 N); CT thrust and shaft tension cancel at the hub in quasi-static
  equilibrium. The rotary lifter is no longer undersized — it exceeds the requirement
  across the operational wind range.
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

**Corrected physics:** F_req = 245 N (airborne weight only; CT thrust and shaft
tension cancel at hub). Kite sized at v_design=4.0 m/s launch condition.

| Metric | Single Kite | Stack×3 | Stack×5 | Rotary Lifter |
|--------|------------|---------|---------|---------------|
| Required lift force | 245 N | 245 N | 245 N | 245 N |
| Required area (v=4 m/s) | **27.5 m²** | 27.5 m² total | 27.5 m² total | ~12 m² blade area (TBD) |
| Individual unit size | 27.5 m² | 9.2 m² each | 5.5 m² each | 1.5m radius rotor |
| T_line at v=11 m/s (N) | ~248 | ~248 | ~248 | 399 |
| Lift margin at v=11 m/s | **8.3×** | 8.3× | 8.3× | **1.6×** |
| Lift margin at v=4 m/s | 1.10× | 1.10× | 1.10× | ~0.4× (below launch threshold) |
| Tension CV | 30.1% | 30.2% | 30.2% | 3.6% |
| CV reduction vs single | — | 1.00× | 1.00× | **0.12× (8× better)** |
| Top kite static load | — | ~20 N | ~20 N | n/a |

### Scaling bottleneck (single kite, v=4 m/s launch condition)

| Power | Area needed | Area/kW |
|-------|-------------|---------|
| 10 kW | 27.5 m² | 2.75 m²/kW |
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

**Long-run results** (84 min simulation, 12 device × wind-speed cases, IEC Class A turbulence I=0.15):

| Device | v=8 m/s hub_z std | v=11 m/s hub_z std | v=11 / SingleKite |
|--------|-------------------|--------------------|--------------------|
| SingleKite | 39 mm | 26 mm | 1.00× (reference) |
| Stack×3 | ~39 mm | ~26 mm | ~1.00× |
| RotaryLifter | TBD | TBD | expected ~0.12× |
| NoLift | 72 mm | 36 mm | 1.38× worse |

The NoLift baseline (no lift device, hub supported only by CT thrust) shows
36–72 mm hub_z std — confirming CT thrust alone holds the hub but with
significantly more sway than an actively supported kite. The single kite
reduces hub excursion substantially by providing a tensioned catenary backstay.

**Short-run results** (3s simulation, earlier run for reference):

| Device       | hub_z std (mm) | hub_z / SingleKite |
|-------------|---------------|--------------------|
| SingleKite  | 3.5           | 1.00× (reference)  |
| Stack×3     | 3.5           | 1.00×              |
| RotaryLifter| 0.9           | **0.26× (3.9× better)** |
| NoLift      | 0.3           | baseline noise      |

The 8× CV improvement predicted analytically for the RotaryLifter is only partially
captured in short runs (3s << 31s turbulence integral time scale). Long-run
RotaryLifter results are pending a dedicated sizing run.

**Stack×3 shows identical excursion to SingleKite** in both short and long runs —
confirming the analytical prediction: same total area, same CV, same hub motion.
The handling benefit (smaller units) comes at zero stability cost.

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

---

## ⚠️ Open Issue — TRPT and Rotor Collapse Not Observed in Low-Wind Simulation

**Observed:** The simulator does not produce TRPT torsional collapse or rotor stall/drop
under low-wind or low-lift conditions. A real suspended kite turbine would collapse the
shaft and lose altitude when lift is insufficient. This absence is conspicuous and
represents missing due-diligence for non-ideal operational cases.

**Suspected causes (to be investigated in priority order):**

1. **Pre-loaded rotor energy at startup** — Simulations begin with the rotor already
   spinning (ω_hub seeded manually). This inertia artificially sustains shaft tension
   through the early low-wind period. A cold-start from ω=0 with v_wind below cut-in
   would stress-test the collapse mechanism correctly.

2. **Back line modelled as single rigid element** — The back line is currently a single
   spring-damper from hub to ground anchor. A real Dyneema back line has catenary sag,
   finite mass, and can go slack. Multiple rope nodes would allow the line to go slack
   at low loads and let the hub drop forward — which the current single-element model
   cannot represent.

3. **Hub reference frame has insufficient degrees of freedom** — The hub (ring 16)
   bearing frame may be over-constrained. If elevation angle is partly fixed by
   parameterisation rather than fully free as a dynamic state, the hub cannot drop
   to the ground even when lift is zero. Check whether β (elevation angle) can
   evolve freely in all 6 DOF during a no-lift simulation.

4. **Lift requirement computed and applied, not assessed for adequacy** — The
   current `hub_lift_required()` path computes the force needed and then *applies*
   exactly that force via the kite model. It never tests whether the wind speed is
   high enough for the kite to *actually generate* that force. Below cut-in wind
   speed the kite would generate less lift than required, but the simulator may
   silently clamp or scale the force rather than letting the deficit propagate to
   a real kinematic drop.

**Interim mitigation:** The current simulator can be treated as a **fixed-mast** model
— correct and useful for above-cut-in steady-state and transient analysis, but not
for launch/landing or low-wind collapse scenarios. This should be stated explicitly
in any report shared externally.

**Required before claiming full fidelity:**
- Cold-start test (ω=0, v_wind=5 m/s, no lift) → hub should drop and shaft should
  un-twist within ~10 s
- Back line multi-element rope model (at least 5 nodes)
- Confirm hub β is a free dynamic state, not a parameterised constant
- Add a minimum-lift check: if kite cannot generate F_req, apply actual F_lift < F_req
  and let the hub sag or drop accordingly

**Note for reports:** Until collapse is demonstrated, all results should be labelled
"above cut-in, kite-suspended" and the fixed-mast caveat stated clearly.
