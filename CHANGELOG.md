# Changelog — KiteTurbineDynamics.jl

All notable changes to this project will be documented in this file.
Dates are YYYY-MM-DD. Versions track major campaign generations.

---

## [0.10.0] — 2026-07-03

### Added
- Unified rotor V10 DE campaign (14 DoF, 76.75 kg at 50 kW)
- Dashboard v2 cockpit refactor: 6-row responsive grid, bar charts, rotor dials, tooltips
- Real per-segment transmitted torque (Tulloch law) in torque chain panel
- Per-rotor hub power fix (was cumulative, now per-rotor contribution)
- K1 knowledge pipeline: 585 papers ingested, 7K nodes, AWEC 2026 Porto materials

### Changed
- Project room cleanup: CONTEXT.md rewritten for current state, PROJECT_ROOM.md updated
- Version bumped 0.1.0 → 0.10.0

---

## [0.9.0] — 2026-06-30

### Added
- Dynamic k_mppt bisection hunt with pre-sweep (scripts/hunt_kmppt_bisect.jl)
- Control-map verification across 6 wind speeds (5–15 m/s)
- Per-ring FoS timeseries capture (1 Hz FEA)
- Left-flank architectural decision: design for overspeed, size blades for P_min ≤ P_rated
- Soft-kite rotors rejected (Ct/Cp = 8.3 vs 2.5 for NACA 4412)
- Two-flank control problem analysis (left vs right flank, dynamic unreachability)
- collapse_margin as monotonic safety indicator
- dP/dk sign detection in RampController (accumulated threshold method)
- Warm-start controller (skip IDLE if settled at ω_operational)
- Dashboard v2 layout + cockpit KPIs

### Fixed
- Equilibrium ω scan now includes expansion rotor power
- Controller init ordering: AFTER settle, not before
- k_mppt slider range extended for V10 (10:1:600)
- Brake auto-engagement removed (was triggering at V10 Tight's 6.4 rpm settle)
- Kite position lag updated during operational settle

---

## [0.8.0] — 2026-06-28

### Added
- V10 Tight campaign (49.2 kg at 50 kW — later found dynamically dead)
- V10 Conservative campaign (k_mppt_safety=3.0)
- V9 dynamic equilibrium campaign (44.52 kg, 59/60 feasible)
- V8 per-component physics campaign (58.41 kg, 57/60 feasible)
- Headless trace recording (6 scenarios, open-loop vs soft-ramp)
- k_mppt hunt sweep script (12-point grid)
- 7-figure publication charting suite (scripts/plot_ramp_traces.py)
- Control-first design plan (docs/plans/2026-06-28-control-first-design.md)

### Fixed
- Static-vs-dynamic k_mppt mismatch identified (3.3× under-prediction)
- Structural redesign workflow from per-ring FoS data
- Ring taper direction documented as structurally backwards

---

## [0.7.0] — 2026-06-25

### Added
- V6.7 relaxed drag campaign (54.91 kg, 53/60 feasible)
- V6.6 parasitic drag campaign (no feasible designs — constraint too tight)
- Expansion rotor parasitic drag model (parasitic_drag_power())
- Bank angle safety tightened: 45° → 35° → 25° (geometric derivation)
- Dashboard k_mppt slider animates during Auto-Ramp
- Builder utility module (scripts/builders_util.jl, no GLMakie dependency)

---

## [0.6.0] — 2026-06-20

### Added
- V6.5 further-widened campaign (17.74 kg ⚠ dynamically impossible)
- V6.4 widened campaign (24.40 kg ⚠ dynamically impossible)
- V6.3 blade scaling campaign (52.61 kg ⚠ dynamically impossible)
- 12-DoF design space (density_profile added)
- Variable-density ring spacing (β ∈ [-0.8, 0.8])
- Expansion rotor blade geometry refactor: same annulus as generating rotor
- Dashboard: expansion rotor rendering (cyan diamonds, HUD section)

### Fixed
- Network power sharing: hub+expansion rotors sized for P/N each
- Distributed loading: cumulative per-ring tension replaces uniform T_peak/n

---

## [0.5.0] — 2026-06-17

### Added
- V6.2 corrected campaign (74.17 kg, n=12 dodecagon, n_exp=1)
- Three physics corrections applied together (commit 3fcc795):
  - tan→sin polygon force resolution
  - cos³→cos²·⁶⁵ elevation exponent
  - Coupled knuckle mass model (knuckle_mass_at_ring())
- TRPT_V4_DIM=9, TRPT_V6_DIM=11

### Fixed
- N_comp was 50% under-estimated for n=3 (triangle rings appeared artificially favorable)
- Pre-V6.2 results superseded — the 58.19 kg and 13.6 kg results used erroneous physics

---

## [0.4.0] — 2026-06-15

### Added
- V6 campaign with multi-start DE (collapse-reseed, 60 islands)
- Network rotor model: distributed per-ring thrust + torque
- Tension stiffening: ring polygon hoop tension credited against Euler buckling
- V6.2 widened bounds: n_lines [3,12], 6 of 12 search bounds relaxed
- 4-angle post-campaign analysis pipeline (Pareto, constraints, variations, sensitivity)
- LHS cartography for feasibility mapping
- 3D design overlay comparison tool

### Fixed
- DE population collapse detection + aggressive reseed (was converging in 11s)
- +1e6 absolute penalty barrier (feasible designs beat infeasible)
- 50 kW bounds widened (BEM rotor 7.4–9.3m, old bounds only allowed 4.3m)
- Ring spacing returns 3-tuple (zs, radii, Int) — third element NOT segment lengths

---

## [0.3.0] — 2026-06-13

### Added
- Expansion rotor force model (force-first: F_radial injected as load relief)
- Expansion rotor torque model: τ_lift + τ_drag → τ_net
- `ExpansionRotorParams`, `ExpansionStackConfig` structs
- `estimate_effective_radii()` returns 4-tuple

### Fixed
- sin(Inf) crash from drag torque acceleration (ring twist destabilisation)
- Settle ω=0 with expansion rotors (was reading wind at equilibrium hub position)
- Dashboard: FEA solver crash on ground-adjacent rings (try-catch, zero utilisation)
- Dashboard: 3D scene empty — effective_radii update removed from ODE

---

## [0.2.0] — 2026-05

### Added
- GLMakie 3D interactive dashboard: config switching, furl controller, lift HUD
- Rotor BEM aerodynamics (AeroDyn, NACA 4412, Cp/TsR tables)
- Lift device comparison: passive kite, stacked kites, rotary lifter
- Torsional collapse FoS (Tulloch/Wacker criterion)
- Euler column buckling FoS per ring
- DLF calibration from 6-load-scenario ODE
- Constant-L/r ring spacing (v4/v5 geometry)
- Economics module: LCOE, carbon intensity, competitor comparison
- Differential Evolution optimiser (60-island parallel)

### Changed
- v5 50 kW campaign: 259 kg octagon (8-line TRPT)
- 10 kW pentagon: 23.9 kg (5-line TRPT)

---

## [0.1.0] — 2026-04

### Added
- Multi-body ODE dynamics engine (1478-state for 10 kW pentagon)
- TRPT structural sizing: ring polygon beam compression, Euler buckling
- MPPT generator law: τ_gen = k_mppt · ω²
- Emergent torsional coupling from rope attachment geometry
- Tensile-only spring law (lines go slack naturally under overtwist)
- Initial project room: CONTEXT.md, DECISIONS.md, PLAN.md, AGENTS.md, CLAUDE.md
