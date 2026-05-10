# CONTEXT.md — KiteTurbineDynamics.jl

## What this is

A full multi-body dynamics simulator for a **TRPT kite turbine** — a Rotary Multi-Kite Airborne Wind Energy System capable of scaling via blade number, rotor layer stacking, rotor expansion, and network deployment methods, developed by Windswept & Interesting Ltd. The primarily tensile architecture is the key enabler of scaling: blades, shaft, and tether carry loads in tension. The exception is the polygon spacer rings, which resist inward compressive loads arising from the torsion in the helical lines — Euler column buckling of the ring beam segments is therefore a critical structural constraint. Dynamic rotor expansion via centripetal force during rotation (as investigated by AlphaAnemo and SomeAWE) is a further scaling pathway enabled by this tensile design. The primary design targets are a **10 kW prototype** (originally a pentagon, 5-line TRPT) and a **50 kW commercial system** (octagon, 8-line TRPT, v5 geometry).

The simulator is the engineering source-of-truth for sizing, MPPT tuning, structural safety, and lift device trade-offs. It feeds directly into design reports, conference papers, and partner conversations.

---

## Core physical concept: Kite Turbine

**Kite Turbine.** A system for harvesting wind energy using a mostly tensile, lightweight, fast-deployable structure at low material cost. The system comprises: a **lift kite** providing elevation support via a **lift line** and **lift bearing**; a **back anchor line** limiting altitude and elevation angle; a **kite turbine rotor** (spinning ring of autogyro kite blades) generating torque from the wind; a **TRPT** (Tensile Rotary Power Transmission) shaft transmitting that torque to the ground as twist propagating down the helical tether lines; and a **ground station generator** extracting power at the ground end. There is no rigid shaft, gearbox, or tower. The tensile architecture keeps weight and material cost low and enables rapid deployment and scaling.

Key consequences:
- The system is **aerially suspended**: rotor lift + a separate lift device + tether tension must balance airborne weight and aerodynamic drag.
- Torsional coupling between rings is **emergent** from attachment-point geometry, not an analytical formula.
- The critical failure mode is **torsional collapse**: when applied torque exceeds the geometric torsional capacity (Tulloch/Wacker criterion), the helical lines overtwist past their kinematic stability limit. The lines remain taut but the rotational resistance between adjacent rings collapses — the geometry loses its mechanical advantage to oppose further twist. The lines cross and wind toward the axis between adjacent rings, the rings converge, and torque and power transmission fail. Must be avoided at all costs: once collapse begins, there are only seconds to remove the rotor from the sky before the winding destroys the TRPT.

---

## Domain vocabulary

