# DECISIONS.md — KiteTurbineDynamics.jl

Running log of architectural and physical decisions. One entry per decision, newest at top.
Each entry explains the situation, what was decided, what alternatives were on the table, why
this choice was made, what it enables and rules out, and whether it is still active.

The purpose of this file is to make the reasoning behind the simulator transparent — so anyone
reading the code can understand not just *what* was done but *why*, and so future contributors
can assess whether a decision still holds when circumstances change.

---

## [2026-04-20] Taper ratio and n_rings lower bounds in DE search space

**Context:** The 12-DoF search space for the Phase C optimisation needed lower bounds on
`taper_ratio` (r_bottom / r_top) and `n_rings` (number of intermediate polygon frames). A
taper ratio near zero would produce a TRPT that tapers to a point at the ground end — geometrically
degenerate and physically implausible. Too few rings and the inter-ring segment length grows
long, increasing the segment Euler buckling load dramatically for a given beam size.

**Choice made:** `taper_ratio` lower bound set at 0.15 (the bottom ring radius is at least
15% of the top ring radius). `n_rings` lower bound set at 3 (minimum of 3 intermediate rings,
giving 4 inter-ring segments over the 30 m tether length — segment length ≤ 7.5 m).

**Alternatives considered:** Lower `taper_ratio` bound of 0.05 (nearly a point) was considered
to let the optimiser fully explore the extreme taper space. Lower `n_rings` bound of 1 was
considered to allow very sparse configurations.

**Why this choice:** A taper ratio below ~0.2 produces a bottom ring so small that attachment-
point geometry is dominated by rope sag rather than ring radius, making the structural model
increasingly inaccurate. Below 0.15 the ring is smaller than the rope diameter at minimum SWL,
which is physically nonsensical. For n_rings, fewer than 3 intermediate rings means inter-ring
spacing exceeds 6 m; at this segment length and the design tether tensions, even large-diameter
beams are near the buckling threshold. The optimiser would waste evaluations on degenerate
geometries. These bounds are engineering-informed guards, not arbitrary.

**Consequences:** Regions of parameter space below these bounds are not explored. If a
genuinely optimal design existed below taper_ratio = 0.15 (extremely unlikely given the
buckling physics), it would be missed. The 60-island campaign found all global minima well
above these bounds (taper_ratio ≈ 0.25 for straight-taper winners), confirming the bounds
do not constrain the real optimum.

**Status:** Active.

---

## [2026-04-20] DLF (Design Load Factor) calibrated at 1.2; emergency brake excluded

**Context:** The structural fitness function needs to convert tether line tension into an
effective inward radial force per pentagon vertex — the input to the Euler buckling FoS
calculation. Under perfectly uniform loading and zero twist, the net radial force per vertex
is zero (tension components from above and below cancel). In practice, taper non-uniformity,
torque-induced helix inclination, and gust asymmetry all create a non-zero inward force. A
lumped Design Load Factor (DLF) captures this: F_in_per_vertex = DLF × T_line.

DLF was calibrated from `scripts/calibrate_dlf.jl` by running the canonical 10 kW ODE through
six load scenarios and extracting the peak per-ring inward-force envelope:
- Steady 11 m/s (rated): 0.83
- Steady 15 m/s: 0.56
- Steady 20 m/s: 0.40
- Steady 25 m/s (peak design wind): 0.32
- Coherent gust 11→25 m/s: 0.74
- Emergency brake (k_mppt stepped to 3×): 1.39

The emergency brake produces the highest DLF (1.39) by a large margin.

**Choice made:** DLF = 1.2. The emergency brake scenario is excluded from the sizing
envelope.

**Alternatives considered:** DLF = 1.39 (include emergency brake as a sizing case).
DLF = 0.85 (size against rated + small margin only).

**Why this choice:** The emergency brake at 3× k_mppt is an operationally-avoided fault.
The live system shutdown sequence is: (1) ease MPPT load through a controlled ramp, never
a step; (2) haul on back-anchor tether to yaw shaft off-axis; (3) rotor stalls
aerodynamically before mechanical braking is applied; (4) haul stalled rotor down on lifter
line. No step change in k_mppt ever hits the airframe in normal operation. Sizing to a fault
that is operationally mitigated would penalise the design weight significantly (DLF 1.39 vs
1.2 is a ~16% increase in required second moment of area). DLF = 1.2 provides ~60% margin
over the worst aero-only steady case (0.83 at rated) and ~60% margin over the coherent gust
transient (0.74), while covering manufacturing tolerance and Class A turbulence.

