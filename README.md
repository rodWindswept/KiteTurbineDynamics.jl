# KiteTurbineDynamics.jl

Full multi-body dynamics simulator for a **TRPT kite turbine** — a Tensile Rotary Power
Transmission airborne wind energy system developed by
[Windswept & Interesting Ltd](https://windswept.energy).

---

## 1. What this is

A TRPT kite turbine is an airborne wind energy device. A rotor (a ring of blades, like a
propeller turned into a hoop) is held at altitude by a combination of aerodynamic lift from
the rotor itself, a separate lift kite, and the mechanical tension in the tether lines that
run from the rotor down to a ground generator. The wind spins the rotor. That spin travels
*down the tether lines as twist* — the lines wrap helically, the helix propagates toward the
ground, and the ground end unwinds into a generator shaft. There is no mechanical shaft, no
gearbox, no tower. The structural spine is a tensile column of rings connected by the helical
tether lines. That spine is the TRPT: Tensile Rotary Power Transmission.

The key failure mode is **torsional collapse**: if the shaft is loaded beyond its elastic
twist limit, the helical lines go slack, the rings fall toward each other, and the
transmission fails. Understanding and constraining that failure is a central engineering
challenge.

This package models the TRPT shaft and rotor as a multi-body system. The 30-metre tether
between rotor and ground is modelled as 5 separate lines, each subdivided into 4 spring-damper
segments with 3 intermediate mass nodes. Torsional coupling between rings is **emergent** —
it arises from the attachment-point geometry of those lines, not from an analytical torque
formula. This enables simulation of rope sag, catenary shape, line slack (and therefore
torsional collapse), per-ring structural safety, hub spin-up, MPPT generator loading, and
power extraction.

The simulator has been used to:
- Characterise MPPT tuning (k_mppt sweep vs wind speed)
- Compare lift device architectures (passive kite, stacked kites, rotary lifter)
- Size the TRPT ring frames structurally using global optimisation (60-island Differential
  Evolution campaign, 11.5 billion evaluations)
- Generate design reports with Python-driven Word document pipelines

All of this is open work. Decisions, assumptions, and failures are documented here and in
`DECISIONS.md`.

---

## 2. Repo structure

```
KiteTurbineDynamics.jl/
├── src/
│   ├── KiteTurbineDynamics.jl    Package entry point; all exports
│   ├── types.jl                  RingNode, RopeNode, KiteTurbineSystem structs
│   ├── parameters.jl             SystemParams, params_10kw(), params_50kw()
│   ├── aerodynamics.jl           cp_at_tsr(), ct_at_tsr() — BEM lookup tables
│   ├── wind_profile.jl           Wind shear + IEC Class A turbulence model (AR-1)
│   ├── geometry.jl               Attachment points, helix basis, shaft_dir
│   ├── initialization.jl         Build node list, static pre-solve, simulate()
│   ├── rope_forces.jl            Sub-segment spring/damper/drag; shaft_dir from hub pos
│   ├── ring_forces.jl            Rotor aero, generator torque, lift device integration
│   ├── dynamics.jl               multibody_ode! — unified 1478-state ODE
│   ├── simulation.jl             High-level simulation runner helpers
│   ├── structural_safety.jl      Post-process Euler buckling FoS per ring
│   ├── lift_kite.jl              LiftDevice type hierarchy + force models
│   ├── trpt_axial_profiles.jl    Axial profile families for sizing optimisation
│   ├── trpt_optimization.jl      TRPTDesign struct, evaluate_design(), DE fitness
│   └── visualization.jl          GLMakie 3D dashboard
├── scripts/
│   ├── interactive_dashboard.jl  Launch the GLMakie 3D viewer
│   ├── mppt_twist_sweep_v2.jl    28-case MPPT gain × wind speed parametric sweep
│   ├── mppt_ramp_only.jl         7→14 m/s wind ramp to expose inertial spin-up delay
│   ├── hub_excursion_sweep.jl    Hub position variance vs lift device architecture
│   ├── lift_kite_equilibrium.jl  Static lift analysis across three device architectures
│   ├── cold_start_collapse.jl    Hub droop / collapse from zero-spin cold start
│   ├── run_trpt_optimization.jl  Phase B1 DE sizing (7-DoF, circular/elliptical/airfoil)
│   ├── run_trpt_optimization_v2.jl Phase C DE sizing (12-DoF, 60 islands)
│   ├── run_lhs_cartography.jl    Phase D Latin Hypercube Sampling — design space survey
│   ├── launch_trpt_optimization.sh  Batch-launch all 6 (config × profile) Phase B runs
│   ├── launch_autonomous_campaign.sh  60-island Phase C launch, 12 parallel
│   ├── auto_refresh_monitor.sh   Regenerate cartography report every 15 min
│   ├── calibrate_dlf.jl          Calibrate Design Load Factor from ODE load cases
│   ├── verify_top_candidates_envelope.jl  Phase E FoS envelope check on winners
│   ├── render_winners_clean.jl   Phase G GLMakie winner renders
│   ├── power_curve_sweep.jl      Power curve P(v) at rated conditions
│   ├── make_diagrams.py          Python matplotlib system diagrams
│   ├── plot_mppt_sweep.py        MPPT sweep analysis charts
│   ├── plot_mppt_individual.py   Per-case MPPT time-series charts
│   ├── plot_hub_excursion.py     Hub excursion statistics charts
│   ├── plot_cartography_heatmaps.py  Phase D 2-D / 3-D heatmaps
│   ├── plot_dlf_calibration.py   DLF calibration per load case
│   ├── plot_phase_f_sensitivity.py  n_lines × knuckle mass sensitivity
│   ├── plot_polygon_pair_graphic.py  Polygon family illustration
│   ├── produce_report.py         TRPT_Dynamics_Report.docx generator
│   ├── produce_free_beta_report.py   TRPT_FreeBeta_Report.docx generator
│   ├── produce_kite_turbine_potential_report.py  TRPT_KiteTurbine_Potential.docx
│   ├── produce_trpt_optimization_report.py  TRPT_Sizing_Optimization_Report.docx
│   ├── produce_cartography_report.py  TRPT_Design_Cartography_Report.docx
│   ├── torque_diag.jl            Torque budget diagnostic
│   ├── torsion_check.jl          Manual torsional angle check
│   └── results/                  All simulation output CSVs (not in git LFS — large)
│       ├── canonical_output_v12.0.csv   Reference steady-state trace
│       ├── mppt_twist_sweep/            k_mppt × v_wind sweep data
│       ├── trpt_opt/                    Phase B best designs (circular/elliptical/airfoil)
│       ├── trpt_opt_v2/                 Phase C–H 60-island campaign archive
│       │   ├── cartography/             Phase D LHS heatmap data
│       │   ├── lhs/                     LHS sample CSVs
│       │   ├── campaign_status.md       Live campaign snapshot
│       │   └── winner_*.png             Phase G winner renders
│       ├── lift_kite/                   Hub excursion time-series CSVs
│       ├── power_curve/                 P(v) data
│       └── collapse/                    Cold-start droop validation data
├── test/
│   ├── runtests.jl               Test suite entry; runs all 11 suites
│   ├── test_types.jl             Node count, state size, ring_idx mapping
│   ├── test_parameters.jl        Parameter struct completeness
│   ├── test_aerodynamics.jl      Cp/CT table bounds, TSR lookup correctness
│   ├── test_geometry.jl          Attachment points, perp basis, helix
│   ├── test_rope_forces.jl       Spring tension, tensile-only clamp, damping
│   ├── test_ring_forces.jl       Rotor thrust, generator torque direction
│   ├── test_dynamics.jl          ODE smoke test — does not crash, states finite
│   ├── test_static_equilibrium.jl  Zero-wind: rings sag, rope nodes droop correctly
│   ├── test_rope_sag.jl          Low-tension: rope nodes sag toward ground
│   ├── test_emergent_torsion.jl  Applied twist → correct torque direction
│   ├── test_power.jl             Rated wind → expected power output
│   └── test_trpt_axial_profiles.jl  Axial profile geometry consistency
├── docs/
│   └── plans/
│       ├── 2026-03-16-kite-turbine-dynamics-design.md      Original architecture spec
│       ├── 2026-03-16-kite-turbine-dynamics-implementation.md  Build task list
│       └── 2026-04-01-session-notes-pending-work.md        Work log + pending items
├── figures/                      matplotlib system diagrams for reports
├── NOTES_MPPT_TWIST.md           MPPT × twist analysis research notes
├── NOTES_LIFT_KITE.md            Lift device architecture analysis + hub droop findings
├── DECISIONS.md                  Running log of architectural and physical decisions
├── RESTART_INSTRUCTIONS.md       Per-session instructions for resuming overnight runs
├── Project.toml                  Julia package manifest
├── run_all_sims.sh               Launch all overnight simulations sequentially
└── TRPT_*.docx                   Design reports (generated, checked in for sharing)
```

---

## 3. How to run it

### Prerequisites

- Julia 1.12 or later
- Python 3.10+ with `python-docx`, `matplotlib`, `pandas`, `scipy` (for report generation)

### Install

Clone the repo and activate the environment:

```bash
git clone https://github.com/rodWindswept/KiteTurbineDynamics.jl.git
cd KiteTurbineDynamics.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Or add from another Julia project:

```julia
pkg> add https://github.com/rodWindswept/KiteTurbineDynamics.jl
```

### Run the tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

All 11 test suites should pass.

### Run a simulation

```julia
using KiteTurbineDynamics

p         = params_10kw()                        # 10 kW parameter set
sys, u0   = build_kite_turbine_system(p)         # 241 nodes, 1478-state ODE
u_settled = settle_to_equilibrium(sys, u0, p)    # pre-solve gravity sag (~0.3 s wall time)

# Power law wind profile (1/7 shear exponent)
wind_fn = (pos, t) -> begin
    z  = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0/7.0)
    [p.v_wind_ref * sh, 0.0, 0.0]