| Term | Meaning |
|------|---------|
| **TRPT** | Tensile Rotary Power Transmission — the tether-shaft architecture comprised of polygonal Spacer Rings linked by (polygon n) tether lines|
| **Ring / polygon ring** | Spacer frame between tether lines set at defined attachment points. A polygonal hoop made of rigid carbon tube beams joined at knuckle nodes. Configurations include pentagon (n=5) or octagon (n=8) |
| **Top rotor ring hub** | The topmost polygon ring, at the rotor end of the TRPT. Unlike a conventional turbine hub there is no central bearing — the hub is a tensile polygon ring with the rotor blades attach at the perimeter. The blades mount to the periphery of the top rotor ring hub and sweep an annulus (no root join, open centre). The Top Rotor ring hub functions as a spinning ring autogyro kite. This device is flown at altitude as the top ring of the TRPT stack and is the turbine device which gathers rotary power from wind energy and transmits it via tethers to the next lower TRPT ring in the shaft stack. |
| **Lift kite device** | A separate kite device that provides lifting line tension to keep the kite turbine at elevation (types: passive kite, stacked kites, or rotary lifter). The lifting kite line holds a lift bearing which connects to the top lift lines of the kite turbine rotor. A ground anchor line attaches to the lifting line approximately 30 cm above the lift bearing (the lift bearing being at the lowest point of the lifting line), limiting the altitude and elevation angle of the kite turbine |
| **TSR (λ)** | Tip-Speed Ratio: blade-tip speed ÷ wind speed at hub altitude |
| **MTR** | Moment-to-Tension Ratio: `MTR = moment / (looping_radius × shaft_tension)`. Typical value ≈ 0.05 |
| **Cp** | Rotor power coefficient. BEM (AeroDyn, NACA4412, 3-blade) gives Cp ≈ 0.22 at TSR ≈ 4.1 |
| **Ct** | Rotor thrust coefficient. BEM gives Ct ≈ 0.55 at rated, 1.0 at peak design load |
| **MPPT** | Maximum Power Point Tracking. Generator load law: `τ_gen = k_mppt × ω²` |
| **k_mppt** | MPPT gain constant (N·m·s²/rad²). Derived from rated torque and rated speed: `k = τ_rated / ω_rated²` |
| **FoS — Euler buckling** | Factor of Safety against Euler column buckling of each polygon ring beam: `FoS = P_crit / N_comp`. Hard constraint ≥ 1.8 in the optimiser; design-point target = 3.0 in post-processing |
| **FoS — torsional collapse** | Factor of Safety against torsional collapse (Tulloch/Wacker criterion): `FoS = τ_cap / τ_op`. Hard constraint ≥ 1.5 |
| **FoS — tether** | Factor of Safety on tether line tension: `FoS = TETHER_SWL / T_peak`. Shown live in the dashboard |
| **DLF** | Design Load Factor: `DLF = F_inward_per_vertex / T_line_axial_peak`. Captures net inward radial force from taper non-uniformity, torque-reaction helix projection, and gust asymmetry (under ideal uniform taper + zero twist the radial force is zero). Calibrated to 1.2 from the multi-body ODE across six load scenarios (`scripts/calibrate_dlf.jl`). The polygon geometry resolves F_inward into per-beam compression separately via `N_comp = (F_inward / n) / (2·tan(π/n))` |
| **rL ratio (r/L)** | Geometry ratio: ring radius ÷ segment length. Constant-r/L gives the v4/v5 tapered geometry |
| **Torsional collapse** | The critical failure mode: when applied torque exceeds the geometric torsional capacity (Tulloch/Wacker criterion), the helical lines overtwist past their kinematic stability limit. The lines remain taut but the rotational resistance between adjacent rings collapses — the geometry loses its mechanical advantage to oppose further twist. The lines cross and wind toward the axis between adjacent rings, the rings converge, and torque and power transmission fail. This is a geometric stability limit, not a material failure. Must be avoided at all costs: once collapse begins there are only seconds to remove the rotor from the sky before the winding destroys the TRPT — line snapping is the likely outcome (7 lines snapped in field testing; the back-anchor line prevented complete loss of the system) |
| **BEM** | Blade Element Momentum theory — used to compute Cp(n_lines, geometry) |

---

## System architecture

### Multi-body model

The simulator models a TRPT kite turbine as a multi-body system of ring nodes, rope nodes, and sub-segments. The current canonical configurations are a 10 kW pentagon (241 nodes, 1478-state ODE) and a 50 kW octagon (476 nodes, ~2920-state ODE), but the intent is for the system to become fully parametric — node count, ring number, line count, and geometry should all flow from `SystemParams` rather than being hard-coded configurations.

The ODE state vector is: 6 DOF (position + velocity) per node, plus twist angle and angular velocity per ring. Each TRPT line is subdivided into spring-damper sub-segments with intermediate rope nodes. Torsional coupling between rings is emergent from the rope attachment geometry — there is no analytical torque formula. Torsional collapse itself is emergent: the tensile-only spring law `T = max(0, EA·strain + c·damp·rate)` means lines go slack naturally under overtwist; nothing needs to be explicitly detected. The ODE is integrated via `DifferentialEquations.jl` (adaptive step).