**Consequences:** The structural sizing is contingent on the shutdown procedure being followed.
If the shutdown sequence is violated (e.g., sudden electrical disconnect causing step braking),
the structure is under-designed for that event. This is an operational constraint, not a design
safety margin. If the shutdown procedure ever changes to allow step braking, DLF must be
recalibrated.

**Status:** Active. DLF recalibrated once already (Phase B); will need revisiting when 50 kW
system load cases are calibrated independently.

---

## [2026-04-20] Torsional collapse not in optimiser fitness function

**Context:** The TRPT structural fitness function (`evaluate_design()` in
`src/trpt_optimization.jl`) evaluates Euler column buckling FoS of each polygon segment and
checks beam manufacturability bounds. It does not evaluate whether the shaft can transmit the
design torque without torsionally collapsing. Torsional collapse is the characteristic failure
mode of a TRPT shaft: when the applied twist angle per unit length exceeds the geometric limit
set by the helical line winding angle and ring radius, the lines go slack and the shaft loses
its torque-transmitting ability.

Tulloch (PhD thesis, TU Delft) and Wacker (unpublished analysis, Windswept internal) derived
the torsional collapse criterion for TRPT-style tensile shafts. The criterion sets a minimum
on (ring radius × number of turns) relative to (shaft torque ÷ tether tension). This is a
geometric stability limit, distinct from material failure.

**Choice made:** Torsional collapse constraint not implemented in the Phase B or Phase C–H
optimiser. The optimiser sizes for Euler buckling only.

**Alternatives considered:** Implement the Tulloch/Wacker criterion as an additional Boolean
feasibility constraint in `evaluate_design()`, returning infeasible for any design that cannot
transmit the rated torque without collapsing. This is the correct long-term approach.

**Why this choice (at the time):** The Tulloch/Wacker criterion requires knowledge of the
operating torque and tether tension at rated conditions, which depend on the rotor radius and
the aerodynamic model — inputs that are fixed for a given power class (10 kW or 50 kW) but
which interact with the geometric design variables in a non-trivial way. Implementing the
constraint correctly requires either (a) computing the torsional limit analytically from the
design geometry and rated operating point, or (b) running the multi-body ODE for each
candidate design (computationally prohibitive at 192 million evaluations per island). The
correct approach is (a), but it requires deriving the closed-form torsional stability limit
for a tapered, variable-radius TRPT shaft — not a trivial extension of Tulloch's constant-
radius derivation. Deferring this allows the Euler-only sizing to complete while the torsional
derivation is developed separately.

**Consequences:** Designs that pass the Euler FoS check may still be torsionally fragile.
In particular, designs with small ring radius, few lines, or very long inter-ring spacing
may be well under the torsional stability limit at rated torque. The optimiser cannot detect
this. Any winning design from the Phase C–H campaign should be independently checked against
the Tulloch/Wacker criterion before being treated as a final design.

**Status:** Under review — active known gap. This is the highest-priority structural modelling
task flagged by Tulloch's PhD and Wacker's analysis. Implementing the constraint correctly will
require deriving the tapered-TRPT torsional stability limit and adding it to `evaluate_design()`.

---

## [2026-04-09] Hub elevation angle β freed as a dynamic degree of freedom

**Context:** The original model fixed the hub position such that the shaft always pointed at
the design elevation angle β = 30°. This was implemented by reading `p.elevation_angle`
as a fixed parameter in `rope_forces.jl` and suppressing hub translational velocity in
`orbital_damp_rope_velocities!`. The hub could not droop.

**Choice made:** `shaft_dir` in `rope_forces.jl` is now computed as `normalize(hub_pos)` at
every ODE step. Hub ring translational velocity is no longer killed. The hub is a free 3D
body, held by rope tension + back line + lift device.

**Alternatives considered:** Keep fixed β but add a spring-restoring force toward the nominal
hub position. This would allow some hub motion while preventing numerical drift, but it
introduces an artificial restoring force with no physical basis.

**Why this choice:** The hub elevation angle is a physical outcome of the force balance, not
a design input. A simulator that constrains it to a fixed value cannot model droop, collapse,
or the dynamics of lifting and lowering the system. The freedom is essential for any realistic
launch/retrieval or fault simulation. The intermediate ring velocities are still suppressed to
prevent numerical drift, but the hub itself must be free.

**Consequences:** Simulations now require a lift device or CT thrust to maintain hub altitude.
Without any lift force, the hub droops from 30° to ~26° over ~10 s. This is physically
correct. Simulations from this commit onward produce different hub position trajectories than
earlier runs — they are more realistic, not broken.

**Status:** Active.

---

## [2026-04-01] Sim/reporting decoupled: Julia CSVs → Python Word documents

