# KiteTurbineDynamics.jl

> **Current state (July 2026):** V10 Tight design landscape, per-vertex spoke model, 13 viable designs. For full campaign history and design rationale see **[CONTEXT.md](CONTEXT.md)** and **[DECISIONS.md](DECISIONS.md)**.

Full multi-body dynamics simulator for a **TRPT kite turbine** — a Tensile Rotary Power
Transmission airborne wind energy system developed by
[Windswept & Interesting Ltd](https://windswept.energy).

The simulator spans **34 source modules and ~150 scripts** across 5 architectural layers,
supporting multi-configuration dashboards, multi-objective DE optimisation campaigns
(V2→V10), three lift device architectures, expansion rotor networks, and k_mppt control.
Canonical designs cover 10 kW through 50 kW with live switching in the GLMakie dashboard.

---

## 1. What this is

A TRPT kite turbine is an airborne wind energy device. A rotor (a ring of blades) is held
at altitude by aerodynamic lift and tether tension. The wind spins the rotor. That spin
travels *down the tether lines as twist* — the lines wrap helically over polygon rings which hold the lines appart, the helix propagates
toward the ground. The ground end unwinds into a generator shaft. There is no rigid
mechanical shaft between the flown turbine and the ground sited generator, no gearbox, no tower.

The key failure mode is **torsional collapse**: if the shaft is loaded beyond its elastic
twist limit, the helical lines twist together, the rings fall toward each other, and the
transmission fails.

This package models the TRPT as a multi-body ODE system. Torsional coupling between rings
is **emergent** — it arises from attachment-point geometry, not an analytical torque formula.
This enables simulation of rope sag, catenary shape, line slack (and therefore torsional
collapse), per-ring structural safety, hub spin-up, MPPT generator loading, and power
extraction.

---

## 2. Repo structure

```
KiteTurbineDynamics.jl/
├── src/
│   ├── KiteTurbineDynamics.jl    Package entry; all includes + exports
│   ├── builders_util.jl          V10 system builders
│   ├── control_map_hunt.jl       ControlMapHunt bisection module
│   ├── types.jl, parameters.jl   Core types + parameter sets
│   ├── aerodynamics.jl, bem.jl   BEM aerodynamics + solidity model
│   ├── geometry.jl, initialization.jl
│   ├── rope_forces.jl, ring_forces.jl, dynamics.jl   ODE core
│   ├── simulation.jl, sim_frame.jl, sim_runner.jl     Simulation
│   ├── structural_safety.jl, ring_element_analysis.jl  FEA + FoS
│   ├── lift_kite.jl              Lift device hierarchy (kite, stacked, rotary)
│   ├── expansion_rotor.jl, expansion_stack.jl, expansion_analysis.jl
│   ├── ring_spacing.jl, trpt_axial_profiles.jl
│   ├── trpt_optimization.jl      DE evaluator
│   ├── objective_v6.jl, objective_v10.jl
│   ├── soft_ramp_controller.jl   k_mppt auto-ramp state machine
│   ├── visualization.jl, dashboard_panels.jl, dashboard_v2.jl
│   └── spacer_ring_design.jl, catenary.jl, economics.jl
├── scripts/
│   ├── launchers/                Shell scripts for campaigns + dashboards
│   ├── diagnostics/              Verify scripts, campaign test runners
│   ├── wind_sweep.jl, catalog_sweep.jl, crossover_sweep.jl   Sweeps
│   ├── power_curve_quick.jl      Quick power curve generator
│   ├── interactive_dashboard.jl  GLMakie launcher
│   ├── run_v*_campaign.jl        DE campaign runners
│   └── results/                  Simulation CSVs (campaign CSVs tracked)
├── test/
│   ├── runtests.jl               FAST unit suite (35 files, 1926 tests wired)
│   ├── acceptance_runtests.jl    SLOW ODE acceptance suite (6 files, parallel)
├── docs/
│   ├── adr/                      Architecture Decision Records
│   ├── outreach/                 Phase E design landscape charts + figures
│   ├── awes-forum-diagrams/      Forum diagram specs + PNGs
│   ├── porto-2026/               AWEC 2026 Porto materials
│   └── ...
├── handovers/                    Agent handoff documents
├── AGENTS.md / CLAUDE.md         Agent entry points
├── CONTEXT.md                    Domain vocabulary + current development state
├── DECISIONS.md                  Running design decision log
├── CHANGELOG.md                  User-facing version history
├── PROJECT_ROOM.md               Repo inventory
└── Project.toml                  Julia package manifest
```

---

## 3. How to run it

### Prerequisites

- Julia 1.12 or later
- `CoaxialAutogyroStacking.jl` (local dependency — provides PCA-2 autogyro lift model)

### Install

```bash
git clone https://github.com/rodWindswept/KiteTurbineDynamics.jl.git
git clone https://github.com/rodWindswept/CoaxialAutogyroStacking.jl.git
cd KiteTurbineDynamics.jl
julia --project=. -e 'using Pkg; Pkg.develop(path="../CoaxialAutogyroStacking.jl"); Pkg.instantiate()'
```

### Run the tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

All fast unit tests pass (1926/1926, ~1 min); the slow ODE acceptance suite runs via test/acceptance_runtests.jl (~18 min, parallel) and is re-baselined on each campaign's winners.

### GLMakie interactive dashboard

```bash
julia --project=. scripts/interactive_dashboard.jl
```

Features: config switching, pitch depower, lift device telemetry, safety state machine,
structural HUD, economics module.

### Pluto.jl notebooks

```bash
# Daisy 1kW calibration & validation (vs Tulloch, Bergey Excel 10)
julia --project=. -e 'using Pluto; Pluto.run(notebook="notebooks/daisy_calibration.jl")'

# Parametric design explorer (interactive 3D parameter tweaking)
julia --project=. -e 'using Pluto; Pluto.run(notebook="notebooks/design_explorer.jl")'
```

### Minimal simulation

```julia
using KiteTurbineDynamics

p         = params_10kw()
sys, u0   = build_kite_turbine_system(p)
u_settled = settle_to_equilibrium(sys, u0, p)

wind_fn = (pos, t) -> begin
    z = max(pos[3], 1.0)
    [p.v_wind_ref * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
end

u_start = copy(u_settled)
u_start[6*sys.n_total + sys.n_ring + sys.n_ring] = 1.0   # hub ω = 1 rad/s
u_final = simulate(sys, u_start, p, wind_fn; n_steps=1_500_000, dt=4e-5)
```

---

## 4. Physics and assumptions

The TRPT shaft is modelled as 241 point masses: 16 ring nodes + 225 rope nodes. All 241
nodes obey Newton's second law. State vector: 1478 components (3D pos + vel for each node,
plus twist angle + rate for each ring).