### What it models well (current state)

- Full multi-body ODE dynamics: torsional coupling, rope sag, line slack, and torsional collapse — all emergent from geometry and the tensile-only spring law.
- MPPT gain sweep, TRPT structural sizing (v2–v5 Differential Evolution campaigns), and lift device comparison (passive kite, stacked kites, rotary lifter).
- GLMakie 3D dashboard: canonical 5-line pentagon and v5 8-line octagon, config switching, furl controller, lift HUD, and economics (LCOE, carbon payback).
- Torsional collapse FoS (Tulloch/Wacker) and Euler column buckling FoS enforced as hard constraints in the optimiser from v3 onwards.

### Known limitations and simplifications

- **Not yet fully parametric**: node count, ring count, and line count are derived from the two fixed configurations (canonical / v5). Intent is for these to flow entirely from `SystemParams`.
- **Elevation angle β fixed at 30°**: not a design variable in v2–v5 campaigns. Cold-start and lift-kite analysis suggest optimum near β ≈ 26°. v6 should free β.
- **Strip theory not validated above n = 6 lines**: BEM Cp values at n = 8 are provisional. CFD or panel-method validation required before adopting n = 8 for hardware.
- **Static sizing only**: all campaigns size against a peak static load envelope at 25 m/s. Cyclic 1P/2P tether tension, S-N fatigue, and dynamic torsional loading are not modelled.
- **Ring radial deformation not modelled**: ring nodes are point masses. A buckled ring deforms inward; the model keeps it circular and reports the FoS margin only.
- **Lift device has no trajectory dynamics**: kite applies a steady-state force each ODE step via `lift_force_steady()`. No kite flight path, line catenary, or gust response model.
- **Back anchor line is a single spring-damper**: a real Dyneema line can sag and go slack. Multi-segment back-line modelling is on the backlog.
- **No blade pitch**: angle of attack is fixed. Bridling as a control input is discussed in `NOTES_MPPT_TWIST.md` but not implemented.
- **Furl controller incomplete**: furl depowers the rotor by raising it (via back-anchor winch) to pitch the rotor away from the incoming wind, reducing wind incidence. The current implementation does not show the change in rotor altitude during furl — the altitude change and its effect on wind incidence angle are not visualised.
- **Lift HUD incomplete**: currently shows lift force numbers but lacks a visual lift kite representation and tension scale.
- **Economics module not integrated into dashboard**: LCOE and carbon payback are computed in `src/economics.jl` but have no display interface in the GLMakie dashboard. The module runs separately. Better accessibility from simulation data and integration into presentation formats (reports, dashboard, export) is a priority as the project advances.
- **Known v5 campaign bug**: `run_v5_campaign.jl` hardcodes 50 kW loads for all islands — 10 kW designs were sized against 50 kW loads. Fixed in `run_v5_safe_campaign.jl`.

### Intended development

- Full parameterisation: all geometry flows from `SystemParams`, no hard-coded configurations.
- v6 campaign: free β, CFD Cp validation at n = 8, dynamic torsional loading and fatigue.
- Stacked rotor, network deployment, and centripetal rotor expansion modelling.
- Multi-segment back-anchor line and active furl/shutdown sequence.
- Economics module integrated into dashboard and export pipelines.

### Key source files