end

# Seed hub angular velocity and run 60 s
N, Nr = sys.n_total, sys.n_ring
u_start = copy(u_settled)
u_start[6N + Nr + Nr] = 1.0   # hub ω = 1 rad/s

u_final = simulate(sys, u_start, p, wind_fn; n_steps=1_500_000, dt=4e-5)
println("Hub ω = ", u_final[6N + Nr + Nr], " rad/s")
```

### GLMakie interactive dashboard

```bash
julia --project=. scripts/interactive_dashboard.jl
```

Opens a 3D view: rope node geometry, ring polygons coloured by structural utilisation
(blue = safe → red = at buckling limit), structural FoS HUD, frame playback slider.

### Regenerate reports from saved simulation data

```bash
python3 scripts/produce_report.py
python3 scripts/produce_free_beta_report.py
python3 scripts/produce_kite_turbine_potential_report.py
python3 scripts/produce_trpt_optimization_report.py
python3 scripts/produce_cartography_report.py
```

These read CSVs from `scripts/results/` and regenerate the Word documents. The simulation
and reporting steps are deliberately decoupled: you can regenerate reports without re-running
the Julia simulator (see Section 8 — key choices).

---

## 4. The physics and its assumptions

### What the model does

The TRPT shaft is modelled as 241 point masses: 16 ring nodes (ground anchor, 14 intermediate
rings, and the hub/rotor) plus 225 rope nodes (5 lines × 15 inter-ring segments × 3
intermediate nodes per segment). All 241 nodes obey Newton's second law. The state vector
has 1478 components: 3D position and velocity for each node, plus twist angle and twist rate
for each of the 16 ring nodes.

Torsional coupling is emergent. Each ring node has 5 attachment points arranged as a regular
pentagon in the plane perpendicular to the shaft. The helical winding angle between adjacent
rings offsets those attachment points. When torque is transmitted, the pentagon twists,
displacing attachment points and stretching the helical lines. The elastic tension in those
lines pulls back — that is the restoring torque. The model computes this without any analytical
torque formula: only the sub-segment spring law `T = max(0, EA·strain + c·damp·rate)` and the
geometry of where the rope ends are attached.

The `max(0, ...)` tensile-only clamp is the entire torsional collapse model. When a line goes
slack (zero tension), the torsional coupling through that line disappears. If enough lines go
slack simultaneously — as happens under severe overtwist — the shaft loses its ability to
transmit torque and collapses. This happens naturally from the physics, not from a detection
criterion.

Rotor aerodynamics use BEM-derived Cp and CT tables (from AeroDyn,
`Rotor_TRTP_Sizing_Iteration2.xlsx`), normalised to the full disc area πR². The TRPT blades
are physically annular (inner tip at r ≈ 0.4R, outer tip at R); the inner hub region
contributes negligibly at operational TSR so the full-disc normalisation is consistent with
the swept annulus. CT drives the axial hub thrust force. Cp drives the aerodynamic torque on
the hub ring node. The generator is modelled as an MPPT load: `τ_gen = k_mppt · ω²` on the
ground ring.

### What is simplified

**Fixed-ring-radius:** Ring nodes are point masses at their centre. Radial deformation of
the ring frame is not modelled. A ring that buckles would deform inward, but in this model
it remains a circular point mass while the FoS indicator just shows the margin to buckling.

**Hub lift history:** The lift device (kite or rotary lifter) applies a steady-state force
at each ODE step via `lift_force_steady()`. It does not have its own dynamics — there is
no model of the kite's flight path, line catenary, or gust response. The turbulent lift
variation is captured statistically through the wind model, not through an explicit kite
trajectory.

**Back line as single element:** The back-anchor tether from hub to ground anchor is a
single spring-damper. A real Dyneema line can sag and go slack. Multi-segment back-line
modelling is on the backlog (see Section 7).

**No blade pitch:** Blade angle of attack is fixed. There is no pitch control loop.
Bridling (adjusting rotor blade angle) is discussed in `NOTES_MPPT_TWIST.md` as future
work based on shaft twist as a proxy signal, but is not implemented.

**Centripetal effects — partially included:** Blade centrifugal force is included in the
optimiser hub-ring loading (Phase C onwards: centripetal vertex load subtracted from inward
line force, lumped at hub ring). Rope node centrifugal bow-out is present dynamically in the
ODE (rope nodes are free masses and will bow outward under spin). However, the structural
safety evaluator does not apply a centrifugal correction to ring inward forces — consistent
with the static-envelope design intent.

**Static envelope only:** Structural sizing is against a peak static load envelope at
25 m/s, not against a fatigue spectrum. There is no model of cyclic loading, S-N curves,
or accumulated damage.

### What would break these simplifications

If ring deformation is significant (rings collapsing inward), the point-mass approximation
fails: the simulated torque transmission would overestimate the real system's structural
stiffness. This matters at FoS close to 1.0.

If the back line sags substantially (hub drifts forward, back line catenary), the single
spring underestimates the hub's freedom to move. Real torsional collapse scenarios may be
conditional on back line sag — not yet captured.

If blade pitch changes substantially (wind speed range, bridling control), the fixed Cp/CT
tables become invalid outside the design TSR range. The current BEM tables are calibrated
for the design operating point.

---

## 5. What has been done (chronological)

### Canonical physics refactor (March 2026 — commits `6ca14ea`–`12bc91b`)

The predecessor codebase (`TRPTKiteTurbineJulia2`) had a bug: it applied a kite-style
aerodynamic lift force `q·A·CL` in the `[0,0,1]` direction to the hub node, alongside the
rotor CT thrust. This was wrong on two counts. First, the direction `[0,0,1]` is appropriate
for a horizontal disc, not for a rotor at 30° elevation — the disc normal force should follow
the shaft axis. Second, the CT thrust already captures the dominant axial hub force. The
blades rotating in the disc plane produce zero net hub lift; they are not a kite.

Removing this phantom lift changed the hub force balance: the required lift from the external
kite device dropped to just the airborne weight (245 N for the 10 kW system). This single fix
unblocked the lift device sizing analysis and the hub excursion study that followed. All
reports were regenerated against the corrected physics. Reference output:
`scripts/results/canonical_output_v12.0.csv`.

### MPPT × twist sweep (March–April 2026 — commits `eaa7b43`, `1943407`)

A parametric sweep of MPPT gain multiplier (0.5×–4.0× nominal) across four wind speeds
(8, 10, 11, 13 m/s) — 28 simulation cases, each run for 60 s after a 5 s spin-up, totalling
~23 wall-hours. Key findings:

- Optimal MPPT gain is at k×1.0–1.2× (very flat peak). Nominal calibration was already close.
- Shaft twist at optimal ranges from 238° at 8 m/s to 308° at 13 m/s. It is not
  wind-speed-independent: it tracks wind speed, which means twist can be used as a wind
  estimator but cannot be used alone as an MPPT feedback signal (it is ambiguous between
  under-braked and over-braked at the same twist value).
- Torsional stability confirmed: settled twist standard deviation ≤ 1.7°.
- A 7→14 m/s wind ramp over 150 s showed the TRPT delivers only 2.25 kW at the end of the
  ramp vs 13.4 kW at steady state — the mechanical inertia time constant is much longer than
  150 s. The TRPT cannot track a fast wind ramp.

Data: `scripts/results/mppt_twist_sweep/`. Analysis: `NOTES_MPPT_TWIST.md`.
Report: `TRPT_Twist_Analysis.docx`.

### Lift kite analysis (March–April 2026 — commits `bfa6249`, `abdf56b`, `32038c2`, `74a2079`)

Three lift device architectures were analysed: single passive kite, stacked kites (N identical
units on one line), and rotary lifter (TRPT-style ring rotor, blades pitched for lift,
fixed RPM).

After the canonical physics refactor, the required lift from any device is 245 N (airborne
weight only — CT thrust and shaft tension cancel at the hub in quasi-static equilibrium).

Key findings:
- A single passive kite sized for the 4 m/s cut-in condition needs 27.5 m² — a large parafoil.
  Required area scales super-linearly with rated power (mass exponent ~1.35), making the
  passive kite impractical beyond ~50 kW.
- Stacked kites provide the same lift and tension variance as a single kite of equal total
  area. The handling benefit (smaller individual units) is real; the stability benefit is not.
- Rotary lifter at fixed RPM has apparent wind dominated by tip speed (ω·r >> v_wind), so lift
  varies approximately as tip speed squared (constant), not wind speed squared (variable).
  Tension coefficient of variation: 3.6% vs 30.1% for single kite — 8× better. Hub vertical
  excursion: 0.9 mm vs 3.5 mm standard deviation in 3-second test runs (3.9× better).

The hub elevation angle β was freed as a dynamic degree of freedom (commit `74a2079`): shaft
direction is now `normalize(hub_pos)` at every ODE step, so the hub can droop realistically.

Cold-start collapse validation (`scripts/cold_start_collapse.jl`) confirmed hub droops from
30° to ~26° elevation over 10 s with no lift device. A single kite at sub-cut-in wind
(3.5 m/s) reduces droop by ~5×.

Data: `scripts/results/lift_kite/`. Analysis: `NOTES_LIFT_KITE.md`.
Reports: `TRPT_Lift_Device_Analysis.docx`, `Lift_Kite_Sizing_Report.docx`.

### TRPT sizing optimisation — Phase A–B1 (April 2026)

The first sizing optimisation used a 7-DoF search space: beam outer diameter, wall thickness
ratio, Do scaling exponent along the TRPT, rotor hub radius, taper ratio, and ring count.
Three beam cross-section families (hollow circular, hollow elliptical, symmetric airfoil
shell) were searched separately for 10 kW and 50 kW — 6 runs total. Structural fitness
criterion: FoS ≥ 1.8 at 25 m/s peak wind with Design Load Factor (DLF) = 1.2 (calibrated
from the canonical ODE via `scripts/calibrate_dlf.jl`; see Section 8).

Phase A refers to the initial search space formulation. Phase B refers to the DLF
recalibration after excluding the emergency-brake load case from the structural envelope
(the live system uses a yaw-stall back-anchor procedure to avoid sudden braking; the
ebrake DLF = 1.39 is an operationally-avoided fault).

Results: `scripts/results/trpt_opt/`. Report: `TRPT_Sizing_Optimization_Report.docx`.

### TRPT sizing optimisation — Phase C–H (April 2026 — commit `28bc58a`)

Phase C expanded to 12 DoF (adding axial profile family, n_lines/n_polygon_sides, knuckle
point mass at each vertex, centripetal relief). 60 independent DE islands ran in parallel
(12 at a time, 3 h budget each, 480 core-hours total). Top 200 feasible designs per island
were archived — 12 000 archived feasible designs.

Phase D used Latin Hypercube Sampling (480 000 points) to map the feasibility boundary and
global sensitivity (Spearman rank correlation). Do_top (outer beam dimension at hub ring)
dominates mass; taper_ratio and n_rings are next most significant.

Phase E verified top candidates against a six-point operating envelope (steady 8–25 m/s,
coherent gust 11→25 m/s) with a 1.5 FoS floor.

Phase F characterised n_lines and knuckle mass sensitivity. Sweet spot: n_lines = 8,
knuckle ≤ 20 g.

Phase G generated GLMakie renders of the winning designs.

Phase H auto-generated and refreshed `TRPT_Design_Cartography_Report.docx` every 15 min
during the campaign.

Global winner results from Phase C–H (FoS exactly 1.80, Euler buckling only — later found
torsionally infeasible in post-hoc check):

| Config | Beam family  | Axial profile  | Total mass |
|--------|-------------|----------------|-----------|
| 10 kW  | Circular    | Straight taper | 2.81 kg   |
| 10 kW  | Elliptical  | Straight taper | 2.81 kg   |
| 10 kW  | Airfoil     | Straight taper | 16.99 kg  |
| 50 kW  | Circular    | Straight taper | 19.22 kg  |
| 50 kW  | Elliptical  | Straight taper | 19.22 kg  |
| 50 kW  | Airfoil     | Straight taper | 155.37 kg |

### TRPT sizing optimisation — campaigns v3–v5 (April 2026)

**v3 (2026-04-22):** Torsional collapse (Tulloch/Wacker criterion) added as a hard
feasibility gate alongside Euler buckling. Post-hoc check on v2 results showed 54/60 islands
infeasible — the lightest 10 kW winner (2.808 kg) had torsional FOS = 0.069. v3 enforces
Euler FOS ≥ 1.8 + Torsional FOS ≥ 1.5 simultaneously. All 60 v3 islands converged to
cylindrical geometry (`taper_ratio = 1.0`) because uniform ring spacing penalises taper
(thin bottom segments get the same span as wide top segments, driving high L/r). 10 kW winner:
**15.435 kg**. Results: `scripts/results/trpt_opt_v3/`.

**v4 (2026-04-25):** Replaced the uniform-spacing + axial-profile approach with geometric
ring spacing that targets a constant L/r ratio across all segments (`ring_spacing_v4()` in
`src/ring_spacing.jl`). This lets the optimiser recover taper without the Euler buckling
penalty. Ring count `n_rings` is now a derived output, not an input; `target_Lr` replaces the
axial profile family. 60 islands (9 DoF). 10 kW winner: **10.587 kg** (−31.4 % vs v3).
n_lines = 8 unanimous across all 60 islands. target_Lr = 2.0. Results: `scripts/results/trpt_opt_v4/`.

**v5 (2026-04-30):** Closed the aerodynamic coupling loop: rotor radius R is now derived
self-consistently from n_lines via a BEM Cp(σ, TSR) surface (`src/bem_cp_model.jl`). In v4,
R was a fixed input and more lines had zero aerodynamic cost; in v5, Cp degradation from
over-solidity requires a larger R, increasing thrust and shaft mass. 60 islands, same geometry
as v4. 10 kW winner: **11.470 kg** (−25.7 % vs v3, +8.3 % vs v4). n_lines = 8 remains
unanimous across all 60 v5 islands. Results: `scripts/results/trpt_opt_v5/`.

Campaign progression summary (10 kW):

| Campaign | Constraint set                          | Best mass    |
|----------|-----------------------------------------|--------------|
| v2       | Euler only                              | 2.808 kg (invalid) |
| v3       | Euler + torsion (cylindrical forced)    | 15.435 kg    |
| v4       | Euler + torsion (taper free, fixed R)   | 10.587 kg    |
| v5       | Euler + torsion (taper free, BEM R)     | 11.470 kg    |

Figures for the above campaigns committed to `figures/report/` and `figures/` (16 figures
total). In progress: `TRPT_AWE_Forum_Report_v3.docx`.

---

## 6. What was learned

### Elliptical tube collapses to circular

The hollow elliptical beam family is strictly more general than circular — circular is the
special case with aspect ratio = 1. In every elliptical optimisation run the optimiser
converges to aspect ratio = 1, delivering identical mass to the circular result. The reason:
structural fitness is Euler column buckling, which is governed by the minimum second moment
of area I_min. For a given cross-sectional area (hence mass per unit length), a circular tube
maximises I_min. Making the tube elliptical increases I in one bending direction while
reducing it in the orthogonal direction, and the minimum governs. The elliptical family was
worth testing to confirm this — it does not add value here.

### Airfoil profile is dominated by circular under compression loading

An airfoil shell is aerodynamically clean but structurally inefficient under Euler buckling.
For a given mass, an airfoil shell has much lower I_min than a hollow circular tube of the
same perimeter, because the material is distributed as a thin aerodynamic shell rather than
around a symmetric cross-section. The 10 kW airfoil winner is 16.99 kg vs 2.81 kg for
circular — six times heavier. Airfoil profiles should only be considered if aerodynamic
frame drag is a dominant performance term, which it is not at this scale and wind speed.

### Straight-taper wins across all beam families and power classes

Five axial profile families were tested: uniform, linear taper, parabolic, elliptic, and
trumpet (flaring at ground end). Straight linear taper wins in every combination. The
physics reason: in a tapered TRPT, the peak compressive load per polygon segment is
approximately constant across rings (inward radial force scales with ring radius; polygon
segment length also scales with ring radius; the ratio P/P_crit stays flat). A straight taper
optimally allocates structural mass along the length. Other profile shapes create
under-loaded regions that carry excess mass.

### Torsional collapse not yet properly constrained in the optimiser

This is the most important open engineering gap. The structural fitness function evaluates
Euler column buckling FoS and beam manufacturability only. It does not enforce any constraint
on torsional collapse. Tulloch (PhD thesis, TU Delft) and Wacker (unpublished analysis)
derived the geometric limit at which a TRPT shaft collapses torsionally: the applied twist
angle per unit length must not exceed the limit set by the helical line geometry and ring
radius. This constraint is not currently computed or checked in `evaluate_design()`. Designs
that pass the Euler FoS check may still be torsionally fragile. See `DECISIONS.md`.

### Torsional constraint adds real mass; uniform spacing was imposing false cylindricity

The v2 Euler-only optimiser produced designs at 2.808 kg (10 kW) that looked excellent but
were torsionally infeasible by factors of 10–60×. The torsional FOS ≥ 1.5 constraint (v3)
increased the minimum mass to 15.435 kg — a 449 % increase. That penalty was then partially
recovered in v4 (−31.4 % vs v3) by switching from uniform to geometric ring spacing. The key
insight: uniform spacing with a tapered shaft gives small-radius bottom segments a very high
L/r ratio, making them structurally expensive and driving the optimiser toward cylindrical
geometry. Constant L/r spacing removes this artificial pressure and recovers taper as an
efficient structural strategy.

### n_lines = 8 is structurally dominant over the canonical n_lines = 5

All 120 optimisation islands across v4 and v5 unanimously select n_lines = 8 over the
canonical n_lines = 5. More lines shorten the polygon segment span, raising the Euler buckling
capacity. The aerodynamic cost (Cp degradation from higher solidity, quantified in v5 via BEM
coupling) is approximately 3–4 % in Cp, translating to ~2 % larger required R and ~2 % higher
shaft mass — well below the structural benefit. However, BEM strip theory is not validated for
n_lines > 6: wake interference and potential-flow blockage effects at n = 8 are unmodelled.
CFD or panel-method validation is required before adopting n_lines = 8 for hardware.

### Hub elevation angle β likely has a structural optimum near 26°

All sizing campaigns (v2–v5) fix β = 30°. The cold-start collapse analysis and lift-kite
equilibrium work showed the natural hub equilibrium without active lift is approximately β ≈ 26°.
A joint β + structural optimisation has not yet been run. The structural loads (thrust, tether
tension) vary with cos²β; a lower β reduces thrust but increases the tether length per unit
altitude — the net mass optimum is not obvious without a combined search.

### MPPT gain is near-optimal; ramp dynamics are the bigger concern

The flat power peak between k×1.0 and k×1.2 means MPPT gain is not a sensitive parameter
at steady state. The more important finding is the long mechanical inertia time constant:
the TRPT cannot follow a fast wind ramp. Control strategies must account for a large lag
between wind resource and delivered power.

### Hub elevation angle must be a dynamic degree of freedom

The original fixed-β model suppressed hub droop — any imbalance that would physically lower
the hub was constrained away by the geometry assumption. Freeing β revealed real droop
dynamics. The lesson: any degree of freedom the physical system can exercise must be included
in the model, even when the expected steady-state value matches the fixed assumption.

---

## 7. Known limitations and what could break

**n_lines = 8 requires CFD validation.** Campaigns v4 and v5 unanimously select n_lines = 8.
The BEM Cp model (v5) accounts for solidity-dependent Cp degradation but uses strip theory,
which is not validated for n_lines > 6. Blade-to-blade wake interference, potential-flow
blockage, and high-solidity corrections are unmodelled. n_lines = 8 should not be adopted
for hardware without CFD or panel-method Cp confirmation.

**OPT_DESIGN_LOAD_FACTOR is lumped and calibrated at one design point.** DLF = 1.2 was
calibrated from six load scenarios at the 10 kW rated point (see `trpt_optimization.jl`
source comments and `calibrate_dlf.jl`). It is applied uniformly across all ring radii and
all wind speeds in the optimiser. At off-design conditions the actual force distribution may
differ substantially from this lumped envelope.

**No fatigue model.** The structural sizing is against a peak static envelope only. Tether
lines, ring frame tubes, and knuckle joints all experience cyclic loading. Without an S-N
model and load spectrum, the structural sizing cannot claim fatigue life — only
survival-load margin.

**Centripetal effects partially included.** The optimiser subtracts centripetal blade
loading from the hub-ring inward force (Phase C onwards). Intermediate ring centripetal
loading is not included in the structural fitness evaluation. At high RPM, blade centrifugal
force can add substantial hoop tension to the hub ring. Ignoring this for intermediate rings
is the conservative (safe) side for Euler buckling.

**Static envelope only.** Dynamic amplification, resonance between the elastic TRPT shaft
and rotor harmonic loading (torque wave resonance — see `NOTES_MPPT_TWIST.md`), and impact
loads during handling are not captured.

**Back line is a single spring-damper.** A real Dyneema back line can go slack. The present
model cannot capture hub drift forward caused by back-line catenary. Multi-segment back-line
modelling is needed for realistic collapse scenario simulations.

**Solid-body collision not implemented.** Under severe droop (no lift, no wind), the hub can
fall through intermediate TRPT rings geometrically — there is no contact physics. This limits
what can be concluded from cold-start collapse runs and from launch/retrieval sequence
modelling.

**No blade pitch control.** The rotor runs at fixed blade angle. Bridling is a real control
degree of freedom in the physical device. Its effect on power curve, structural loads, and
torsional stability is not modelled.

---

## 8. Key choices and why

**Julia.** The multi-body ODE has 1478 states and must run at 4×10⁻⁵ s timestep to keep
the stiff rope springs stable. Julia's DifferentialEquations.jl (QNDF implicit solver)
handles the stiffness without the small-timestep penalty of an explicit integrator in Python
or MATLAB. Julia's type system also makes the node architecture (AbstractNode, RingNode,
RopeNode) clean and efficient without heap allocation in the ODE inner loop.

**Differential Evolution over gradient methods.** The TRPT sizing problem is
discrete-continuous (n_rings and n_lines are integers), multi-modal (different axial profiles
define disconnected feasible regions), and the fitness function has discontinuities where
manufacturability constraints activate. Gradient-based optimisers need smooth, differentiable
objectives. DE needs only function evaluations, handles discrete variables by rounding, and
naturally explores multiple local optima simultaneously through its population. F=0.7 and
CR=0.9 are standard DE settings that have worked well on similar engineering problems.

**FoS 1.8.** Offshore wind structural practice (IEC 61400-3) uses FoS 1.35–2.5 depending
on load type, inspection regime, and consequence of failure. For a prototype AWE system with
limited field data, load model uncertainty, and difficult in-service inspection (the structure
is airborne), 1.8 is a reasonable intermediate value: tighter than a well-characterised
ground-based structure, looser than a primary safety-critical member. It is a design choice
subject to revision once field data is available.

**25 m/s survival wind.** This is approximately the IEC 61400-1 Class III 50-year extreme
wind speed at hub height. The system is not expected to generate power at 25 m/s; it should
survive stowed in that wind without structural failure.

**30 m tether length.** The baseline TRPT shaft length for the 10 kW system. It determines
the number of torsional degrees of freedom in the shaft (more length = more twist capacity)
and the aerodynamic rotor altitude (affects shear and turbulence). It is a design parameter,
not a derived quantity.

**Decoupled simulation and reporting.** Julia runs the ODE and writes results as CSVs.
Python reads those CSVs and writes Word documents. This decoupling allows overnight
simulation runs to be analysed and re-reported without re-running the simulator (which can
take 14+ hours per case). It also means report generation is reproducible from saved data
without needing a running Julia environment. The tradeoff is that reports can become stale
if new simulation data is generated without triggering a report regeneration —
`RESTART_INSTRUCTIONS.md` documents the regeneration sequence.

---

## Design reports

All design reports are checked into the repo as `.docx` files for sharing.

| Report | Contents |
|---|---|
| `TRPT_Dynamics_Report.docx` | Core multi-body dynamics; ODE architecture; emergent torsion; power results |
| `TRPT_FreeBeta_Report.docx` | Free hub elevation angle β; droop dynamics; cold-start results |
| `TRPT_Twist_Analysis.docx` | MPPT × twist sweep; optimal MPPT gain; twist as wind estimator |
| `TRPT_Lift_Device_Analysis.docx` | Lift device comparison; static force analysis |
| `Lift_Kite_Sizing_Report.docx` | Lift device comparison; full hub excursion analysis |
| `TRPT_KiteTurbine_Potential.docx` | Power curve; kite turbine potential vs installed wind |
| `TRPT_Ring_Scalability_Report.docx` | CFRP ring sizing; Do ∝ √R scaling law; P/W vs radius 1–5 m |
| `TRPT_Stacked_Rotor_Analysis.docx` | Blade count sweep; stacked rotors; conical stack 44.2 kW at 540 W/kg |
| `TRPT_Conical_Stack_Analysis.docx` | Wind shear benefit; centrifugal radius expansion; conical stack P/W |
| `TRPT_Sizing_Optimization_Report.docx` | Phase B1 DE sizing; 7-DoF; three beam profiles |
| `TRPT_Design_Cartography_Report.docx` | Phase C–H cartography; 60-island campaign; 11.5 B evaluations |
| `TRPT_AWE_Forum_Report_v3.docx` | v2–v5 campaign progression; n_lines = 8 finding; BEM Cp coupling (in progress) |
| `KTD_Novelty_and_Prior_Art_Review.docx` | Patent and prior art landscape |

---

## System architecture

```
Ground anchor (fixed)
│
├─ 5 tether lines × 4 sub-segments per inter-ring segment
│    Each segment: ring_A ─ rope_1 ─ rope_2 ─ rope_3 ─ ring_B
│    Torque propagates via elastic stretch of helical lines;
│    torsional stiffness and collapse are emergent from geometry
│
├─ 14 intermediate rings (pentagon CFRP frames, RingNodes)
│
└─ Hub (RingNode) — rotor disc, lift kite attachment
     Kite/rotary lifter force + CT rotor thrust + MPPT load