**Context:** The original pipeline ran Julia to produce results and immediately generated Word
reports in the same script. This made overnight batch runs monolithic: if the report generator
crashed (e.g., a Python library issue), the simulation data was lost or had to be re-run. It
also meant the simulation environment (Julia) and the reporting environment (Python/python-docx)
had to both be available and working simultaneously.

**Choice made:** Julia scripts write results as CSVs to `scripts/results/`. Separate Python
scripts (`produce_*.py`) read those CSVs and generate Word documents. The two steps are
completely independent.

**Alternatives considered:** Single Julia → Word pipeline using a Julia Word library
(e.g., OOXML.jl). This would avoid the Python dependency but requires maintaining Julia-side
document formatting code — more fragile and less readable than Python's mature python-docx.

**Why this choice:** Decoupling means (a) simulation data is preserved regardless of what
happens to the reporting step, (b) reports can be regenerated from saved data without
re-running multi-hour simulations, (c) the two toolchains (Julia numerics, Python/Word
formatting) each stay in their natural domain, and (d) adding new analyses to existing reports
only requires changing the Python scripts. The tradeoff is that reports can become stale —
`RESTART_INSTRUCTIONS.md` documents the regeneration sequence to guard against this.

**Consequences:** All overnight simulation runs must explicitly write their outputs as CSVs.
Any analysis that was computed in memory but not saved to CSV is lost on process exit. Julia
scripts must be written with explicit `CSV.write()` calls; results should not rely on Julia
session persistence.

**Status:** Active.

---

## [2026-03-28] Differential Evolution chosen over gradient-based optimisation

**Context:** The TRPT structural sizing problem requires minimising the total ring frame
mass subject to FoS ≥ 1.8 for all rings. The search space includes discrete variables
(n_rings, n_lines) and the fitness function has discontinuities where manufacturability
bounds activate (minimum wall thickness, t/D limits). Multiple axial profile families create
disconnected feasible regions.

**Choice made:** Differential Evolution (DE) with F = 0.7, CR = 0.9, population size 64.

**Alternatives considered:** L-BFGS-B (gradient-based, handles box constraints), CMA-ES
(covariance matrix adaptation evolution strategy), Bayesian optimisation (surrogate model).

**Why this choice:** L-BFGS-B requires differentiable objectives — the t_min wall clamp and
integer rounding for n_rings and n_lines make this impractical without smoothing heuristics.
CMA-ES is effective on continuous, unimodal problems but struggles with the multi-modal
structure introduced by the five axial profile families. Bayesian optimisation builds a
surrogate model that becomes expensive to maintain beyond ~1000 evaluations; the analytic
fitness function evaluates in <1 ms so the surrogate overhead is never recovered. DE handles
all of these naturally: it operates on populations that maintain diversity across disconnected
feasible regions, rounds integer variables, and needs only function evaluations. F=0.7, CR=0.9
are standard settings from Storn & Price (1997) that have converged reliably on similar
engineering sizing problems.

**Consequences:** DE converges more slowly per function evaluation than a gradient method
when the problem is smooth and unimodal. In this case, the fast analytic fitness (192 million
evaluations per island in ~3 h on a single core) more than compensates. The 60-island campaign
provides independent convergence verification: when two seeds of the same island reach the same
minimum, we have high confidence it is the global optimum within that (beam, axial profile)
combination.

**Status:** Active.

---

## [2026-03-20] FoS 1.8 as the structural feasibility threshold

**Context:** The optimiser needs a single scalar threshold to classify designs as structurally
feasible or infeasible. This threshold directly controls the minimum-mass winner — a higher
FoS threshold produces heavier, more conservative designs; a lower threshold produces lighter
designs with less margin.

**Choice made:** FoS ≥ 1.8 as the hard constraint. The constraint is applied to Euler column
buckling of each polygon segment at the peak design load (25 m/s, DLF = 1.2).

**Alternatives considered:** FoS 1.5 (IEC 61400-1 extreme event, well-documented loads),
FoS 2.5 (conservative for novel technology with poorly characterised loads), FoS 3.0 (used in
earlier TRPT_Ring_Scalability_Report analysis for rated-load buckling).

**Why this choice:** FoS 3.0 in the scalability report was applied at rated load (11 m/s),
not at the 25 m/s survival load. At 25 m/s the load is approximately 5× the rated load
(load ∝ v²); applying FoS 3.0 at 25 m/s would produce enormously heavy designs. FoS 1.8
at 25 m/s corresponds to roughly FoS 9 at rated — conservative for the operating regime.
IEC 61400-3 guidance for offshore wind uses 1.35 for partial safety factor on thrust load
with well-characterised dynamic response; for an AWE prototype with limited validation, 1.8
provides additional margin against load model uncertainty, manufacturing variability, and
installation-induced pre-stress.