| File | Role |
|------|------|
| `src/types.jl` | `RingNode`, `RopeNode`, `RopeSubSegment`, `KiteTurbineSystem` structs |
| `src/parameters.jl` | `SystemParams`, `params_10kw()`, `params_50kw()` |
| `src/dynamics.jl` | `multibody_ode!` — the unified 1478-state ODE |
| `src/initialization.jl` | Node-list builder, static pre-solve, `simulate()` entry point |
| `src/rope_forces.jl` | Sub-segment spring/damper/drag; emergent torsion from geometry |
| `src/ring_forces.jl` | Rotor aero, generator torque (MPPT law), lift device integration |
| `src/aerodynamics.jl` | `cp_at_tsr()`, `ct_at_tsr()` — BEM lookup tables |
| `src/lift_kite.jl` | `SingleKiteParams`, `StackedKitesParams`, `RotaryLifterParams` + force models |
| `src/structural_safety.jl` | Post-process Euler buckling FoS per ring |
| `src/trpt_optimization.jl` | `TRPTDesign`, `evaluate_design()`, Differential Evolution fitness |
| `src/ring_spacing.jl` | v4/v5 geometric ring spacing (constant L/r) |
| `src/bem.jl` | BEM Cp(n_lines) model for v5 aero coupling |
| `src/economics.jl` | LCOE, carbon intensity, competitor comparison |
| `src/visualization.jl` | GLMakie 3D dashboard — config switching, furl animation, lift HUD |

### Configurations

| Config | Lines | Rings | Nodes | ODE states | Notes |
|--------|-------|-------|-------|------------|-------|
| 10 kW pentagon (canonical) | 5 | 14 | 241 | 1478 | Original prototype geometry |
| 50 kW octagon (v5) | 8 | 18 | 476 | ~2920 | Constant-L/r spacing from 168-hour DE campaign |

---

## Key design decisions and constraints

- **Rotor Cp ≈ 0.22** (not 0.15): AeroDyn BEM with NACA4412, 3-blade, 20–30° elevation. The old Framework PDF value of 0.15 was a conservative proxy.
- **Emergent torsion**: torsional coupling is computed from rope attachment geometry — do not replace with an analytical torque formula; it would miss collapse dynamics.
- **Constant-L/r geometry (v4/v5)**: ring spacing follows `L_i = r_i / rL_ratio`. This distributes structural load more evenly than uniform spacing.
- **Knuckle mass = 50 g** per polygon vertex (approved 2026-04-20). Discrete point masses, not distributed.
- **DLF calibrated from ODE** (`scripts/calibrate_dlf.jl`) against six structural load scenarios — not analytically derived.
- **Elevation controller not implemented**: fixed-pitch, fixed-bank blades; no cyclic control. `β_min/max` fields in `SystemParams` are reserved placeholders.

---

## Lift device trade-offs

Three architectures are modelled in `src/lift_kite.jl`:

| Device | Lift law | Wind sensitivity | Notes |
|--------|----------|-----------------|-------|
| Single passive kite | F ∝ v² | High | Simple; unsafe above ~10 kW |
| Stacked kites (N cascade) | F ∝ v² | High | Easier handling per unit; same instability |
| Rotary lifter | F ∝ v_app² = v² + (ωr)² | Low (ωr >> v) | Near-constant lift; path to safe 50 kW scaling |

The static governing load case for stacked kites is the **topmost kite** supporting the full weight of the cascade below it — opposite to a compression stack.

**Operational constraints:** A single lift kite sized to work at 4 m/s generates dangerously high forces at high wind speeds and becomes impossible for a human operator to control and recover safely. Stacked kites require multiple attachment points and are harder to deploy than a single kite, but their number can be adjusted to match an expected wind range. The rotary lifter avoids both problems — its near-constant lift force across wind speeds makes it the target architecture for safe scaling beyond 10 kW.

---

## Numerical / toolchain notes

- Julia 1.12.5
- ODE integration: `DifferentialEquations.jl` (default solver, adaptive step)
- Optimisation: Differential Evolution (BlackBoxOptim.jl or custom), 60-island parallel campaign
- Visualisation: `GLMakie.jl` — 3D dashboard launched from `scripts/interactive_dashboard.jl`
- Structural analysis: analytic (Euler buckling + thin-wall second moment of area) — each evaluation <<1 ms
- All SI units throughout: m, kg, Pa, rad, rad/s, N·m