```

**Total nodes:** 241 (16 RingNode + 225 RopeNode)
**State vector:** 1478 (3D pos + vel for 241 nodes + twist angle + rate for 16 rings)

---

## Tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

All 11 test suites pass. Test names and what they verify are listed in Section 2.

---

## Backlog

Known open items not yet implemented:

- **CFD/panel-method validation of n_lines = 8 Cp** — BEM strip theory not validated above
  n = 6. Required before adopting n_lines = 8 for hardware. Highest-priority for v6.
- **Joint β + structural optimisation** — β fixed at 30° through all campaigns; optimum likely
  near 26°. v6 should free β alongside structural design variables.
- **Dynamic torsional loading and fatigue** — all structural sizing is against a static peak
  envelope. Cyclic 1P/2P tether tension, S-N curves, and accumulated damage not modelled.
- **Multi-segment back line** — replace single spring-damper with 5+ rope nodes to allow
  catenary sag and forward hub drift
- **Solid-body collision physics** — ring and rotor interpenetration under severe droop;
  need contact normals and impulse-based rigid-body response
- **Stacked rotor configurations** — multiple turbine stages on one TRPT shaft
- **Launch and retrieval sequence simulation** — ramp from ground to operating altitude
- **Turbulent wind field input** — von Kármán or Kaimal spectrum

---

## Licence

MIT © 2025–2026 Rod Read / Windswept & Interesting Ltd