**Consequences:** Designs at FoS exactly 1.8 are accepted. Any design that the model deems
feasible at FoS 1.8 may have true FoS lower or higher depending on how well the analytic
buckling model represents the as-built structure. The FoS threshold is a design policy, not
a guarantee — it should be revisited with measured field data.

**Status:** Active. The Phase E envelope check verified top candidates at a 1.5 FoS floor
across six operating points; all winners satisfied 1.5 floor comfortably, which gives
confidence that 1.8 at the survival design point is not marginal.

---

## [2026-03-18] Emergent torsion replaces analytical torque formula

**Context:** The predecessor code (`TRPTKiteTurbineJulia2`) computed inter-ring torque
transmission using `compute_tensegrity_torque()` — an analytical formula relating the twist
angle difference between adjacent rings to a restoring torque via a torsional stiffness
constant. This gave one scalar torque per ring pair. Torsional collapse was detected by a
separate threshold check on the twist angle.

**Choice made:** `compute_tensegrity_torque()` is deleted entirely. Torsional coupling
emerges from attachment-point geometry. Each of the 5 lines has 3 intermediate rope nodes;
tension in each sub-segment contributes a linear force and a torque to its ring nodes through
the cross-product `r_attach × T_vec`. Torsional collapse emerges from the `max(0, ...)`
tensile-only spring clamp.

**Alternatives considered:** Keep the analytical torque formula but add line-by-line slack
detection to capture torsional collapse more accurately. This hybrid approach would have been
faster to implement.

**Why this choice:** The analytical formula requires calibrating a torsional stiffness
constant, which is itself a function of the line geometry, material properties, and pre-tension
— all of which change dynamically. Calibrating it correctly is as hard as the physical model.
More fundamentally, the analytical formula cannot capture load wave propagation, snap loads,
or the asymmetric partial-collapse behaviour where some lines go slack and others remain taut.
These are physically real phenomena that a lumped-parameter model cannot represent. The
emergent approach models each line individually; the correct torsional stiffness, damping, and
collapse threshold all fall out of the geometry and material properties without additional
calibration.

**Consequences:** The ODE state vector grows from 128 states (TRPTKiteTurbineJulia2) to 1478
states. Simulation time increases proportionally. The QNDF implicit solver is needed to manage
the stiffer system (shorter sub-segment springs). This is the fundamental reason for rewriting
the simulator in a new package rather than extending the old one.

**Status:** Active. The emergent model is the simulation core from which all analyses derive.

---

## [2026-03-18] Canonical physics refactor: phantom CL lift removed from CT thrust

**Context:** The predecessor code applied two aerodynamic hub forces simultaneously: a BEM CT
rotor thrust in the tether (shaft) direction, and a kite-style lift force `q·A·CL` in the
`[0,0,1]` (straight up) direction. The intent was to model the net upward force from the
rotating disc. This was physically wrong for two independent reasons.

**Choice made:** The `q·A·CL` block in `ring_forces.jl` was deleted. The only aerodynamic
hub forces are: (1) CT thrust in the shaft direction, and (2) the separate lift device force
(from `lift_kite.jl`, applied only when a LiftDevice is provided).

**Alternatives considered:** Correct the CL direction from `[0,0,1]` to the disc normal
direction (shaft axis) and reduce the CL coefficient to avoid double-counting with CT. This
was considered but rejected: the disc normal force is CT thrust by definition. There is no
additional kite-style lift force from the rotor disc at 30° elevation — the in-plane wind
component (v·sin30°) produces a force slightly downward along the tether, not upward.

**Why this choice:** The phantom CL lift inflated the hub's upward force, making the hub
appear to float on its own aerodynamic lift at much larger apparent kite area than physically
justified. This masked the real requirement for the lift device: once removed, the required
lift dropped to just the airborne weight (245 N), which changed the sizing of all three lift
device architectures. Removing phantom forces is always preferable to correcting them: a
correction requires an accurate coefficient, while removal just applies the correct physics.

**Consequences:** All simulations before this commit (including all reports prior to
`12bc91b`) used the phantom lift. Their hub force balance and lift device sizing conclusions
are wrong. The canonical reference output is `scripts/results/canonical_output_v12.0.csv`
from after this fix. All reports were regenerated.

**Status:** Active. This decision is permanent — the phantom force was a bug, not a modelling
choice.

---

*This file is updated with each significant decision. Minor implementation choices (variable
names, code structure, test organisation) are not recorded here. Record a decision when:
(a) multiple plausible alternatives existed, (b) the choice has non-obvious consequences, or
(c) the choice is likely to be revisited or questioned.*
