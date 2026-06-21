# Rotor Sizing: Static vs Dynamic Mismatch

**Date:** 2026-06-18  
**Discovered by:** Dashboard verification of V6.2 campaign winner  
**Status:** Open — requires dynamic equilibrium solve in objective function

## The Problem

`objective_v6` sizes the hub rotor from a **static** BEM power equation:

```
r_hub_rotor = BEM.rotor_radius_for_power(P_per_rotor, v_rated, n_lines)
ω_design   = 4.1 × v_rated / r_hub_rotor
```

This assumes the rotor operates at design TSR=4.1 and converts all wind power
to useful work. The **dynamic** simulation (ODE) settles to a completely
different equilibrium ω because it includes forces the static model ignores:

1. **Expansion rotor τ_net** — can be hundreds of kW for λ≈1.0 blades
2. **Parasitic drag** on structural elements (ring beams, tethers)
3. **Lifter torque** contribution

## Dashboard Evidence (V6.2, 2026-06-18)

| Metric | Static (design intent) | Dynamic (dashboard) | Ratio |
|--------|----------------------|---------------------|-------|
| Power | 50 kW | **390.8 kW** (474.9 kW peak) | 7.8× |
| ω | 4.27 rad/s (41 rpm) | **8.38 rad/s (80 rpm)** | 2.0× |
| Tether FoS | 3.0 (design) | **0.1** | 30× overloaded |
| Ring buckling margin | 33% | **17%** (83% loaded) | — |
| Peak tether tension | ~3,500 N (SWL) | **33,379 N** | 9.5× SWL |

**Configuration:** V6.2 12-line dodecagon, λ=1.0 expansion blades  
(10.6 m span, 1,197 mm chord, 12 blades/rotor, 10 expansion rotors at 45° bank)  
**Conditions:** Steady 11.4 m/s wind, 30° elevation, MPPT gain k_mppt=614.9

## Root Cause

Two interacting problems:

### 1. Static sizing ignores dynamic torque balance

The rotor radius is chosen for P=P_rated at TSR=4.1. The actual dynamic ω
settles where the net shaft torque is zero:

```
τ_hub_aero(ω) + τ_exp_net(ω) − τ_parasitic(ω) − τ_lifter(ω) = 0
```

This equilibrium ω is NOT at TSR=4.1. It can be higher (when expansion rotors
drive the shaft) or lower (when parasitic drag dominates).

### 2. Expansion rotor coefficients are placeholder values

The expansion rotor model (`src/expansion_rotor.jl`) uses:
- CL=1.0, CD0=0.02, k_induced=0.05
- These produce **unrealistically large forces** with full-scale blades

At λ=1.0 (V6.2), the blade annulus is massive:
- Blade span: 10.6 m (tip) − 1.5 m (hub) = 9.1 m
- Blade chord: 1,197 mm
- n_blades: 12 per rotor × 10 rotors = 120 expansion blades

At ω=8.38 rad/s and r_mean≈6 m, the apparent wind is ~50 m/s. Dynamic pressure
at 30° elevation: q ≈ 1,500 Pa. Blade lift: L ≈ 1,500 × 1.2 × 9.1 × 1.0 ≈ 16,400 N
per blade → 120 × 16,400 = 2 MN total lift from expansion blades.

The resulting τ_net from a single expansion rotor exceeds 500 kW at this ω.
Ten rotors collectively inject **megawatts** of shaft power — all from
placeholder coefficients.

## Effect on V6 Campaign Results

The V6.3–V6.5 campaigns converged to tiny blade_scale (λ=0.011 in V6.5)
partly to escape this pathology. Tiny blades produce tiny (realistic) forces.
But λ=0.011 means:

- Blade span: 9.1 × 0.011 = 0.10 m
- Blade chord: 1.2 × 0.011 = 13 mm
- These contribute negligible useful radial spreading
- Hub rotor shrinks to 1.61 m radius with ω=267 rpm
- **Parasitic drag exceeds available power by 640×** (see #parasitic-drag)

The optimizer has been gaming a broken model: shrinking expansion blades to
escape the unrealistically large forces from placeholder coefficients, while
the hub rotor shrinks to minimise structural mass.

## What Needs to Happen

### Immediate (blocking)

- [ ] Calibrate expansion rotor coefficients against real airfoil data or CFD
  - CL should be ~0.6–0.8 for a practical blade section at Re~10⁵
  - CD0 should be ~0.01 for a clean NACA section
  - k_induced should be validated from 3D panel method or lifting line
- [ ] Implement parasitic drag model in objective function (#parasitic-drag)
  - Prevents the "tiny hub rotor + extreme ω" strategy
  - DONE: `src/objective_v6.jl` — `parasitic_drag_power()` function added
- [ ] Replace static rotor sizing with a dynamic equilibrium solve:
  ```
  function find_equilibrium_omega(r_rotor, stack, p, v_wind)
      # Solve τ_hub_aero(ω) + Στ_exp_net(ω) − τ_parasitic(ω) = 0 for ω
      # Return equilibrium ω and power balance
  end
  ```

### Follow-up

- [ ] Re-run V6 campaign with realistic coefficients + parasitic drag
- [ ] Verify dashboard power at equilibrium ω matches rated power
- [ ] Validate that tether FoS ≥ 3.0 and ring buckling ≥ 33% at equilibrium

## Related

- `src/objective_v6.jl` — rotor sizing at lines 240–241
- `src/expansion_rotor.jl` — placeholder coefficients at lines 53–55
- `src/aerodynamics.jl` — `TETHER_DRAG_CD`, `TUBE_DRAG_CD` constants
- `references/expansion-mach-analysis.md` — V6.5 Mach 0.6 blade velocity analysis
- Skill: `ktd-v6-campaign-workflow` — calibration caveat, pitfalls 7, 8