Torsional coupling is emergent — no analytical torque formula. The `max(0, T)` tensile-only
clamp on each sub-segment spring is the entire torsional collapse model.

Rotor aerodynamics use BEM-derived Cp and CT tables. Generator: MPPT load `τ = k·ω²`.

**Simplifications:** fixed ring radius (no radial deformation), lift device is steady-state
(no kite flight dynamics), back line is single spring-damper, no blade pitch control,
static envelope only (no fatigue). See [DECISIONS.md](DECISIONS.md) for full details.

---

## 5. Key findings

See [CONTEXT.md](CONTEXT.md) for the full V2→V10 campaign table and current development
state, and [DECISIONS.md](DECISIONS.md) for design rationale. Highlights:

- **Torsional collapse** dominates structural sizing. Euler-only v2 designs (2.81 kg) were
  torsionally infeasible by 10–60×. v3 added the gate; v4 recovered taper via constant-L/r
  ring spacing. Mass settled at ~11.5 kg (10 kW) and ~74 kg (50 kW corrected physics).
- **n_lines = 8** was unanimously selected by 120 DE islands (v4+v5). V6.2 corrected
  physics pushed the optimum to n=12 (dodecagon). BEM strip theory is not validated
  above n=6 — CFD/panel-method validation needed.
- **Expansion rotors** (v6+) share power across multiple rotors on the TRPT stack.
  V10 unified rotors with 8 structural gates: 76.75 kg at 50 kW.
- **Left-flank architecture:** design for overspeed (low-torque, high-ω regime).
  The right flank is dynamically unreachable due to torque and taper constraints.
- **Per-vertex spoke springs** (July 2026) replaced the centre-constraint model.
  The corrected physics revealed 13 viable V10 Tight designs — see
  `docs/outreach/figures/design-cards.pdf`.
- **k_mppt soft-ramp controller** with FoS taper, collapse margin guards, and
  dP/dk sign detection for perturb-and-observe hill detection.

---

## 6. Known limitations

- **n_lines validation:** BEM strip theory not validated above n=6. V10 uses n up to 14.
- **No fatigue model:** structural sizing is against static peak envelope only.
- **Back line is single spring-damper:** cannot capture catenary sag or forward hub drift.
- **No blade pitch control:** rotor runs at fixed blade angle.
- **Solid-body collision not implemented:** no contact physics under severe droop.
- **Static envelope only:** no dynamic amplification, resonance, or impact loads.

---

## 7. Key choices

**Julia.** 1478-state stiff ODE at 4×10⁻⁵ s timestep. Julia's type system and
DifferentialEquations.jl handle the stiffness efficiently.

**Differential Evolution.** Discrete-continuous TRPT sizing is multi-modal with
manufacturability discontinuities. DE handles discrete variables by rounding and
naturally explores multiple optima through its population.

**FoS 1.8.** Intermediate value between offshore wind practice (IEC 61400-3: 1.35–2.5)
and a prototype AWE system with limited field data. Subject to revision.

**Decoupled simulation and reporting.** Julia writes CSVs; Python reads them for reports.
Allows overnight runs to be analysed and re-reported without re-running the simulator.

---

## Licence

MIT © 2025–2026 Rod Read / Windswept & Interesting Ltd
