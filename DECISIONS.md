# DECISIONS.md — KiteTurbineDynamics.jl

Running log of architectural and physical decisions. One entry per decision, newest at top.

## 2026-07-17: Phantom triangle validated — legacy results re-legitimised

**GATE PASS (exact):** `build_phantom_triangle(blade_scale=0.85)` + legacy
kickstart protocol reproduces `wind_sweep_triangle_legacy.csv` 0.85/k2/11 m/s
bit-for-bit: 117.4 kW @ 411 rpm, FoS 4.52, T 77.3 kN.

**Consequence:** all numbers previously shared with Strathclyde are verified
simulations of a now-deliberately-specified design (3-line triangle, 22 rings,
untapered 2.99 m, rotors at rings 14/17/20 with bank 18/11/4°, 11.6 m² blade
area) — not artifacts of a bug. The kickstart/high-RPM-equilibrium finding is
protected.

**12-gon regression check (partial):** the fixed decode reproduces the
campaign's `best_design.json` 10/10 fields exactly (geometry-level validation
✓). Dynamic numbers from `dynamic_verification.txt` (12.1 kW @ 55.6 rpm, k=62)
are NOT reproducible on current code — physics and `params_v5_50kw().k_mppt`
have evolved since the campaign era. Current-code 12-gon with spokes+shear:
109.6 kW @ 119.5 rpm FoS 0.79 at k=62 (possibly viable on power, fails FoS).

**Geometry fingerprint mandate (Rod):** every sweep CSV must embed
`geometry_fingerprint()` output (n_blades/rotor, tip, chord, per-rotor and
total blade area, masses, taper) so cross-configuration tables can never hide
a λ-reference shift.

## 2026-07-17: x-vector packing fix — drop-direction and blades-per-rotor (Rod)

**Severity: Campaign-defining.** The `_build_v10_tight` builder has been packing
`best_design.json` in JSON-field order into a `design_from_vector_v4` decoder,
producing a phantom 3-line/22-ring/untapered triangle system. All sweeps and
dashboard runs used this incorrect geometry. Fix: load `best_vector.csv` directly
(Phase 1a of `docs/plans/fix_xvector_rerun_sweeps.md`).

**Gate 1b — which rotor to drop (Rod, 2026-07-17):** The expansion rotor nearest
the **ground** (lowest ring_idx) was removed as an experiment to reduce power draw.
Fix: sort rotors by ring_idx ascending, `popfirst!` removes the ground-adjacent
rotor. Print text corrected to match.

**Gate 1c — blades per expansion rotor (Rod, 2026-07-17):** `n_blades = n_lines`
for a balanced polygon frame. A 12-gon system gets 12 blades per expansion rotor
(12 vertices, blade at each). Fewer blades must divide `n_lines` evenly for
balance (e.g. 3 blades on a 6-line hexagon ✓). The triangle-bug systems had 3
blades/rotor (n_lines=3); corrected 12-gon has 12 blades/rotor. This is physically
intended — blades balance around the polygon vertices.

## 2026-07-06: Wrap-rate applicability — swivel rating = hardware ω ceiling

**Severity: Gate 2 constraint.** Wrap rate applies to the TRPT rig because a
stationary member (rigidised pipe-shrouded lift line) passes through the
rotating shaft axis at the top swivel bearing.

**Configuration (Rod):** The top swivel has a rigidised pipe-shrouded lifting
line segment passing through it, held to the underside of the bearing by washers
and a carefully bound and finished knot. Above the bearing, the back line is
tensely anchored to the ground — this resists torque propagating upward into the
top lift line. A flange between the rigidised pipe and the back line is under
consideration to further prevent wrap risk.

**Finding: wrap rate applies.** If no stationary member crossed the rotation
axis, wrap rate would be n/a (pure bearing interfaces). With a stationary
member, the swivel is the decoupling interface — its rated RPM is the hardware ω
ceiling. The mitigations (ground-anchored back line, proposed flange) reduce
torque ingress to the swivel but do not raise the bearing's speed rating.

**Gate 2 impact:** Current Gate 2 operating points (λ=0.69 at 337 rpm; Tight at
376 rpm) must be checked against the swivel's rated RPM. If the swivel is rated
below ~300 rpm, all left-flank designs require a bearing upgrade or gearbox
relocation of the speed ceiling.

**Status:** Applicability confirmed. Rated RPM value TBD — Rod to supply swivel
make/model or measurement.

## 2026-07-05: Blade geometry defect — expansion rotor annulus 3× too far outboard

**Severity: CRITICAL.** Every simulation using expansion rotors was affected.

**The defect:** `blade_hub_radius = 0.25 * blade_tip_radius` placed the
entire blade annulus outboard of the ring attachment point. The blade hub was a
positive outboard offset (25% of tip), meaning the inner edge sat outboard of the
ring and the mean aerodynamic radius was `r_nom + 0.625·s·cos(β)`.

**The correction:** `blade_hub_radius = -0.3 * blade_span` (negative = inboard of
ring) and `blade_tip_radius = 0.7 * blade_span` (positive = outboard). The
correct mean radius is `r_nom + 0.2·s·cos(β)`. The offset was overstated by a
factor of ~3.1×.

**Root cause:** BEM's hub-root-cutout convention (hub_radius = 0.25 × tip_radius,
measured from shaft axis for nacelle clearance) was mistakenly adopted as a ring
offset. In a conventional HAWT, the hub is a physical structure at some distance
from the shaft. In TRPT, the ring IS the hub — the blade attaches AT the ring, so
~30% sits inboard (toward shaft axis) and ~70% outboard. Different coordinate
systems; different parameter semantics.

**Impact:** Expansion rotor power, torque, centrifugal forces, ring structural
loading, FoS values, k_mppt values, loss model coefficients, and blade-scaling
laws were all computed on wrong geometry. V6-V10 optimisation campaigns evaluated
designs on wrong physics. The Gate 1 control maps (all three builders), the
AWEC Porto poster, and the technical report carried invalid numbers.

**Fix:** 13 files changed (src/objective_v6.jl, src/objective_v10.jl, 6 scripts,
3 doc/vis files, 2 handover/docs). See PRD 0006 for full audit and recovery plan.

**What survived:** Hub rotor aerodynamics (uses BEM `sys.rotor.radius` from shaft
axis), ring geometry, TRPT structural model code, tether dynamics, and any sims
without expansion rotors.

**Decision:** Gate 1 re-run with corrected geometry (in progress). All downstream
numbers, reports, and claims to be re-verified against corrected results before
publication. Old CSVs retained as tier-X reference; new ones supersede them.

**2026-07-06 P1 provenance resolution:** The fix was committed as `13f304a`
(2026-07-05T21:07+0100). The tier-X biased runs (14:58–19:18) used code state
`d661dfc` (pre-fix). The corrected runs (21:37–00:37) used `13f304a`. All six
CSVs were retro-annotated with `code_state:` stamps. The hardcoded `GIT_HASH`
constant in `hunt_kmppt_bisect.jl` was replaced with `git rev-parse` auto-detect
plus a `-dirty` flag for uncommitted src/script edits. A `tier-X-biased-geometry/
README.md` was added documenting the DO-NOT-CITE status. Attribution: CSV
annotations, README, and GIT_HASH auto-detect were contributed via the Cowork
advisor session of 2026-07-06; the Gate 1 runner stubs with done-timestamps
originate from the 07-05 sequential-run session; the Gate 1 max-power runner
with VerifySlice/P_aero fields is from the primary Hermes session.

**2026-07-06 script cleanup:** `scripts/hunt_kmppt_maxpower.jl` was deleted
(`git rm`). It was the abandoned first-attempt max-power script that used
`ExtendedSimFrame` and produced garbage at low winds. All Gate 1 runs used
`scripts/hunt_kmppt_bisect.jl` instead. History retained at `51e70cb`.

**2026-07-06 Gate 1 methodology defects #2 and #3 (P2 k-refinement findings):**

Defect #2 — **5s pre-sweep k-selection is invalid (systematic, all 18 rows).**
The Gate 1 max-power hunt uses a 5s pre-sweep (`T_HUNT=5.0`) to pick k,
then verifies at 60s. The 5s sims have not reached steady state; P is still
rising. This systematically biases k toward higher values (right flank of the
true P(k) curve). Three-row k-refinement with 60s verifies shows the true
steady-state peak at much lower k for all three builders.

Defect #3 — **T_VERIFY=60s insufficient for V10 Tight at low k.**
Timeseries at k=6.23 for V10 Tight @ 11 m/s shows P(t) still drifting at 60s
(range 47 kW over final 20s, drift +11%). The 247.4 kW last-slice snapshot
(claimed +108%) is a transient artefact, not converged steady state. At
t=57–59s, P swings 226→270→247 kW — possible onset of dynamic instability
at low k/high ω, not just slow settling. R3 λ=0.69 is deterministic at 60s
(ΔP=0.0000% on re-run); T_VERIFY sufficiency is design-dependent.

**Implications for Gate 1 re-run:**
- `T_HUNT` must be extended until P(t) flattens (sliding-window convergence
  criterion, not fixed duration). Adaptive stop: fast designs finish at
  ~60–80s, only Tight rows run long. Cap at ~240s.
- Report windowed-mean P, never last-slice. Last-slice artefacts manufactured
  the 247.4 kW +108% claim.
- Record ω(t) and FoS(t) alongside P(t) to distinguish slow settling from
  dynamic instability. If ω ramps or oscillates, low k may be dynamically
  unstable — a more important finding than "peak is at lower k."
- V10 Tight stays retired on its 13 m/s FoS wall (best FoS=1.24 at any k,
  still below 1.5). The 11 m/s question is unresolved until P(t) converges.
## 2026-07-06: Corrected expansion rotor ring radii

Verified via scripts/verify_ring_radii.jl. r_tip = ring_radius + 0.7·blade_span
≈ 4.6-5.8m across the three builders. Gate 1 ω values (150-322 rpm) correspond
to Mach 0.18-0.54 — well subsonic, BEM model is valid throughout.

**Retraction:** the 2026-07-06 handover claimed "expansion rotor tips at Mach
1.2-1.7" and "subsonic BEM beyond validity at ω ≥ 260 rpm." Both are wrong.
Root cause: ring radii were estimated as ~12m (confusing ring polygon radius
with ring position along the shaft). Actual RingNode.radius values are 2.2-3.0m.
Gate 1 never exceeded Mach 0.54. The "defect: BEM validity" entry is struck.

**Magnitude correction:** the centrifugal force magnitude check used r_mean ≈ 12m
→ F_cf ≈ 27 kN. At correct r_mean ≈ 3.5m (ring radius + mid-span projection):
F_cf ≈ 8 kN at 260 rpm — still significant vs aero F_radial, so the centrifugal
fix stands, but all downstream numbers quoting 27 kN need correction.

## 2026-07-06: Spoke engagement onset and SWL derivation
Spoke engagement onset is at ~191 rpm on beam+knuckle mass alone (load-dependent,
not a fixed threshold). 7mm Dyneema spokes: MBL 44.0 kN (generic SK78 catalogue,
provisional pending Rod's reel spec), SWL = 44.0 × 0.90 splice × 0.50 creep/fatigue/UV
= 19.8 kN. Spoke FoS-1.0 crossing moves well above 376 rpm for all designs.
The spokes replace the old "clamp" — the outward load path is now a measured
structural check. See `SpokeParams` in `src/expansion_rotor.jl`.

## 2026-07-06: Spoke ties design change (Rod)

Radial 7mm Dyneema spokes from
each ring vertex to a floating center node, engaging under net-outward radial
load. `SpokeParams` in `src/expansion_rotor.jl`: d_line=0.007, SWL=19.8 kN
(derived from 44.0 kN MBL × 0.90 × 0.50). Structural check
(`_evaluate_trpt_design_impl`): T_spoke = max(F_centripetal + F_exp − F_in_aero, 0),
FoS = SWL/T_spoke.
Drag torque (ODE only): τ = ρ·C_D·d·ω²·R⁴/8 per spoke. Hand-calc validated:
47.6 N·m/spoke at 260 rpm/R=2.66m → ~4 kW/ring → ~12 kW total. Spokes only on
rings with expansion rotors (Rod). `spoke=nothing` = current behavior.

## 2026-07-06: Spoke drag static parity gap (deferred)

Spoke drag applies in ODE path (ring_forces.jl →
multibody_ode! → run_canonical_sim!) but NOT in static equilibrium solver
(solve_equilibrium_self_consistent in objective_v6.jl). Static evaluations
(objective_v10, Phase 2 campaign re-eval) compute ω_eq without spoke drag.
Guard: objective_v10 errors if spoke is enabled (not @warn — prevents silent
divergence). Must be lifted before Phase 2 static campaign re-evaluation.

## 2026-07-06: Neutral radial loading design philosophy (Rod)

The spoke engagement
onset — the point where net radial load crosses zero and spokes begin to carry
tension — reframes from a diagnostic threshold into an operating target. "Neutral radial loading" as a
design objective: operate at small positive spoke tension — beams near-zero
compression, spokes in light standing tension, structure sized for cruise can
be genuinely light. Bias slightly outward (taut lines don't snap, sewn tabs
tolerate steady low tension far better than slack-taut cycling from gusts).
Target: small positive T_spoke with enough offset that site turbulence rarely
flips the sign — a percentile statement against the wind distribution.

**Ramp constraint:** the light structure is sized by the ramp, not the cruise.
At low ω (startup, shutdown, parked), centrifugal vanishes and beams see full
inward squeeze. Rings must survive the trajectory through (tension, ω) space
during spin-up/down — the soft-ramp controller and record_ramp_traces.jl
machinery exist to characterize this. If the ramp case dominates, the fly-light
mass saving shrinks — check this before betting a design on neutral operation.

**Cycle fatigue caveat:** low mean load reduces abrasion and creep, but cyclic
damage in stitching is driven by load range — turbulence sets the range
regardless of mean. The bias eliminates snap events (the big win), but tabs
still cycle. Tab life is a coupon-test question for the field kit, not
simulator-answerable.

**Action items (post-Gate 2):**
- ω_neutral tool: bisection on net radial load=0 per (design, wind, k)
- MPPT-vs-neutral overlay chart: gap between k_mppt operating line and neutral line
- New Gate 2 CSV columns: standing radial load (signed), sign-flip margin
  (gust/turbulence percentile at which sign flips)
- Candidate objective variant for next campaign: min mass subject to
  neutral-band operation across wind distribution, ramp transients as binding
  off-design case

## 2026-07-06: FoS gate decision (Rod)

Gate 2 hunts at spoke FoS ≥ 1.0 (SWL
already embeds deratings; gating at 1.5-on-SWL would double-margin). Rows with
FoS < 1.5 carry a caveat flag. Single number, single role.

## 2026-07-06: Gate 2 implications

Mach 0.85 ceiling is at 478-602 rpm — non-binding.
Spoke engagement (7mm Dyneema, SWL 19.8 kN, FoS-1.0 crossing well above
376 rpm for all designs) and spoke drag (~12 kW at 260 rpm, ω³) are the
real constraints. Gate 2 hunts constrained max-power with spoke FoS ≥ 1.0
(gate) and <1.5 (caveat flag). Spoke drag in power balance. Mach becomes
a verify-stage caveat.
Stability check (Tight t=57-59s transient) remains a separate bound.
Neutral radial loading (operate at small positive spoke tension) is a
candidate design target.
- FoS < 1 rows are infeasibility certificates, not data points. Report both
  unconstrained peak (diagnostic) and constrained optimum (FoS ≥ 1.5).

## 2026-07-06: V10 Tight dynamic instability at low k

The t=57-59s spike at k=6.23 is reproducible and is not an isolated artefact.
`scripts/diagnose_tight_transient.jl` tested three k values at 11 m/s:

| k | Stability | P range | Min FoS | n_fail |
|---|----------|---------|---------|--------|
| 3.0 | ✗ Unstable | 11.8% | 0.20 | 10 |
| 6.23 | ✗ Unstable | 20.4% | 0.42 | 5 |
| 12.94 | ✗ Unstable | 17.7% | 1.22 | 1 |

V10 Tight is dynamically unstable across the entire low-k range at 11 m/s.
The instability worsens as k decreases (higher ω). This is not a convergence
problem — it is a real dynamic instability. The stable operating k is above
some (unknown) boundary. Design cannot be optimised into the unstable regime.

V10 Reinforced at k=12.94: marginal (6.7% P range, n_fail=0). The FoS
oscillation (2.2→39→2.3) is the signature of net radial load passing through
zero — the spoke-engagement sign crossing — not a numerical artefact. FoS
blows up as inward load vanishes, snaps back as compression returns. Consistent
with dwelling at the engagement boundary — exactly the snap-cycling regime
the neutral-loading philosophy aims to avoid. The sign_flip_gust_ms column
will catch this in Gate 2.

λ=0.69 at k=3.0: stable (1.2% P range, 2 rpm ω range).

**Config:** `scripts/diagnose_tight_transient.jl` @ `3e713de`. Spokes: off
(default verifier). T_sim=60s (ControlMapHunt.T_VERIFY). Convergence: none
(last-slice, not windowed-mean — these runs pre-date the adaptive convergence
spec). Wind: 11 m/s (Tight), 15 m/s (Reinforced, λ=0.69). 1/7-power shear via
h_ref. Rotary lifter default. Caveat: spoke-off means no spoke drag; Gate 2
with spoke-on will shift ω via drag → stability classifications may move for
marginal rows. Accumulating case:
stable, flat peak (flatness 1.008), FoS 3.87, clean traces. Robust-to-k
plus dynamically calm — the profile for a field machine.

**Stability gate calibration:** measured separation — stable 1.2%, marginal
6.7%, unstable 11.8-20.4% windowed-P range. Gate at 4-5% splits cleanly
with margin on both sides. Basis: this table, these runs. (Note: runs used
spoke-off; Gate 2 runs spoke-on → drag shifts ω → marginal cases may shift.)

**CSV annotation:** Corrected Gate 1 CSVs carry tier-Y status: right geometry
(post-PRD-0006 fix), unverified convergence. k_refine CSVs carry the same
caveat. Delta doc regeneration waits for Gate 1 re-run with corrected selection
basis and convergence criterion.

## 2026-07-06: Centrifugal expansion blade loads added to structural evaluator

Expansion rotor blade centrifugal forces were absent from the FoS calculation.
`expansion_rotor_forces()` is pure aero; no ω² term. The structural evaluator
(`_evaluate_trpt_design_impl`) added blade mass only to the hub ring
(`i == n_rings_tot ? m_blade_per_vertex : 0.0`).

**Fix:** `expansion_blade_mass()` centralized in `src/expansion_rotor.jl`
(replaces 8 copy-pasted instances). `m_expansion_blade_per_ring` kwarg added
to the evaluator, plumbed through `evaluate_design()` in `ring_spacing.jl`.
`objective_v10.jl` builds the per-ring mass vector and passes it. The existing
`F_centripetal = m_vertex·ω²·r` machinery applies the force with correct
per-ring radius and sign — no double-counting with aerodynamic F_radial.

**Clamp caveat:** At high ω, centrifugal force can exceed inward aero load,
clamping `F_v` to 0 → FoS reads ∞ (no ring compression). Net outward load
passes into strut tension/bending and knuckle attachments — unmodeled. Designs
at the boundary carry an unverified structural margin. `@warn` log reports
each clamped ring with force magnitudes. **Superseded by spoke ties (2026-07-06
entry above):** spokes replace the clamp with a measured structural check;
the outward load path is now verified where spokes are enabled.

**Mass formula:** `(0.3 + 0.1·tip_radius)·blade_scale³` (kg, total per rotor
assembly). n_blades = n_lines (one blade per vertex, V10 convention).

**Tests (against evaluate_design, not full objective):**
- ω→0: F_centripetal→0, recovers pre-fix results bit-for-bit
- mass→0: expansion_blade_mass=0, recovers pre-fix results
- N_expansion=0: m_expansion_blade_per_ring=nothing, bit-identical

**Side effects:** Gate 7 penalty branches (objective_v10.jl:330,337) use
`sum(er.mass)` — now non-zero. Infeasible-design penalty values shift;
DE trajectories not byte-reproducible against old campaigns. Feasible results
unaffected.

## 2026-07-04: Settle k_mppt bug and five simulator-integrity findings; blade-scaling energy balance

### Settle k_mppt bug (integrity #1)

**Context:** `settle_to_operational_state` (`initialization.jl:738,747`) used
`p.k_mppt` (fixed params, V10 Tight = 614.9) to find equilibrium ω/τ, while the
simulation reads `sys.k_mppt_ref[]` (mutable, gate override = 15.6). The 39×
mismatch meant every settle initialised at a wrong low-ω state, and short sims
(≤10s) may not have converged to the true steady state.

**Fix:** Changed `:738` to `P_gen = sys.k_mppt_ref[] * w^3` and `:747` to
`τ_eq = sys.k_mppt_ref[] * ω_eq^2`. Gate retest: P shifted from 166–172 kW to
193 kW (+12–16%). All published V10 control-map and k-hunt numbers carry this
asterisk until re-run through the fixed settle.

### Integrity findings #2–5

1. **Gate drift (settle fix consequence):** Gate P shifted from 166–172 kW to
   193.2 kW at 221.7 rpm. The 2026-06-28 static/dynamic k_mppt mismatch (3.3×)
   may be partially this bug. Control maps under re-verification.

2. **Hardcoded `rotor_radius = 5.0` (severity: low for power, moderate for inertia):**
   Builder overrides `params_v5_50kw().rotor_radius = 11.18` with 5.0. The hub produces
   only 6 kW of 221.5 kW total aero at the gate (2.7%), sitting far off its cp peak
   at TSR≈10.5. Aerodynamically near-irrelevant for power — but the hub disk inertia
   term is still wrong, affecting transient dynamics.

3. **Builder–design pipeline mismatch:** `p_base.k_mppt = 614.9` (mass-scaled
   from 10 kW params, k ∝ P^2.5) vs empirical K₀ = 15.6 for V10 Tight (39×).
   `trpt_hub_radius = 2.988` at runtime ≠ `best_design.json.r_hub_m` (v5 design
   pipeline transforms the value en route). The builder constructs a system that
   differs from the recorded DE winner in at least three parameters (rotor_radius,
   k_mppt, trpt_hub_radius). "V10 Tight" in reports and "V10 Tight" in the
   simulator are different machines.

4. **Silent catch in `capture_extended` (`sim_frame.jl:439`):** Any exception in
   `expansion_rotor_forces` was caught and silently zeroed per-rotor aero/ground
   power. Fixed to `@warn` + `NaN` instead of `0.0` (zero is a plausible valid
   value; NaN signals "this measurement failed").

### Blade-only scaling energy balance (λ=0.54)

Tested post-design blade scaling of V10 Tight to 54% blade dimensions (fixed ring
geometry, r_mean-corrected k=2.3). Full ODE + static aero P(ω) sweep:

| | Gate (λ=1.0) | λ=0.54 |
|---|---|---|
| Expansion aero (static peak) | 253.2 kW @ 248 rpm | 73.5 kW @ 315 rpm |
| Ratio | — | **0.290 = λ²** |
| Expansion aero (ODE op point) | 215.5 kW | 48.1 kW |
| Hub aero (ODE) | 6.0 kW | 3.9 kW |
| Σ Aero (ODE) | 221.5 kW | 52.0 kW |
| Generator (k·ω³) | 193.8 kW | 23.6 kW |
| Transmission loss | 27.8 kW (13%) | 28.4 kW (55%) |
| Shaft efficiency | 87% | 45% |
| Max segment twist | 11.6° | 11.0° |
| Min FoS | 2.53 | 8.8 |

**Key findings:**
- Static aero model obeys λ² at peak power (confirmed at 0.290)
- **Transmission loss scales as ~ω³** (consistent with quadratic aerodynamic drag
  torque τ_d ∝ ω² on the rotating shaft). Coefficient c ≈ 2.2–2.5 W/(rad/s)³ is
  near-constant across λ=1.0 and λ=0.69 (design-independent shaft property).
  Knockout pair: Gate@11 (P_aero=222 kW, ω=23.1 rad/s, loss=28 kW) vs λ=0.69@15
  (P_aero=224 kW, ω=28.3 rad/s, loss=56 kW) — same aero power, 2× loss at higher ω.
  Loss fraction rises as blades shrink (13% → ~25%) because generator k falls with
  λ² while shaft drag does not. Notation: loss_frac ≈ c/(k+c). c is a shaft
  property; k fell with λ² — the shaft didn't get worse, the rotor got smaller.
  Low-wind additive term under investigation (c drifts from 2.5→4.8 W/(rad/s)³
  at 5 m/s, suggesting small constant-torque component at very low ω).
- **Damping sensitivity verified:** halving `lin_damp` (0.05→0.025) changes gate
  loss by only 1% (27.8→27.5 kW). The ~28 kW overhead is NOT a solver-stability
  artifact — it's structural/geometric. lin_damp=0.0 crashes the solver
  (stability floor exists), but the loss magnitude is robust to the lin_damp value.
  Other dissipation channels (line axial damping, back-line damper, solver tolerance)
  untested; mechanism attribution ongoing.
- Max segment twist is near-identical (11–12°) despite different loadings — the
  torque saturation mechanism is not twist-limited at these regimes.
- FoS margin is generous (8.8) — structural headroom exists for larger blades.

**Status:** Full-envelope verified. λ=0.69 with scaled m_blade: 62→168 kW at 11→15 m/s,
FoS 4.29→2.51. Low-wind P(v): 4.5/13.8/32.2/62.1 kW at 5/7/9/11 m/s, following v³
below rated. Blade mass saving: 19.0 kg (36.2→17.2 kg, λ² scaling). Corrected
airborne mass ≈ 30 kg vs V10 Tight 49.2 kg — feeds counter-analysis mass-scaling
table. The published V10 Tight failed at 15 m/s (FoS 1.36); blade right-sizing
improves high-wind structural margin.

**For counter-analysis:** "Blade-rescaled V10 Tight (λ=0.69) simultaneously meets
P≥50 kW and FoS≥1.5 across the full 5–15 m/s wind envelope. Static aero follows λ²
at peak (confirmed 0.290). Transmission loss scales as ~ω³ (quadratic shaft drag,
design-independent coefficient c ≈ 2.3 W/(rad/s)³), causing loss fraction to rise
from 13% to ~25% as blades shrink — not because the shaft degrades, but because
generator k falls with λ² while shaft drag does not. Constant-CL expansion rotor
model caveat applies pending cross-fidelity validation."

## 2026-07-01 (round 3): Dashboard v2 — per-rotor hub power fix, stacked dials in tall row, tension-colour match, N/Pcr relabel

**Context:** Rod reviewed the round-2 cockpit and asked: the hub dial showed
η=286% (aero efficiency >200%) — are the dial powers cumulative?; move the rotor
dials to stack vertically beside the bar charts (like the top-row bars); what is
`N/Pcr` in plain English; is "more torque at the bottom" of the torque chain
right; and should the tension-chain bar colours match the 3D viewport tether
line colours.

1. **Hub dial η>200% was a genuine bug — fixed at source.** The hub dial's
   "ground" power was `base.P_kw` (the TOTAL generator electrical, which reacts
   the hub rotor PLUS all expansion-rotor torques accumulated down the shaft),
   while its "aero" was the hub rotor alone → η = total/hub_aero can exceed 100%.
   Fix in `sim_frame.jl`: hub `rg = |tau_aero · omega_gnd| / 1000` — the hub
   rotor's OWN contribution referred to the ground shaft. Now every dial is a
   per-rotor contribution and the dials approximately SUM to `GEN ELEC kW`; no
   dial is cumulative. `rotor_ground_power` is consumed only by the dials/scripts
   (grepped), so changing its hub definition is safe for tests/core.

2. **Rotor dials moved into the TALL row (row 3, col 4), stacked vertically.**
   Rod: "stacked beside the bar charts top to bottom … like the rotors are."
   `rotor_gauges!(…; horizontal=false)` now lives at `fig[3,4]`; 3D viewport moved
   `fig[3,4:6]` → `fig[3,5:6]`. Row 2 headers gain `ROTOR POWER` (col 4), `3D
   VIEWPORT` → cols 5:6. Freed-up row-5 space: config now spans cols 2:3, event
   log cols 4:6 (rotor gauges no longer in row 5). Centre fonts scale with layout
   (`fs_kw` 24 horizontal / 18 stacked) so the kW readout fits the narrower dial.
   New `colsize!(fig.layout, 4, Relative(0.12))`; cols 1-3 12% each; 3D keeps 5:6.

3. **Tension-chain bar colours now use the same ramp as the 3D tethers.** Was a
   local green>10 / orange>5 / red<5 kN threshold; now
   `_tension_color(T_newtons, TETHER_SWL)` per segment (grey<5N slack, then
   blue→green→orange→red as T/SWL→1). A segment's bar colour matches its line
   colour in the viewport. Bars still plot kN; colour is computed on Newtons.

4. **`N/Pcr` relabelled `buckle util (N/Pcr)`.** It is axial compressive load N
   divided by the ring frame's critical Euler buckling load Pcr — a buckling
   utilisation (1.0 = at buckling; FoS = Pcr/N). Axis label + tooltip updated.

5. **Torque chain now shows REAL per-segment transmitted torque, not a linear
   interpolation.** Rod (correctly) flagged that drawing interpolated intermediate
   bars on a diagnostic panel is misleading — it looks like data but isn't. The
   old `torque_chain!` ramped linearly from |tau_gen| (ground) to |tau_aero| (hub)
   because "no per-ring torque array is exported." But the transmitted-torque law
   is already documented in `ring_forces.jl` (§torsional stiffness, Tulloch curve)
   and `capture_extended` already has its two real inputs. New
   `ExtendedSimFrame.segment_torque` (n_seg): for each rope segment,
   `τ_s = n_lines · T_s · r_s² · sin(Δα_s) / chord_s`,
   `chord_s = √(L_seg² + 2 r_s²(1 − cos Δα_s))`, evaluated on the ACTUAL per-segment
   line tension (`segment_tension`) and inter-ring twist (`segment_twist`) of the
   frame. This is byte-for-byte the same `τ_fn` used by `scripts/torque_diag.jl`
   (lines 31–35) — the codebase's own torque reference — except it uses the real
   `get_segment_tension` instead of torque_diag's idealized `EA·strain` estimate,
   so it's the more faithful of the two. It is the torque the twisted rope is
   physically carrying: it builds along the shaft with steps at driving rings and
   captures torsional dynamics, rather than a straight-line guess. `torque_chain!`
   is now per-segment (S1..Sn) to align with the tension chain beside it.
   Telemetry-only — does NOT feed back into the solver (physics conservatism, FR4
   unaffected). NB: `scripts/simframe_extension.jl` is a dead prototype whose
   struct has a stale `ring_torque` field (stored as zeros) and no longer matches
   `ExtendedSimFrame`; not include()d by the package. Gold-standard alternative if
   ever needed: call `compute_rope_forces!` in capture_extended and read its
   per-ring `torques_r` — but that's NET ring torque (≈0 in steady state), not the
   TRANSMITTED torque a chain diagram wants, and costs an extra force eval/frame.

## 2026-07-01 (round 2): Dashboard v2 — barplot binding bug, rotor dial sizing, tooltips, power-label clarity

**Context:** After the round-1 refinements rendered, Rod reviewed the running
cockpit and reported: the three tall bar charts (torque/ring/tension) were
visually empty on every design; rotor dials too small to read; config panel
over-spaced with content hidden under the play bar; and asked whether the
`POWER kW` KPI is generator electrical out and whether tooltips are possible.

1. **Root cause of "empty bars" was a barplot API misuse, not light load.** The
   panel handlers set `bars[1] = vals`, which reassigns the bar *positions* (the
   first plot argument), shoving every bar to an off-axis y-coordinate. Fix: bind
   bar lengths to an `Observable` created at plot time (`heights = Observable(...)`;
   `barplot!(ax, 1:n, heights; …)`) and update `heights[] = vals`; likewise a
   `colors` Observable for per-bar colour. Also removed the bogus `width=22/35`
   kwargs (absolute data-unit widths that would overlap bars into a blob) — barplot
   auto-width is correct. This makes all three charts fill and animate.

2. **`GEN ELEC kW` is the correct reading and is now labelled as such.** Verified
   `P_kw = tau_gen · |omega_gnd| / 1000` (sim_frame.jl:133) — generator reaction
   torque × ground-PTO speed = electrical output at the single ground generator.
   Renamed the cockpit KPI `POWER kW` → `GEN ELEC kW`. Expansion-rotor powers shown
   on their own dials are aero contributions to the same shaft, not separate
   generators, so the KPI is not summed.

3. **Rotor dials laid out horizontally in a wide 3-column cell.** `rotor_gauges!`
   gained a `horizontal` kwarg (places each dial at `gp[1,i]` instead of `gp[i,1]`);
   centre fontsizes bumped (kW 17→24, sub 7→10, label 10→13). In v2 the gauges moved
   from a single narrow column to `fig[5,4:6]`, so each dial is ~top-row-chart width.

4. **Floating tooltips via `DataInspector(fig)`.** Each bar panel sets a custom
   `inspector_label` (ring/segment id + value); other inspectable plots show default
   readouts. Answers Rod's "can we give floating tooltips" — yes, globally.

5. **De-compressed the secondary row.** Figure 1040→1180 tall, row 5 250→340;
   row 5 reflowed to twist(1) | config(2) | event log(3) | rotor gauges(4:6). Config
   menus narrowed 140→120 to fit the single column and stop content spilling under
   the control bar.

**Status:** written to `src/dashboard_panels.jl` + `src/dashboard_v2.jl`; NOT
compile-verified (sandbox 401 again). Rod runs `--v2 --v10-reinforced`.

## 2026-07-01: Dashboard v2 cockpit — layout, dynamic scaling, rotor readout, config interactivity, and V10 design selection

**Context:** The `--v2` cockpit (`src/dashboard_v2.jl` + `src/dashboard_panels.jl`)
first rendered successfully on 2026-07-01 (play/scrub, 3D viewport, and the
rotor gauge all live). Rod reviewed it at screen and asked for five concrete
changes. This entry records the decisions taken in response, plus a correction
about V10 design artifacts. Full session detail in
`handovers/handover-2026-07-01-dashboard-v2-refinements.md`.

### 1. Three tall diagnostic charts sit side-by-side, not stacked across rows

**Decision:** Torque chain, ring health, and tension chain are placed in a
single tall row beside each other (`fig[3,1]`, `fig[3,2]`, `fig[3,3]`), with the
3D viewport widened to `fig[3,4:6]`. The layout moved from a compressed 6-row ×
4-col grid to a 6-row × 6-col grid; the tall content row is `Auto` (takes all
leftover height, ~640 px), the secondary row is `Fixed(250)`, and the figure
grew from 1600×1000 to 1780×1040.

**Why:** Rod: "I'd like to see the three tall segment and ring elements all
charts beside each other because that would show easily a lot about how those
relate." Ring buckling, torque accumulation, and tension slack all propagate
*along the shaft* — placing the three per-position bar charts adjacently lets an
engineer read their relationship at a glance (e.g. high torque at the bottom
ring co-located with the lowest tension segment). Stacking them across separate
rows hid that relationship. The previous layout was also "really quite
compressed"; the bigger figure and full-width control bar address that.

### 2. Bar-chart x-axes autoscale to the current frame, not fixed limits

**Decision:** `ring_health!` and `tension_chain!` now autoscale their x-axis in
the frame handler (`xlims!(ax, 0, max(mx*1.25, floor))`) instead of using fixed
limits. Ring health dropped its `xlims!(ax, 0, 1.5)` + `clamp(ratio, 0, 1.5)`;
tension keeps the SWL line in view via `max(mx*1.15, swl*1.15)`. Torque chain
already autoscaled.

**Why:** On the lightly-loaded canonical design (ring util ~8%, FoS ~21) the
fixed-scale bars were near-invisible — Rod: "can we... scale it dynamically...
the ring health, the torque chain and the tension chain." Autoscaling makes the
bars readable at any load. Trade-off accepted: a fixed reference threshold (e.g.
the buckling line at N/Pcr = 1.0) is *not* pinned on-screen, because pinning it
would re-compress the bars under light load — the colour coding (green/orange/red
by FoS) carries the safety signal instead. Tension is the exception: its SWL
line stays visible because it is the operative limit for that panel.

### 3. Rotor gauge reads delivered power in kW, not efficiency percent

**Decision:** The rotor gauge centre shows delivered (ground) power in kW as the
big number, with an `aero X.X · η YY%` sub-line; the panel header states
`outer=aero · inner=out`. The outer cyan arc is aerodynamic power, the inner
green arc is delivered power (both scaled to `P_rated_kw / n_rotors`).

**Why:** Rod couldn't tell what the arcs meant or what power the rotor produced —
"it doesn't show what the power output of the rotor is, and I think the other
bit's percentage efficiency." Delivered kW is the number an operator cares about;
efficiency is secondary and demoted to the sub-line. Units confirmed: both
`rotor_aero_power` and `rotor_ground_power` are already kW in
`capture_extended` (`sim_frame.jl` — `Pa/1000`, `base.P_kw`).

### 4. Config panel uses real interactive Menu widgets; live rerun stays deferred

**Decision:** The config panel's four dropdowns (design / scenario / generator /
payout) are now real Makie `Menu` widgets, selectable at runtime.
`config_panel!` returns a NamedTuple of the menu handles so the caller wires each
`.selection` to the event log. The duplicate scenario menu that lived in the
control bar was removed. Selecting a menu logs "rerun pending" — it does **not**
yet re-run the simulation.

**Why:** Rod: "Not able yet to select any of the controls in the config." The
static `Label` placeholders looked interactive but weren't. Making them real
widgets closes that gap now; live scenario re-simulation via `build_rerun!`
(`sim_runner.jl`) remains deferred per the PRD (out of scope for v2 v1.0) — it
needs the runner/panel seam wired and is a larger change.

### 5. V10 "Reinforced" is the demo-worthy loaded design; a flag exposes it

**Decision:** Added `--v10-reinforced` to `scripts/interactive_dashboard.jl`,
which calls `build_v10_tight_no_lowest(r_bottom_scale=1.30, tether_diameter=0.004)`.
`build_v10_tight_no_lowest` gained those two kwargs (scaling design-vector
`x[2]` = r_bottom, and swapping the `MaterialSpec` tether diameter).

**Why:** Correction to a stale assumption — `scripts/results/v10_campaign_50kw/best_design.json`
**is present and valid** (an earlier note claimed it was absent; that was wrong),
so `--v2 --v10-tight` works today and renders the cockpit on a loaded design
(bars fill and colour, unlike canonical). But plain V10 Tight is **dynamically
dead (FoS = 0.43)** — it shows red/warning states and may diverge. The only
viable V10 is the reinforced variant (wider bottom ring + 4 mm tethers → ~55 kW
at FoS = 2.30), and the builder previously had no way to express it. The
kwargs + flag make the healthy loaded design a one-command demo:
`julia --project=. scripts/interactive_dashboard.jl --v2 --v10-reinforced`.
Note: the separate Tight campaign winner in `v10_campaign_50kw_tight/` is not
read — the builder path to `v10_campaign_50kw/` is hardcoded.

**Status:** All five changes are written but **not yet compiled** — the sandbox
was unauthenticated (401) this session, so Rod compiles/runs on his machine.
Watch for Makie issues on `Menu` `fontsize`/`width` kwargs, `Relative` column
sizing, the `lblkw...` NamedTuple splat in `config_panel!`, and the new builder
kwargs.

## 2026-06-30: The two-flank control problem — left-flank overspeed vs right-flank torque demand

**Context:** The dynamic k_mppt hunt (control-map bisection) consistently
finds the **left-flank** solution: low k (2–16), high ω (200–430 rpm),
power 3–4× rated (110–185 kW at 50 kW target).  The generator braking is
minimal — the rotor overspeeds until P = k·ω² crosses the target.  This
is structurally dangerous (high thrust → low ring FoS, V10 Tight FoS=1.36
at 15 m/s) but easy to reach dynamically (low torque, low twist, healthy
collapse margin 42–47°).

The P(k) curve is hump-shaped and P_rated crosses it at **two** points:

```
P ↑      ╱‾‾‾╲
  │     ╱     ╲
  │    ╱       ╲
  │───╱─────────╲─── P_rated
  │  ╱           ╲
  │ ╱             ╲
  └──────────────────→ k
   LEFT            RIGHT
   FLANK           FLANK
   low k, high ω   high k, low ω
   low torque      HIGH TORQUE
   high thrust     low thrust
   low twist       high twist
   FoS-limited     collapse-margin-limited
```

The **right-flank** solution would operate at higher k (more generator
braking), lower ω (less thrust → better FoS), with more twist (lower
collapse margin).  It trades the scarcer resource (FoS, currently 1.36
on V10 Tight) for the more abundant one (collapse margin, currently
42–47°).  This is the correct trade for a tensile transmission.

### Why the right flank may be dynamically unreachable

1. **Collapse margin soft-taper tension.**  At the right-flank k, steady-state
   collapse margin will be lower than the left flank's 42–47°.  If it drops
   below the controller's soft taper (e.g., 20°), the controller backs off
   BEFORE reaching the operating point:
   - Ramp k upward → twist accumulates → margin drops
   - Margin < 20° → controller reduces ramp rate (or reverses)
   - Twist unwinds → margin recovers → controller tries again
   - Result: oscillation around the soft-taper boundary, never settling

   Raising the soft taper to 20° (from 5°) INCREASES this risk — the
   controller becomes more conservative, potentially blocking access to
   the right flank entirely.

2. **Dynamic bounce.**  The TRPT is a distributed spring-damper chain.  k
   changes propagate as torsional waves.  A discrete k step causes overshoot
   in twist before settling.  The transient dip in collapse margin may cross
   the soft taper even if steady-state margin is above it.

3. **Generator torque demand.**  At the right flank, τ_gen = k·ω².  For the
   same 50 kW output, lower ω means higher torque:
   - Left flank (k=2, ω=400 rpm): τ ≈ 120 N·m
   - Right flank (k=500, ω=50 rpm): τ ≈ 1,250 N·m (10× higher)

   A direct-drive generator sized for low-torque, high-speed left-flank
   operation cannot deliver right-flank torque without a gearbox — which
   the TRPT's tensile architecture is designed to avoid.  Generator
   cooling is identical (50 kW dissipated either way), but the torque
   rating at low rpm is the limiting factor.

4. **Bisection may find a k that doesn't survive the transient.**  The
   hunt uses steady-state endpoint power.  A k that produces 50 kW at
   t=60s may cause the controller to back off at t=5s due to the twist
   transient, preventing the system from ever reaching that endpoint.

### What the control map proved

The 2026-06-30 control-map sweep (canonical 10 kW, V10 Tight, Reinforced
V10) confirmed:
- The left-flank solution exists at all operational winds for V10 Tight
  and Reinforced V10, producing 3–4× rated power with FoS as low as 1.36.
- The canonical 10 kW operates correctly on the left flank because its
  TRPT is massively over-designed relative to 10 kW (FoS ≥ 28).
- Collapse margin is healthy (42–47°) at the left-flank solution.
- The +30% bottom ring reinforcement improves FoS from 1.36 → 7.18 at
  15 m/s but does not fix the over-blading.
- The DE campaign's static solver completely failed to predict the dynamic
  power overshoot.

### What remains unknown

- **Does a right-flank k exist** that produces 50 kW with collapse margin
  above the soft taper (steady-state)?
- **Is that k dynamically reachable** — can the controller ramp there
  without the transient twist dip triggering the soft-taper guard?
- **Does the generator have the torque capacity** for right-flank operation
  at 50 kW?
- **If right-flank is unreachable**, the TRPT rings must be sized for
  left-flank overspeed thrust loads — a structural problem, not a
  control problem.

### Design implications

If right-flank operation is infeasible (torque limit, dynamic reachability),
the design path is:
1. Reduce blade scale (λ) until left-flank minimum power ≤ P_rated
2. Size rings for the thrust loads at that operating point
3. Accept that the controller operates on the left flank

If right-flank IS reachable:
1. The generator must be sized for high-torque, low-speed operation
2. The soft taper must be set below the steady-state right-flank collapse margin
3. The controller must navigate the twist transient without triggering the guard

**Status:** Active.  Right-flank search to be implemented in `scripts/hunt_kmppt_bisect.jl`.
Full analysis at `docs/reports/2026-06-30-control-map-findings.md`.
Control map data at `scripts/results/control_maps/`.

## 2026-06-30: Architectural decision — design for left-flank overspeed, the TRPT's natural operating regime

**Context:** The two-flank control problem (entry above) reveals that the TRPT
is fundamentally a **low-torque, high-speed** transmission.  Torque is carried
by twist in tensioned lines — the more torque, the more twist, the closer to
torsional collapse.  The TRPT naturally wants to run fast with low torque: the
left flank.

The right flank demands the opposite: high torque at low speed.  That's what
gearboxes and rigid shafts deliver.  A tensile shaft fights that regime — it
twists, bounces, and the controller backs off before reaching the operating
point due to the collapse margin soft-taper guard.

**What was decided:** Design the rotor to match the TRPT's natural operating
regime rather than forcing the TRPT into a high-torque regime it resists.
This means:

1. **Size blades so that the left-flank minimum power ≤ P_rated.**  As k → 0,
   the rotor overspeeds freely.  The minimum achievable power at k→0 is the
   design floor — if it exceeds P_rated, the turbine is over-bladed (the
   current V10 Tight produces 178 kW at k=2, 15 m/s).

2. **Size rings for left-flank thrust loads.**  At high ω, rotor thrust is
   high.  Ring buckling FoS is the binding constraint.  The +30% bottom-ring
   reinforcement (FoS 1.36 → 7.18) proves this is fixable — larger rings,
   cylindrical taper.

3. **Accept that the left flank IS the operating regime.**  k_mppt will be
   small (2–20), ω will be high (200–400 rpm at 50 kW).  The generator runs
   at high speed, low torque — a direct-drive generator's natural regime.
   No gearbox needed, no high-torque PTO.

4. **Collapse margin is NOT the binding constraint on the left flank** — it
   stays at 42–47° across all tested winds, well above any soft-taper
   threshold.  The controller never needs to intervene for twist.

5. **Right-flank operation remains a future option** if the generator can
   handle the torque and if structural changes (bigger rings, more lines)
   provide sufficient steady-state collapse margin above the soft taper.
   But it is not the baseline design path.

**Alternatives considered:**
- *Design for right-flank operation (high k, low ω):* Rejected as the baseline
  design path.  Requires high-torque generator (gearbox or oversized direct-drive),
  larger rings to increase collapse margin, and the controller must survive
  the twist transient without triggering the soft-taper guard.  Reserved as
  a future option if generator torque rating permits.
- *Split the difference, operate at peak P(k):* Rejected — the peak is
  structurally ambiguous (high thrust AND high twist) and is a knife-edge,
  not a stable operating point.

**Why this choice:** The TRPT's defining advantage is that it eliminates the
rigid shaft, gearbox, and tower of a conventional wind turbine.  Designing
for the left flank preserves this advantage — the generator runs at the
rotor's natural speed, torque stays low, and the transmission stays well
clear of torsional collapse.  The mass penalty (larger rings for thrust) is
the cost of this simplicity.  The current evidence (reinforced V10: FoS=7.18,
cm=42°, zero failing rings at 15 m/s) suggests this cost is acceptable.

**Consequences:**
- The DE campaign must search for blade scale (λ) values that bring left-flank
  minimum power to P_rated, not below it.
- The ring sizing constraint becomes thrust-driven (FoS ≥ 1.5 at max ω), not
  torsion-driven.
- The controller operates on the left flank exclusively — dP/dk sign detection
  must handle the left-flank regime (dP/dk > 0 → increase k to increase P).
- The generator is specified for low-torque, high-speed direct-drive operation.
- If right-flank operation is ever pursued, it is a separate generator and
  structural design exercise.

**Status:** Active.  This is the governing architectural decision for the
Phase 2 dynamic-aware DE campaign and all subsequent design work.

## 2026-06-30: Soft-kite rotors rejected for left-flank TRPT — higher Ct/Cp ratio penalises ring mass

**Context:** The left-flank architectural decision (above) establishes that the
TRPT operates in a low-torque, high-speed regime where ring buckling FoS from
aerodynamic thrust — not torsional collapse margin — is the binding constraint.
The question arose: would soft ram-air kites, with their lower mass and
potentially lower solidity, reduce ring compression compared to rigid NACA 4412
blades?

**Analysis:** The metric that matters is **Ct/Cp — thrust per unit power**.
A rotor producing 50 kW at lower thrust requires smaller, lighter rings:

```
Thrust = ½ρv²A·Ct    Power = ½ρv³A·Cp    →    Thrust/Power ∝ Ct/(v·Cp)
```

Measured and modelled values:

| Rotor type | CL | CD | L/D | TSR | Cp | Ct | **Ct/Cp** |
|------------|----|----|------|-----|------|------|-----------|
| NACA 4412 (BEM, KTD.jl) | 1.0 | 0.04 | 25 | 4.1 | 0.22 | **0.55** | **2.5** |
| Ram-air kite (INTA 2021) | 1.0 | 0.40 | 2.5 | ~2 | ~0.12 | **~1.0** | **~8.3** |
| Optimised ram-air (Thedens) | 1.2 | — | ~4 | ~3 | ~0.15 | **~1.2** | **~8.0** |

At the same CL, a ram-air kite produces **3.3× more thrust per unit power**
because:
1. Higher drag (CD=0.4 vs 0.04) means more lift force is "wasted" overcoming
   drag rather than producing torque.
2. Lower TSR (2–3 vs 4.1) means the rotor must be larger for the same power —
   larger swept area → proportionally more total thrust.
3. Even optimised ram-air designs (SkySails, Thedens 2024) only reach
   L/D ≈ 4, still 6× worse than a clean rigid wing.

**Blade mass is negligible.** At 50 kW scale, aerodynamic thrust (~25 kN for
a rigid rotor at 11 m/s) exceeds blade self-weight (~0.4 kN for 3 blades at
15 kg each) by 60:1.  The ram-air's mass advantage is irrelevant for ring
sizing.

**What was decided:** Rigid NACA 4412 blades (or equivalent clean airfoil)
are preferred for left-flank TRPT operation.  The design path is:

1. **Low solidity** — minimum number of blades needed to achieve rated power
   at design TSR.  Every extra blade adds thrust without adding proportionate
   power (Cp saturates with blade count faster than Ct accumulates).
2. **High TSR (4–6)** — maximises the ω term in P = τ·ω, minimising the τ
   (and therefore Ct) needed for a given power.
3. **Clean airfoil (high L/D)** — minimises the drag penalty that inflates
   Ct relative to Cp.
4. **Smaller swept area** — size blades so the left-flank minimum power
   (at k→0) equals P_rated, not exceeds it by 3×.

**Alternatives considered:**
- *Ram-air soft kites:* Rejected — 3.3× higher thrust per unit power
  translates directly to heavier rings and a heavier TRPT.  The mass saving
  on blades is negligible compared to the ring mass penalty from higher thrust.
- *Very high-TSR soft designs (TSR > 5):* Rejected — soft kite aerodynamics
  degrade at high TSR due to deformation, flutter, and structural compliance.
  Rigid blades are required for TSR > 4 operation.

**References:**
- Borobia-Moreno et al. (2021), "Identification of kite aerodynamic
  characteristics" — ram-air CL=1.0, CD=0.4 at typical AoA.
- Thedens & Oliveira (2019), "Ram-air kite airfoil and reinforcements
  optimization for AWE" — optimised designs push L/D toward 4 but no higher.
- KTD.jl BEM tables (`src/aerodynamics.jl`) — NACA 4412 Cp(TSR) and Ct(TSR)
  from AeroDyn v15.

**Status:** Active.  This decision reinforces the left-flank architectural
choice: rigid blades, high TSR, low solidity.  The DE campaign's blade scale
parameter (λ) controls swept area — and should be driven downward until
left-flank power at k→0 matches P_rated.

## 2026-06-30: Acoustic constraint — left-flank tip speeds require altitude and siting strategy

**Context:** Left-flank operation at 50 kW produces high rotor speeds (150–200 rpm
at R≈5–8 m) and correspondingly high tip speeds.  Measured tip speeds from the
current (over-bladed) V10 design at R≈5 m:

| Wind | V10 Tight | Reinforced V10 | Canonical 10 kW |
|------|-----------|----------------|-----------------|
| 11 m/s | 115 m/s | 107 m/s | **66 m/s** |
| 13 m/s | 188 m/s | 152 m/s | 90 m/s |
| 15 m/s | 224 m/s | 197 m/s | 104 m/s |

Industry references:
- Commercial wind turbine: 70–80 m/s (noise-limited in most jurisdictions)
- Urban / noise-sensitive: 50–60 m/s
- Helicopter rotor: 200–220 m/s (militarily acceptable, not residential)

At 50 kW with properly sized blades (not the current 3× over-bladed design),
tip speeds scale approximately as √(P_rated/P_ref) × tip_ref.  From the
canonical 10 kW baseline (66 m/s at 11 m/s): a 50 kW system at the same
solidity reaches ~148 m/s — well above commercial wind turbine norms.

**Mitigating factors:**

1. **Altitude (Oliver Tulloch PhD, 2024).**  The PhD thesis identified an
   optimal kite turbine operating altitude >100 m.  At 100 m hub height vs a
   conventional 80 m tower, the ground-level noise attenuation is comparable
   (~20 dB additional loss from 80→100 m).  More significantly, the TRPT
   has **no tower** — eliminating tower-shadow thump (the dominant low-frequency
   noise source in conventional turbines).

2. **Line drag noise.**  At 100 m+ tether lengths, vortex shedding from the
   cylindrical Dyneema lines produces broadband aerodynamic noise.  This is
   an additional noise source not present in conventional turbines.  The
   line count (n_lines) and diameter affect both the TRPT mass and the
   acoustic signature — a trade that the DE campaign does not currently model.

3. **No tower thump.**  Tower shadow — the blade passing through the tower's
   wind deficit once per revolution — is the dominant low-frequency annoyance
   from conventional turbines.  The TRPT has no tower, so this source is
   eliminated entirely.  The remaining noise is pure aerodynamic (blade
   self-noise + trailing edge) which is higher-frequency and attenuates
   faster with distance.

4. **Siting strategy.**  The TRPT's deployment advantages (no foundation, no
   crane, rapid install) enable siting further from residences — offshore,
   remote ridges, industrial zones — where noise constraints are relaxed.

**What was decided (design constraint, not yet implemented):**

1. **Maximum tip speed target: 120 m/s at rated wind.**  This is ~1.5× the
   commercial norm but justified by the absence of tower thump and the
   altitude advantage.  The DE campaign must enforce tip_speed ≤ 120 m/s as
   a design constraint on the (R, ω) combination.
2. **Altitude ≥ 80 m** (Oliver's optimisation) for noise-sensitive sites.
   Below 80 m, the ground-level noise from a 120 m/s tip may exceed
   regulatory limits in residential areas.
3. **Line count as an acoustic variable.**  n_lines affects both structural
   mass and vortex-shedding noise.  Lower n_lines = less line noise, but
   higher per-line tension → heavier rings.  The trade is currently
   unmodelled and deferred.
4. **Buyer acceptability.**  A turbine that sounds like a helicopter at
   close range will not sell, regardless of technical merit.  Noise is a
   market constraint, not just an engineering one.

**Alternatives considered:**
- *Accept higher tip speeds (150+ m/s) and rely on siting:* Rejected —
  eliminates residential and near-urban markets.  The TRPT's deployment
  flexibility is its commercial advantage; sacrificing it to avoid a
  rotor-sizing problem is self-defeating.
- *Reduce power rating to keep tip speeds low:* Rejected — 10 kW is quiet
  but commercially unviable.  50 kW is the minimum economically interesting
  scale.
- *Right-flank operation (low ω, high k):* Already analysed as structurally
  challenging (collapse margin, generator torque).  Would solve the noise
  problem but creates others.

**Status:** Active design constraint.  To be encoded as `tip_speed_max` in
the DE campaign objective function.  Acoustic modelling (blade self-noise,
line vortex shedding) deferred to a separate study.

## 2026-06-30: Motor-driven detwist — deferred feature, requires careful implementation design

**Context:** While re-reading Tulloch's PhD thesis (Final Submission), a finding on
pp. 229–230 (Figures 5.44–5.45) was noted: for the Daisy Kite rotor coupled with
TRPT-4, the net torque coefficient Cq crosses zero at **two TSR values** — 1.2 and
5.3. The rotor in isolation doesn't cross zero until TSR > 6. The multiplicity arises
from the **rotor + TRPT combination**, not from the rotor alone. With the optimised
rotor (Section 5.3.2), only one equilibrium emerges — the phenomenon is
design-dependent and some configurations may exhibit 3 crossings.

**Field validation:** During the experimental campaign, "it was necessary to drive
the system using the generator as a motor to reach higher angular velocities" — the
low-speed equilibrium trapped the system, requiring motor boost to escape. This
occurred primarily in light winds.

**What was decided (recorded, not actioned yet):**

1. This is a **third mechanism** contributing to the static-vs-dynamic power gap (in
   addition to distributed torsional stiffness and sequential torque propagation):
   the static equilibrium solver may converge to the *wrong* equilibrium — a low-speed,
   low-power solution — and report the design as viable.
2. The k_mppt bisection hunt assumes monotonic P(k). Multiple equilibria mean P(k)
   may be non-monotonic; the bisection could land on the wrong branch.
3. Tulloch's field experience validates that **motor-driven boot through low-speed
   equilibria** (already recorded as a deferred Phase 3–4 feature in the decision
   above) is a real operational requirement, not a theoretical edge case.
4. The "light winds" condition where the trap occurred matches our controller's
   IDLE→RAMPING transition challenge: the controller may misclassify a low-speed
   equilibrium as "spinning up" and ramp incorrectly.

**Status:** Recorded as Issue [#6](https://github.com/rodWindswept/KiteTurbineDynamics.jl/issues/6).
Action items: check whether V10 Tight exhibits multiple Cq=0 crossings; verify
bisection robustness; reference in Porto paper § power gap discussion.

## 2026-06-30: Motor-driven detwist — deferred feature, requires careful implementation design

**Context:** In field operation of the TRPT prototype, the PTO generator was
capable of forward-driving as a motor — injecting torque into the TRPT from
the ground end to help start the rotor or reduce accumulated twist.  The
current simulation models the PTO as a passive MPPT load only (`τ_gen = k·ω²`).
Adding motor-driven detwist would provide a dynamic, closed-loop mechanism to
avoid torsional collapse: when the controller detects an approaching overtwist
(margin to δα* dropping below a threshold), switch from generator to motor,
drive forward to unwind the accumulated twist, then resume power extraction.

Collapse margin (`δα* − |Δα|`) is the natural trigger metric: monotonic,
physically meaningful, and directly measurable in the field via top-rotor IMU
α position and distance-derived twist inference.  Unlike Euler buckling FoS,
collapse margin is observable from flight instrumentation alone — no structural
model required.

**What was decided (deferral):** Motor-driven detwist is deferred as a
Phase 3–4 feature.  The current Phase 1–2 scope (bisection hunt, dynamic-aware
DE campaign) must complete first to establish the viable design space.
Implementation will require:

1. **Trigger thresholds** — at what collapse margin does the controller switch
   from generator to motor?  Soft taper 20°→5° (ramp rate linearly reduced),
   hard motor engagement at 5°?  How to avoid oscillation (hysteresis band)?
2. **Motor torque profile** — how much torque to apply?  Fixed k_drive, or
   proportional to twist error?  Power budget: motor energy consumption vs
   recovered energy on return to MPPT.
3. **Rotor overspeed during unwind** — with generator load removed, the rotor
   accelerates.  Motor torque partially compensates, but the net loss of
   braking may cause overspeed — thrust-driven ring buckling or tether
   over-tension before twist is relieved.
4. **Torsional wave dynamics** — motor torque injected at the ground ring must
   propagate upward through the same spring-damper chain.  The wave travel time
   and reflection behaviour (impedance mismatch at rotor end) determine whether
   detwist is faster than the collapse progression.
5. **State machine integration** — the controller already has IDLE → RAMPING →
   HOLDING states.  Adding MOTOR (or DETWIST) requires defining entry/exit
   conditions, interaction with the FoS taper, and whether HOLDING can
   transition directly to MOTOR or must go through RAMPING.

**Field relevance:** The 10 kW field prototype demonstrated forward-drive
capability.  At the 50 kW scale, the TRPT's longer shaft and higher accumulated
torque make the collapse margin tighter — detwist becomes a safety-critical
control function, not just a startup convenience.

**Status:** Deferred.  Recorded for future planning.  The collapse margin
infrastructure (`min_collapse_margin()`, `RampController._δα_star`) and the
mutable k_mppt reference (`sys.k_mppt_ref[]`) are already in place —
implementation is a controller logic change, not a physics model change.

## 2026-06-26: Dashboard config addition requires three-string sync across two files

**Situation.** Adding a new CLI flag (`--v10-tight`) to the GLMakie dashboard
failed 8 times — GeometrySpec, ExpansionRotorParams, imports, and menu mismatch
errors cascaded through the Julia precompile cycle, each requiring a full round-trip.

**Decision.** Documented the three-string synchronization requirement as a dev
skill (`ktd-dashboard-config`). When adding a config: (1) CLI flag,
(2) builder's return label, and (3) Menu(options=[...]) list must agree
character-for-character. The `current_config` local variable must be overwritten
with the builder's `label` return value before passing to `build_dashboard()`.

**Rationale.** This is a structural coupling enforced by Makie's `Menu` widget
which checks the default option against the options list at initialization time.
There is no single source of truth — the three strings live in different lexical
scopes and can drift silently until runtime.

**What it enables.** New contributors can add dashboard configs in ~5 minutes
following the checklist rather than ~45 minutes of fix-push-retry cycles.

**Status.** Active. The skill is at `~/.hermes/skills/ktd-dashboard-config/`.

## 2026-06-27: Soft-ramp k_mppt controller — architecture, constraints, and control philosophy

**Context:** The V10 Tight winner (49.2 kg, 4 rotors) is dynamically underpowered: the
static equilibrium solver predicts 59 rpm / 50 kW at k_mppt_eff=166, but the multibody
ODE reaches only 55.6 rpm / 12.1 kW at k_mppt=62. The static solver assumes instant,
lossless torque propagation through the TRPT, but torque propagates sequentially through
each ring pair's torsional spring-damper chain (k_sec, c_s). A manual k_mppt slider
in the dashboard requires the operator to hunt for the sweet spot — fragile and
unrepeatable.

The original plan (`docs/plans/2026-06-26-soft-ramp-kmppt.md`) proposed a PID controller
with state machine and slack-line detection. A detailed review on 2026-06-27 revised
six aspects based on TRPT physics and Tulloch's torsional collapse analysis.

**What was decided:**

### 1. Slack lines dropped as control signal

The original plan proposed "react to slack within 1–2 ODE steps." Polygon ring
redistribution handles local slack naturally — the tension-only spring law
`T = max(0, EA·strain + c·damp·rate)` already models the correct physics. 1–2 slack
lines between a ring pair is a symptom of geometry settling after a load change,
not a failure trigger. The rings redistribute and the slack resolves. Slack is
NOT used as a controller input.

### 2. k_mppt made mutable via Ref{Float64}

Currently `p.k_mppt` lives in the immutable `SystemParams` struct. A `Ref{Float64}`
added to `KiteTurbineSystem` provides a single pointer dereference — one memory load
per generator torque evaluation. The ODE already uses this pattern for
`sys.brake_engaged[]`. Rope force computations (hundreds of `norm()`, `sqrt()`,
spring-damper evals per step) dominate runtime by 3–4 orders of magnitude. The
overhead is unmeasurable.

### 3. Halving k_mppt on FoS violation would cause overspeed

The original plan proposed PROTECT state: "FoS < 1.5 → aggressive k_mppt reduction."
If FoS drops during a gust, halving k_mppt → generator pulls less torque → rotor
accelerates → more aero torque → more structural load. This is a positive feedback
loop toward overspeed. The correct action is to **hold or reduce ramp rate**, not
release the generator load. The generator is the only brake the TRPT has.

### 4. FoS soft intervention at 2.5, hard floor at 1.5

A hard freeze at FoS = 1.5 creates a control discontinuity that could excite the
TRPT's torsional modes (underdamped locally, ζ=1.0 at ring-pair level, but global
mode coupling means a sharp k_mppt change can ring). A linear taper from FoS = 2.5
(full ramp rate) to FoS = 1.5 (zero ramp rate) gives a smooth approach to the
structural limit:

```
ramp_rate = nominal_rate × clamp((FoS − 1.5) / (2.5 − 1.5), 0.0, 1.0)
```

This is the "slow the shocks" approach — the controller begins reducing its
aggression well before the structural limit, avoiding the discontinuity.

### 5. State machine with proportional ramp, not PID

The TRPT is a distributed nonlinear spring-damper chain. Torsional stiffness k_sec
varies with twist angle (geometric hardening, then collapse). A single PID tuned
at one operating point would be suboptimal elsewhere. A state machine (IDLE →
RAMPING → HOLDING) with proportional ramp rate `Δk = Kp × (P_target − P_actual)`
is simpler, more robust, and easier to tune. The P term provides the basic feedback;
the ramp itself provides integral action. No derivative term (power is noisy at
ODE timescales). Anti-windup via k_mppt clamping to [k_min, k_max].

PID autotuning (relay feedback, Åström-Hägglund) is reserved as a future option
if the state machine proves insufficient.

### 6. Margin to torsional collapse (Tulloch δα*) as the constraint metric

Tulloch's τ(δα) curve is non-monotonic: k_sec = dτ/dδα starts low, rises (geometric
hardening), peaks, then goes to zero at δα* = 2·arcsin(L/√(2(L²+2r²))), then goes
negative (the collapse cliff). The segment nearest its δα* is the limiting one.
Its k_sec will be the *highest* (closest to the peak), which is misleading — it's
about to fall off the cliff.

The controller tracks `margin_i = δα*_i − |Δα_i|` per segment. `min(margin_i)` is
the constraint — a direct, monotonic measure of distance to the Tulloch cliff.
If any segment's margin drops below 5°, the ramp rate is frozen regardless of FoS.
This is a novel constraint metric: twist-angle margin to collapse, computed
analytically per segment from ring geometry (no additional simulation cost).

### 7. Data recording for paper

Both old (instant k_mppt step) and new (soft-ramp) systems will be recorded
headless at 0.5 s intervals, capturing: k_mppt, P_gen, ω_hub, ω_gnd, Δω,
min(FoS), min(margin_to_δα*), total twist, peak tether tension. Three scenarios:
canonical 10 kW at rated wind, V10 Tight 50 kW at rated wind, and 7→14 m/s
wind ramp. The comparison will form a paper section on "Dynamic MPPT Control
of TRPT Kite Turbines."

**Alternatives considered:**
- *Use slack as a control input:* Rejected — polygon ring redistribution handles
  local slack. Using it as a trigger would cause false-positive interventions
  during normal geometry settling.
- *Keep k_mppt in immutable SystemParams, rebuild params on change:* Rejected —
  would require reconstructing the entire params struct at frame rate, and
  risks stale references in flight.
- *Halve k_mppt on FoS violation:* Rejected — positive feedback toward overspeed.
- *Hard freeze at FoS = 1.5:* Rejected — control discontinuity excites torsional
  modes.
- *Full PID controller:* Deferred — state machine with P-only ramp is the safer
  starting point for a nonlinear plant.
- *Track k_sec as constraint:* Rejected — k_sec peaks near collapse, making it
  misleading. Margin to δα* is monotonic and physically meaningful.

**Status:** Active. Full plan at `docs/plans/2026-06-27-soft-ramp-kmppt-v2.md`.
Phase A (mutable k_mppt) ready to execute.

---

## 2026-06-26: CoaxialAutogyroStacking documented as required dependency

**Situation.** New users cloning KTD.jl hit `Package CoaxialAutogyroStacking not
installed` because it's an unregistered development dependency providing the
PCA-2 autogyro lift device model (`src/lift_kite.jl`).

**Decision.** Updated README install instructions to clone both repos and use
`Pkg.develop()`. Added note explaining the dependency is unregistered —
`Pkg.add()` won't find it.

**Status.** Active.

Each entry explains the situation, what was decided, what alternatives were on the table, why
this choice was made, what it enables and rules out, and whether it is still active.

The purpose of this file is to make the reasoning behind the simulator transparent — so anyone
reading the code can understand not just *what* was done but *why*, and so future contributors
can assess whether a decision still holds when circumstances change.

---

## [2026-06-25] Bank angle bound tightened 35° → 25° for pitch depower blade-tip clearance

**Context:** During pitch depower, the shaft elevates to ~65° from horizontal to spill
wind. At the top of the shaft rotation circuit (12 o'clock position), a blade extending
radially from a ring points upward at (90° − θ) from horizontal where θ is shaft elevation.
The blade tip is banked downward by bank_angle from the ring plane. For the tip to stay
above the root's horizontal plane:

```
tip_elevation = 90° − θ − bank_angle ≥ 0  →  bank_angle ≤ 90° − θ
```

| Shaft elevation θ | Max safe bank |
|---|---|
| 30° (normal operation) | 60° |
| 65° (pitch depower) | **25°** |

At 65° shaft tilt, any blade banked steeper than 25° has its tip below the root horizontal
at top-of-circuit. A blade tip below horizontal at this point in the rotation means the
apparent wind hits the top face of the blade (back-wind), reversing the lift direction.
Since the tether bridling supports the blade in tension for underside loading only, back-wind
stresses the blade root and ring fitting in ways the structure is not designed for.

**Previous bound:** 35° (set as a DE search bound in V6.2 after reducing from 45° in
earlier versions). The 35° limit was adequate for normal operation but fails the pitch
depower geometric constraint by 10°.

**Choice made:** Tighten bank_angle upper bound from 35° → 25° in all DE search bounds
(V6 and V10). This is a geometric constraint derived from the pitch depower shaft angle,
not an aerodynamic or structural limit — it ensures the blade physically cannot back-wind
regardless of bridling configuration.

**Alternatives considered:** 
- Keep 35° and rely on bridling incidence to prevent back-wind: rejected because bridling
  cannot fix a geometric inversion where the tip sits below the root.
- Compute a dynamic limit from φ_inflow during gusts: deferred as the geometric constraint
  is tighter and simpler to enforce.

**Consequences:**
- Reduces the DE's F_radial per unit blade lift (shallower bank = more F_axial, less F_radial)
- May increase the optimal ring beam mass since less radial spreading → less tension stiffening
- V10 tight winner at bank_bottom=35° becomes infeasible; campaign must be re-run
- The true feasible bank angle may be even lower if bridling incidence is explicitly modeled
  (deferred to a future incidence/AoA model)

**Status:** Active. Pending code change in search_bounds_v6, search_bounds_v10,
design_from_vector_v6, design_from_vector_v10.

---

## [2026-06-28] Confirmed: Static equilibrium solver cannot design a viable TRPT — two independent lines of evidence

**Summary:** Two independent investigations on 2026-06-28 converge on the same conclusion:
the DE campaign's static equilibrium objective function is fundamentally mismatched to the
distributed torsional dynamics of the TRPT.  The optimiser cannot find a viable design because
it evaluates the wrong physics.

### Line 1: V10 Tight dynamic testing (k_mppt hunt + 60s traces)

The original V10 Tight (49.2 kg, k=62) overspeeds to 132 kW (2.6× rated) with FoS=0.43 —
too much blade for the structure.  A 12-point k_mppt hunt (50→600) found the value that
produces 50 kW: **k≈550**.  But at this point FoS=0.75 — the structure buckles progressively
over 60 seconds, power decays from 49→21 kW as rings collapse.

| k_mppt | P_gen | ω_hub | min FoS | Outcome |
|---|---|---|---|---|
| 62 (original) | 132 kW | 123 rpm | 0.43 | Instant overspeed, structural failure |
| 550 (tuned) | 49→21 kW | 52→32 rpm | 0.75→0.26 | Progressive buckling, power decays |

The FoS crosses below the 1.5 hard floor at k≈350, well before the 50 kW target at k≈550.
**No k_mppt value simultaneously satisfies P ≥ 50 kW AND FoS ≥ 1.5.**

### Line 2: Conservative DE campaign (launched independently)

A fresh V10 campaign with tightened constraints produced a 60.8 kg design.  Post-campaign
dynamic verification found the best achievable power was **8.6 kW (17% of rated)** at k=62 —
the design is "dynamically dead."  The static solver steered the optimiser toward a geometry
that looks correct in equilibrium but cannot transmit torque through the TRPT.

| Campaign | Best mass | Dynamic P at best k | Rating |
|---|---|---|---|
| Original V10 Tight | 49.2 kg | 132 kW (k=62) → FoS fails | Over-bladed |
| Conservative V10 | 60.8 kg | 8.6 kW (k=62) | Under-torqued |
| **Neither produces 50 kW with FoS ≥ 1.5** | | | |

### Root cause

The DE objective function evaluates designs using `settle_to_equilibrium()` which:
1. Assumes instant, lossless torque propagation through the TRPT
2. Computes ω_eq by balancing P_aero = P_gen at a single operating point
3. Ignores the distributed torsional spring-damper chain that governs real torque transmission

In the dynamic multibody model, torque propagates sequentially through each ring pair's
torsional stiffness.  The generator only "sees" rotor torque after the torsional wave
travels the full shaft length.  This means:
- The **k_mppt needed dynamically is 3–4× higher** than the static solver predicts
- The **torsional loads are correspondingly higher**
- The **ring radii and tether diameters optimised for static loads are insufficient**

### Required fix: Dynamic-aware objective function

The DE campaign must evaluate candidates using the dynamic simulation, not the static
equilibrium solver.  Proposed two-level objective:

```
For each candidate design vector x:
  1. Build system: sys, u0, p = build_from_vector(x)
  2. Hunt k_mppt:  sweep k ∈ [20, 800] in 5s dynamic sims
     → find k* that minimises |P_gen − P_rated|
  3. Verify at k*: run 60s dynamic sim
     → extract min FoS, P_final, ω_final
  4. Score:
     if min FoS < 1.5:  penalty = 1e6 × (1.5 − min FoS)
     else:              score = mass + λ × |P_final − P_rated|/P_rated
```

Computational cost: ~12 hunt points × 5s + 1 verify × 60s ≈ 120s per candidate.
For a 60-island × 80-population campaign: ~160 hours on 32 threads.
Practical: run a smaller campaign (20 islands, 40 pop) first to validate, ~27 hours.

### Structural redesign estimate

To close the gap between the safe region (k≤350, FoS≥1.5) and the power target (k≈550):
- Ring radii: +40% (FoS ∝ r², need 2× FoS → √2 ≈ 1.4×)
- Tether lines: 3→5 (1.67× load distribution)
- Combined FoS improvement: 1.4² × 1.67 ≈ 3.3×
- Mass estimate: 70–80 kg (vs current 49.2 kg)

### Jamieson scaling law for multi-rotor mass

Peter Jamieson's analysis (personal communication) shows that splitting a single rotor
of radius R into N stacked rotors of radii R₁, R₂, ..., R_N such that total swept area
is preserved (ΣR_i² = R²) gives a mass ratio:

```
M(k) = (1 + k³ + k⁶) / (1 + k² + k⁴)^(3/2)    [for N=3, geometric progression R_{i+1} = k·R_i]
```

For equal-sized rotors (k=1): M = 3 / 3^(3/2) = 0.577 → **42% mass saving**.
As k → 0 (rotors become very unequal), M → 1.0 (no saving — dead mass).
For k < ~0.5, the saving drops below 20% and the optimisation should question whether
the smallest rotor justifies its mass.

This explains the V10 Tight configuration: the lowest expansion rotor was removed by
design specification (minimum ground clearance constraint), not by the optimiser.
The three remaining rotors are the ones that physically fit; they should be as equal
as possible to maximise the Jamieson mass saving.

**Implication for the dynamic-aware campaign:** No explicit Jamieson penalty is needed —
the mass objective naturally penalises unequal rotors because a very small rotor adds mass
without contributing proportional power (P ∝ R², m ∝ R³).  The optimiser will discover
equal rotor sizing as an emergent property of the physics.  The Jamieson analysis explains
*why* this convergence occurs and gives us the theoretical upper bound: 42% mass saving
for perfectly equal rotors vs a single equivalent rotor.

### Brake fix (2026-06-28)

The auto-brake previously engaged whenever ω_hub < 1.0 rad/s (~9.5 rpm).  Removed from
`src/ring_forces.jl` — brake now only engages on explicit command (depower sequence).

### Controller improvements (2026-06-28)

- **Slider range:** V10 k_mppt slider extended 10→600 (was 10→200)
- **Auto-ramp k_min/k_max:** centred on slider setpoint ±80% range, not hardcoded
- **Slider animation:** live-tracks `sys.k_mppt_ref[]` during auto-ramp simulation
- **Idle hold time:** reduced from 3.0s to 0.5s for faster controller engagement

### Figures generated

9 publication-quality figures in `scripts/results/ramp_traces/figures/`:
1. Canonical dashboard (6-panel full-state)
2. V10 Tight dashboard (with failure annotations)
3. Wind ramp triptych (trajectory + structural + torsional)
4. Structural envelope (4-panel operating map)
5. Frequency domain (torsional PSD, Welch method)
6. Controller diagnostic (state machine Gantt chart)
7. Cross-system comparison (bar chart)
8. V10 Tight: Original vs Tuned comparison
9. k_mppt hunt sweep (power + FoS vs k)

### Additional fixes applied (2026-06-29)

- **Expansion rotor power in equilibrium scan** (`src/initialization.jl:715`):
  `settle_to_operational_state` now includes expansion rotor aerodynamic power in the
  ω equilibrium scan.  Previously only the hub rotor counted, causing V10 Tight to
  fall back to ω_eq=9.5 rad/s regardless of actual blade count.

- **Kite position lag in settle loop** (`src/initialization.jl:875`): `update_kite_pos!`
  called during the 150,000-step operational settle so the lift line doesn't snap at frame 1.

- **HOLDING no longer blocked by structural margin** (`src/soft_ramp_controller.jl:250`):
  Removed `struct_mult ≥ 0.99` condition.  Structural guards still limit ramp rate.

- **dP/dk sign detection** (`src/soft_ramp_controller.jl:245`): Controller detects whether
  it's on the left flank (dP/dk > 0) or right flank (dP/dk < 0) and adjusts direction.
  Uses accumulated thresholds to detect small per-frame changes.

- **Controller init after settle** (`src/visualization.jl:854`): `init_geometry!` now sees
  the settled ring positions instead of raw `u0`.

- **Warm start: skip IDLE** (`src/visualization.jl:867`): If the settled rotor is already
  spinning above `ω_idle`, the controller starts in RAMPING, not IDLE.

- **Dashboard panelised** (`src/visualization.jl:1516`): Controls reorganised into
  Generator Control, Structural Guards, System, and Depower panels with colour-coded headers.

- **Kp slider** (`src/visualization.jl:1554`): User-adjustable ramp gain, log scale
  1e-6 → 1e-2 (60 steps), replaces auto-computed gain.

- **Tulloch collapse margin slider** (`src/visualization.jl:1589`): Threshold adjustable
  1°–15°, was hardcoded at 5°.

- **Live k_mppt numeric display** (`src/visualization.jl:1044`): Value label updates
  alongside slider animation.

- **Rotor count label** (`scripts/builders_util.jl`, `scripts/interactive_dashboard.jl`):
  Changed from "3 rotors" to "hub + 3 expansion rotors".

---

## [2026-06-29] Reinforced V10: larger bottom rings + 4mm tethers produce a viable design

### Per-ring FoS sweep confirms bottom bottleneck

3 k_mppt values (62, 200, 550), 60s each, with per-ring ring_element_analysis:
**ring 1 (lowest airborne ring) is ALWAYS the limiting ring** at every operating point.
The bottom ~13 rings (out of 22) fail (FoS < 1.5).  The taper goes from 1.33m (ground)
to 1.58m (kite) — the rings get SMALLER as torsional load ACCUMULATES downward.
This taper direction is structurally backwards for a torque-carrying shaft.

### Reinforced V10 test

Using `build_kite_turbine_system_v5` (ring_spacing_v4 geometry matching the design)
with `r_bottom_scale=1.30` and 4mm tethers:

| Scale | r_bottom | r_top | P at k=200 | min FoS | Rings failing |
|---|---|---|---|---|---|
| 1.0 (original) | 1.33m | 1.58m | 44 kW | 0.29 | 13/22 |
| 1.3 | 2.99m | 2.99m | 55 kW | **2.30** | **0/20** |

The +30% scale (via ring_spacing_v4) produces a cylindrical 3m TRPT.  4mm tethers
alone made no difference — ring buckling, not line tension, is the limiting factor.

### Builder disconnect discovered

The V10 Tight builder uses `build_kite_turbine_system` (linear taper) for the ODE
system geometry, but the design uses `ring_spacing_v4` (non-uniform spacing) for
structural evaluation.  The design radii (~3m) and system radii (~1.33m) differ by
over 2× — the system is built with much smaller rings than the design assumes.
`build_kite_turbine_system_v5` uses ring_spacing_v4 and matches the design geometry.

### Next: Control-first design campaign

Plan: `docs/plans/2026-06-28-control-first-design.md`.  Given a candidate geometry,
sweep 6 wind speeds, hunt the k_mppt that produces P_rated at each, record FoS.
Viable designs have FoS ≥ 1.5 at all wind speeds.  Then run a dynamic-aware DE
campaign with the FoS gate in the objective.  Estimated: 4 hours coding, 27 hours
compute.

---

## [2026-06-20] V11: Tapered tether diameters — top tethers carry less load, don't need the same SWL

**Context:** Tether tension accumulates from hub to ground. In the V10 winner (76.75 kg,
n=12, FoS=3.5), the ground tethers carry ~1,000 N per line requiring 3 mm Dyneema
(SWL 3,500 N), but the hub tethers carry only ~200 N per line — they could use
1.1 mm Dyneema (SWL ~475 N).  The current model uses uniform 3 mm diameter
everywhere, over-designing the upper tethers by up to 7×.

**What was decided (V11 scope):**

1. **Single new design variable:** `tether_taper` ∈ [0.3, 1.0] — ratio of top tether
   diameter to bottom diameter.  1.0 = uniform (backward-compatible), 0.3 = top tethers
   at 30% of bottom.  Quadratic taper profile along the shaft.

2. **Per-segment FoS check replaces global tether FoS gate.**  Each inter-ring segment
   is sized for its local cumulative thrust, with its local tapered diameter.

3. **Practical minimum diameter:** D_min = 1.5 mm (not 1.1 mm theoretical).  Below
   1.5 mm, Dyneema braided lines have handling, inspection, and splicing issues, and
   the SWL ∝ D² scaling breaks down due to sheath-to-core ratio.  This limits
   tether_taper to ~0.5 and mass saving to ~2.5 kg.

4. **Expected impact:** ~3 kg mass reduction (72-74 kg vs 76.75 kg), ~1.5 kW drag
   reduction.  The n_lines trade-off shifts — tapered designs make fewer thick lines
   more competitive.

**Alternatives considered:**
- *Uniform tethers (current):* Rejected — over-designs 80% of the tether length.
- *Full per-segment diameter as separate variables:* Rejected — too many DoF.
  A single taper ratio captures the physics with minimal search space expansion.
- *No D_min, allow 1.1 mm:* Rejected — practical handling concerns and SWL
  model fidelity concerns for very small braided lines.

**Status:** Active.  Implemented in V11 campaign.  See
`docs/plans/2026-06-20-v11-tapered-tethers.md` for full scope.

---

## [2026-06-20] Dashboard verification reveals three unmodelled failure modes — constraint expansion required

**Context:** The V9.0 campaign winner (44.52 kg, n=8, n_exp=9, λ=0.40, bank=30°) passed all
`objective_v6` checks (beam buckling FoS ≥ 1.8, torsional FoS ≥ 1.5, P_gen ≥ 50 kW at
equilibrium ω, parasitic drag balanced).  But when loaded into the interactive dashboard
under steady 11 m/s wind at 30° elevation, the design failed catastrophically:

- Power: 403.7 kW (8× rated) — expansion rotors injecting ~350 kW into shaft
- Rotor ω: 85 rpm — dashboard settles to different equilibrium than campaign solver
- Tether FoS: 0.3 — tension 8.2× SWL (3,500 N), peak tension 28,653 N
- Torsional overtwist: RED ALERT — inter-ring twist exceeded π
- Slack events: 38/500 frames (7.6%) — tethers going slack in steady wind

The `objective_v6` function checks structural FoS and power balance, but does NOT model:
1. **Tether tension FoS** — tethers sized for static hub thrust; dynamic forces 8× higher
2. **Torsional overtwist** — the Tulloch limit (inter-ring twist < 0.95π); expansion rotor
   τ_net can twist the shaft beyond safe limits
3. **Slack events** — the static evaluator assumes all lines taut; 7.6% slack frames
   observed in steady wind

Additionally, `solve_equilibrium_self_consistent` uses a 30-point log scan (1–300 rpm) which
has coarse resolution at high ω (~20 rpm between points near 80 rpm), potentially missing
equilibrium crossings where expansion rotor τ_net dominates.

**What was decided:**

1. **Dashboard verification is mandatory** for every campaign winner before it is cited as
   viable.  The dashboard is the ground truth — if it shows failure, the campaign objective
   is missing a constraint.  This is the validation loop: campaign → dashboard → gap →
   constraint → re-campaign.

2. **Three new constraints will be added to `objective_v6`** before the next campaign:
   - Tether tension FoS: `T_per_line / TETHER_SWL ≥ 3.0`
   - Torsional overtwist: `max_twist < 0.95π` (cumulative per-ring twist)
   - Slack guard: `min(thrust_per_ring) > 0` (no decompressed rings)

3. **Equilibrium scan resolution** will be increased from 30 to 100 points, and the
   lifter torque term will be added to `solve_equilibrium_self_consistent` to close
   the ω mismatch between campaign solver and dashboard.

4. **The V9.0 winner (44.52 kg) is scientifically useful but not viable as-is.**  It
   represents the best design within the modelled constraint set.  With the three new
   constraints, the feasible region will shrink and the optimum mass will rise.  The mass
   trajectory — V6.5 fantasy (17.7 kg) → V6.8 corrected drag (58 kg) → V9.0 equilibrium
   (44.5 kg) → V10 full constraints (TBD) — is the arc of increasing physical fidelity.

**Alternatives considered:**
- *Accept the campaign winner and ignore dashboard failures:* Rejected.  The dashboard is
  the higher-fidelity model; if it shows failure modes the campaign missed, those modes
  are real and the objective is incomplete.
- *Abandon the campaign approach and only use full ODE evaluation:* Rejected — the ODE is
  too expensive for DE optimisation (millions of evaluations).  The correct approach is
  to add static proxies for each dynamic failure mode to the objective.
- *Blame the dashboard for the mismatch:* Rejected after investigation — the ω mismatch
  is caused by the campaign solver undersampling the equilibrium scan and ignoring lifter
  torque, not by a dashboard bug.

**Status:** Active.  The three new constraints plus scan resolution fix are the V10
campaign scope.  See `references/v9_0-dashboard-verification.md` for full evidence.

---

## [2026-06-20] Architectural unification — all rotors are expansion rotors, hub rotor special case removed

**Context:** The V6–V9 architecture treated the hub rotor (ring 1) as a distinct entity:
always present, no bank angle, blades in the rotation plane, separately sized.  N
additional expansion rotors were placed via a clustering strategy, all with identical
bank angle and blade scale.  This created two code paths for rotor force computation,
power sharing (`P_per_rotor = P_total / (1 + n_expansion)`), and structural evaluation.

The V9.0 dashboard revealed that expansion rotor τ_net can inject 350+ kW into the
shaft at high ω — the special-cased hub rotor model couldn't capture this because
it assumed the hub dominated the power balance.  Additionally, the expansion rotor
clustering strategy was arbitrary — there was no physics justification for clustered
vs distributed placement.

**What was decided:**

1. **Ring 1's rotor is just another expansion rotor.**  It can have a bank angle
   (0° = axial driving rotor, the former hub-rotor behaviour).  All rotors use
   the same force model, same power sharing, same structural contribution.

2. **Rotor placement is a 60-pattern bitmask.**  Rotors go on the top 10 rings
   (rings 1–10 from hub) with at least 2 bare rings between any two active rotors
   for wake clearance.  This gives 60 valid patterns encoded as a discrete proxy
   variable.  The optimizer chooses which rings get rotors — from 0 (no expansion)
   to 4 (max density at positions 1,4,7,10).

3. **Blade scale and bank angle become gradients.**  `λ_top` and `λ_bottom` with
   linear interpolation between them.  Same for `bank_top` and `bank_bottom`.
   This lets upper rotors carry larger blades at shallower bank (clean air,
   stronger wind, more thrust) while lower rotors use smaller blades at steeper
   bank (wake-affected, more radial spreading).

4. **Per-rotor BEM sizing with wind shear.**  Each rotor is sized for its local
   wind speed via power-law shear (`v ∝ z^0.14`).  The self-consistent equilibrium
   solve sizes all rotors at their local wind, sharing a common ω.

5. **Hub rotor term retired.**  Code references to "hub rotor," "main rotor,"
   "supplementary expansion rotors" are removed.  All rotors are co-equal.

**Alternatives considered:**
- *Keep hub rotor special case:* Rejected — the dashboard proves expansion rotors
  can dominate the power balance, making the hub-centric model physically wrong.
- *Full bitmask over all 21 rings:* Rejected — bottom-half rings see reduced wind
  (shear), are in the wake of upper rotors, and have smaller radius (less leverage
  for spreading).  10 top rings captures the viable rotor positions.
- *Per-ring binary variables (2^10 = 1024 options):* Rejected — the 2-ring gap
  constraint collapses this to 60 valid patterns, which is manageable.

**Status:** Active.  Implemented in V10 campaign (`objective_v10.jl`).  See
`docs/plans/2026-06-20-v10-full-dynamic-constraints.md` for full scope.

---

## [2026-06-20] V10 campaign implementation — bug fixes, validation gates, and bounds tightening

**Context:** The V10 campaign was launched after implementing the architectural
unification (all-rotors-are-expansion) and 8-gate constraint set.  During
implementation, four bugs were discovered that would have silently produced
physically nonsensical designs.  Additionally, the campaign runner lacked
defence against pathological islands — a single buggy design could waste
hours of compute before being caught.  These gaps were closed before launch.

**What was decided:**

### 1. Four critical bugs fixed in `objective_v10.jl`

| Bug | Root cause | Fix |
|-----|-----------|-----|
| Rotor at ground ring | Mask positions mapped 1:1 to ring indices; position 10 → ground ring (n_rings) | Clamp positions to top half (`n_rings ÷ 2`), convert position → ring index = `n_rings - p + 1` |
| λ=0.005 microscopic blades | Lower bound let optimizer functionally disable rotors (blade tip radius → 0) | Raised λ_min from 0.005 to **0.05** (5 cm minimum blade scale) |
| Duplicate `ring_spacing_v4` | Code called the spacing function twice after refactor, using stale `zs` values | Removed duplicate call; single source of truth |
| Wrong zs index for wind | `pos` started as mask position, used directly to index `zs` after it already became ring index | Use `zs[pos]` directly after position→ring conversion |

### 2. Per-island validation gates (6 checks)

Before the campaign advances to the next island, the current island's best design
is validated through a 6-gate check in `_validate_island()`:

| Gate | Check | Rationale |
|------|-------|-----------|
| 1 — Rotor count | `n_active ≥ 1` | Design must have at least one rotor |
| 2 — Mass sanity | 10 kg < mass < 300 kg | Catch pathological penalty escapes and implausible designs |
| 3 — Blade scale floor | `min(λ) ≥ 0.051` | Ensure no rotor has effectively zero blades |
| 4 — Bank diversity | Not all rotors at bank=35° | Pure spreading rotors with zero thrust are degenerate |
| 5 — Equilibrium ω | 1 < ω < 250 rpm | Designs that can't find equilibrium ("air brake") or overspeed are rejected |
| 6 — Power ratio | 0.90 < P_gen/P_rated < 1.10 | Designs must deliver power within 10% of target at equilibrium ω |

If any gate fails, the campaign **halts** with a diagnostic message and the
offending island number.  The user can fix the issue and `--resume` from that
island.  This trades campaign autonomy for compute efficiency — catching a
bug at island 2 saves ~58 islands of wasted DE iterations.

**Alternative considered:** Run all islands regardless and flag failures in a
post-mortem log.  Rejected — by the time the user sees the log, 60 islands of
compute have been wasted.  Halting immediately is the correct trade-off during
active development.

### 3. Design vector tightened from plan

The original plan specified 14-DoF with n_lines ∈ [3, 24].  Three bounds were
tightened compared to the plan:

| Parameter | Plan bound | Implemented bound | Reason |
|-----------|-----------|-------------------|--------|
| `Do_top` min | 0.01 m | **0.05 m** | 1 cm beam OD is below manufacturing floor for a 50 kW system |
| `r_bottom` min | 0.1 m | **0.5 m** | Ground ring below 0.5 m radius can't carry 3× tether attachment geometry |
| `n_lines` max | 24 | **16** | Strip theory Cp model not validated above n=12; 16 already extrapolating |

### 4. Collapse mechanism carries forward from V6

The DE search uses the same stall-detection and population-reset mechanism from
the V6 campaign: every 100 iterations, check population diversity; if collapsed,
perturb the best vector and re-randomise the rest.  This was vetted across the
V6.x–V9.x campaigns and performed reliably.

### 5. Incremental CSV checkpointing

After each island completes, four files are written (appended) with `flush()`:
`convergence_history.csv`, `island_bests.csv`, `parameter_trace.csv`, and
`verification_log.csv`.  The global best is updated atomically in
`best_design.json` + `best_vector.csv`.  This means:
- **Mid-run inspection:** `tail convergence_history.csv` shows progress
- **Crash recovery:** `--resume` reads `island_bests.csv`, skips completed islands
- **No data loss:** `flush()` ensures data hits disk even if the process is killed

**Status:** Active.  The V10 campaign is currently running (60 islands, 80 pop,
elliptical beam profile only).  First campaign launch produced a 49.1 kg winner
(n=12, 2 rotors, r_bottom=2.1 m free); a second launch with tightened bounds is
in progress.  Dashboard verification of the winner is mandatory per the
[2026-06-20] dashboard decision above.

---

## [2026-06-21] V10 v2 diagnostic campaign — fixes to search machinery confirmed correct but insufficient to shift the fitness landscape

**Context:** A dashboard investigation of the V10 winner (island 41, 76.75 kg,
1 rotor at hub) revealed it is dynamically dead: 0.0 kW, −2 rpm, 144 slack
lines, bouncing lift kite, misaligned hub ring.  The single hub rotor
concentrates all thrust at the top ring; upper tethers go slack under dynamic
load and torque cannot transmit to the generator at the ground ring.

Three fixes were applied to the V10 search machinery before a diagnostic
re-run (v2):

1. **Rotor-position clamp removed** (`design_from_vector_v10`).  The old code
   applied `max_positions = n_rings ÷ 2`, silently discarding rotor mask
   positions beyond the top half of rings.  For the V10 winner (n_rings=7,
   mask positions [1,4,7,10]), only position 1 survived — positions 4, 7, 10
   were killed.  The DE selected 4-rotor masks but the objective only evaluated
   1 rotor.  The atlas visualisation (`export_v10_atlas_data.jl`) reported
   `n_rotors = count_ones(mask)` (the raw bit count, 4) rather than the
   clamped `n_active` (1), creating a silent rotor-count mismatch between
   what the pairs plot showed and what the campaign actually optimised.

2. **Tension-distribution gate added** (`objective_v10`, gate 6b).  After the
   structural evaluation, checks `minimum(cumulative_thrust) / n_lines > 0` —
   every tether segment must carry positive tension at ω_eq.  A slack segment
   means the TRPT cannot transmit expansion-rotor torque to the ground-ring
   generator.  Rejects designs with a mass-scaled penalty + 1e6.

3. **Hub-rotor mask filter** (`_generate_valid_rotor_masks`).  41 of 60 masks
   lacked a rotor at position 1 (hub, highest wind).  These were filtered out
   by adding `(m & 1) == 0 && continue`, reducing the valid set to 19 masks,
   all with a hub rotor.  Eliminates DE search time wasted on configurations
   that place the first rotor partway down the shaft.

Additionally, the dashboard's MPPT gain slider range was widened from
`1:1:50` to `1:1:2000` after discovering that `params_v5_50kw().k_mppt ≈ 615`
was out of range — the dashboard was testing at k_mppt=50 (8% of campaign
value), explaining the "massive overpower" symptom reported during dashboard
testing.

**What the v2 diagnostic run showed:**

The v2 campaign was launched (`launch_v10_50kw_v2.sh`, 60 islands, 80 pop)
and stopped after 22 islands.  Every island converged to the same basin as
v1: **n_active=1, 76.7 kg, 41 rpm**.  The tension-distribution gate did not
trigger on single-rotor designs — `cumulative_thrust` is monotonically
positive when all thrust comes from the hub ring.  Multi-rotor masks (e.g.
[1,4], [1,5]) are now available but the DE has no incentive to select them:
a second rotor costs blade mass with no offsetting benefit in the objective.

**Why the fixes didn't change the outcome:**

The fixes addressed structural problems in the *search machinery* (clamp,
masks, gates) but did not change the *fitness landscape*.  Lower mass always
wins, a second rotor always costs mass, and the static tension gate sees
positive cumulative thrust for 1-rotor designs.  The 144 slack lines observed
in the dashboard are a *dynamic* effect from the lift-kite interaction —
tension oscillates, bridles go slack, and the static equilibrium solver
cannot model this.

**What would actually shift the DE toward multi-rotor designs:**

1. **Model the lift kite in the objective's force balance.**  The lift kite's
   tension vector changes the tether force distribution.  Without it, the
   static solver thinks tethers are fine when the ODE shows they collapse.

2. **Add a thrust-spreading incentive.**  Penalise designs where >80% of
   cumulative thrust comes from a single ring.  This would make 2-rotor
   designs at rings [7,4] competitive against 1-rotor at ring 7 alone.

3. **Replace the static tension check with a dynamic proxy.**  The
   `headless_verify_structural` (gravity-settle only) catches degenerate
   geometry but not dynamic slack.  A cheap dynamic check — perhaps a very
   short wind-driven ODE settle with lift device — could close this gap
   without the full 5-minute `headless_verify` scan.

**Status:** The three search-machinery fixes are committed and correct — they
enable multi-rotor exploration and prevent silent rotor-count mismatches.
They do not, by themselves, change the optimum.  The V10 campaign must be
re-run with at least a thrust-spreading incentive or lift-kite modelling
before a multi-rotor design can emerge.  See `docs/plans/2026-06-21-rotor-
position-clamp-tension-gate.md` for the implementation record.

---

## [2026-06-21] Ring-count mismatch — rotor on wrong ring, bridles slack, k_mppt blade-area scaling

**Context:** Dashboard testing of the V10 winner (76.75 kg, 1 rotor, bank=35°,
λ=0.234) revealed 0 kW, −2 rpm, 144 slack lines, and a bouncing lift kite.
Systematic tracing through the ODE state revealed three compounding issues.

**Issue 1 — Rotor on wrong ring.** `design_from_vector_v10` uses intermediate
ring numbering (1..n_rings from `ring_spacing_v4`). `build_kite_turbine_system`
adds ground (ring 1) and hub (ring n_rings+2) rings, creating a +2 offset.
A rotor meant for the hub (mask position 1 → intermediate ring n_rings) was
placed at system ring n_rings (an intermediate ring at r=5.26m) instead of
ring n_rings+2 (the actual hub at r=3.70m).  Rotor thrust and bridle
connections were on different rings — 12/13 bridles slack, tension chain
broken.  **Fix:** Remap ring indices in `build_from_campaign_v10` and
`_build_verify_system`: intermediate ring i → system ring i+1, and the
hub-proxy ring (intermediate ring n_rings) → system ring n_rings+2.

**Issue 2 — Blade scale λ exploited as mass cheat.** The DE converged to
λ=0.234 because blade mass ∝ λ³. The static equilibrium solver found ω_eq
at k_mppt=615 regardless of λ — tiny blades were "compensated" with higher
ω in the solver, but the ODE showed the rotor lacks startup torque to reach
that ω.  At λ=0.234 (tip=2.7m): stalls at 10 rpm, 0.6 kW.  At λ=1.0
(tip=11.5m): spins to 35 rpm, 31 kW.  **Fix:** Scale k_mppt by λ² inside
the equilibrium solver (`k_mppt_eff = p.k_mppt × λ²`).  A λ=0.5 rotor has
¼ the swept area of λ=1.0 and should expect ¼ the power.  The scaled
k_mppt is passed to `solve_equilibrium_self_consistent` so ω_eq is found
for the correctly-sized generator load.  Applied in both `objective_v10`
and `build_from_campaign_v10` for dashboard consistency.

**Issue 3 — Lift kite tension adequate but structural tension degrades.**
After fixes 1 and 2, all 12 bridles are taut (139-161N).  The lift kite
provides 1.53 kN vs 0.75 kN system weight — healthy 2× margin.  Initial
slack drops from 36% to 5%.  After 2s simulation: 19% slack, 2.3 rpm,
0 kW — tension still degrades dynamically.  Force balance at hub shows
bridle axial force (1.53 kN) slightly exceeds rotor thrust (1.36 kN) plus
axial weight (0.38 kN) by 0.21 kN — the lift kite is marginally too weak
to maintain axial preload under dynamic conditions.  Not yet resolved;
the rotary lifter radius/elevation factor may need tuning, or a second
rotor to increase total thrust.

**Status:** Issues 1 and 2 are fixed and committed (commits 71ea694 and
1c86b69).  Issue 3 (dynamic tension degradation) remains open.

The tight-bounded campaign with k_mppt scaling (`launch_v10_tight.sh`,
commit 04f2d18 with widened validation gates) found a fundamentally
different basin: **49.20 kg, 4 rotors, λ=0.519, r_hub=2.89m, ω=59 rpm**
— a 36% mass reduction from the V10v1 76.75 kg baseline.  The k_mppt
λ² scaling prevented the DE from converging to λ→0; the ring-mapping
fix placed rotors on the correct hub ring; the hub-rotor mask filter
reduced the search space from 60 to 19 masks.

However, post-campaign dynamic verification (`headless_verify` k_mppt
scan) shows the design is still dynamically dead: 12.1 kW at 55.6 rpm
(24% rated) vs the static solver's prediction of 50 kW at 59 rpm.  The
static-vs-dynamic power gap persists — the equilibrium solver and the
multibody ODE disagree on the operating point even with the k_mppt
scaling fix.  Five parameters are screaming at bounds (Do_top, t_over_D,
r_bottom, target_Lr, λ_bottom), indicating the true optimum lies outside
the current tight envelope.

Full analysis: `docs/reports/v10-tight-analysis.md`.
Landscape diagram: `docs/awes-forum-diagrams/v10-tight-landscape.png`.

---

## [2026-05-23] Banishment of Furl, Transition to Pitch Depower, and Terminological Preservation of Furl

**Context:** During wind-spilling winching scenarios in *KiteTurbineDynamics.jl*, the simulator previously used the term "Furl" to refer to the process of winching out the backline to raise the turbine rotor and spill the wind. This terminology created significant confusion with "Lift Kite Furling" (the aerodynamic modulation of the top lift device to prevent structural overload in high winds). 

Furthermore, high-fidelity dynamic simulations of this scenario identified a critical failure mode: if the backline is paid out without active tension constraints on the top lift device, the sky anchor and bearing sag under gravity and wind, causing the gold bridles to go completely slack (Tension = 0.0 N). This structurally decouples the ground generator from the airborne rotor, rendering active drivetrain damping and $k_{\text{MPPT}}$ stall governance completely useless, and triggering severe, unphysical 100 rad/s intermediate ring whipping and torsional collapse.

**What was decided:**
- **Banishment of "Furl" for Shaft Operations:** The term "Furl" is completely retired from all user-facing GUI, status messages, simulation parameters, and test campaigns. It is replaced by **"Pitch Depower"** (or **"Turbine Rotor Pitch Depower"** in full).
- **Physical Concept & Terminological Separation:** 
  1. *Pitch Depower:* Raising the generating rotor (at the top of the TRPT) by paying out the backline to tilt its axis of rotation closer to vertical, reducing its apparent wind annulus area and spilling wind.
  2. *Furl:* Strictly reserved for future work on the lift kite's own aerodynamic lift modulation/reduction under extreme wind loads to protect the sky anchor from overload.
- **The Lifter High-Tension Constraint:** The top lifting rotor kite must maintain **full operational lift force and tension** (high-tension pull, similar to and at least as much as under normal operating conditions, i.e., $T_{\text{lift}} \ge 1000\text{ N}$) throughout the entire Pitch Depower operation. This ensures that the TRPT column remains preloaded and taut, the gold bridles never go slack, and the ground-winch + MPPT stall braking controls can safely and smoothly stall the generating rotor.
- **Drivetrain Active Damping Preservation:** Ground damping is preserved during pitch depower and is physically valid because the high-tension pull of the lifter kite keeps the bridles and tethers taut ($GJ \gg 0$).
- **UI HUD Default Open:** The "Lift Device" HUD telemetry section is set to start open by default to display the lifting line tension $T_{\text{lift}}$ in real time, so that the high-tension pull constraint is immediately visible and easily monitored.

**Alternatives Considered:**
- *Letting the lift kite depower at the same time:* Checked in simulation, but this causes complete loss of tether tension, leading to bridle slackness, dynamic uncoupling of the PTO, and immediate torsional collapse.
- *Keeping "Furl" as the general term:* Ruled out due to the clear physical distinction between spilling wind on the generating rotor (Pitch Depower) and spilling wind on the lifting device (Furl).

**Status:** Active.

---

## [2026-05-22] Phase N — Full 6-DOF Inertia Relief & Moment Equilibration in Space-Frame Ring FEA Solver

**Context:** During dynamic simulations (e.g., startup, wind changes, or furl/slack scenarios), the intermediate spacer rings of the airborne kite turbine undergo acceleration due to unbalanced forces (such as gravity, aerodynamic wind drag, and cyclic tether tension). Because the space-frame finite element method (FEA) solver in `src/ring_element_analysis.jl` is static, it solves a stiffness equation $K d = F$. To handle rigid-body modes (since the free-floating ring is not physically anchored to the ground), a soft Tikhonov ground spring regularisation ($\varepsilon$) is added to the diagonal of $K$.

Previously, when the net applied force vector $\vec{F}_{\text{net}} \neq \vec{0}$, these soft ground springs reacted to the net force, leading to huge fictitious rigid-body translations ($d \approx 10^6 \text{ m}$ to $10^8 \text{ m}$). We initially resolved this using a 3-DOF translational inertia relief. However, even with balanced forces, the intermediate rings experienced unbalanced out-of-plane rotational (pitch/yaw) moments ($M_x, M_y$) and in-plane torsional moments ($M_z$) due to dynamic, asymmetric tether loading. The soft regularisation springs ($\varepsilon$) reacted to these unbalanced moments by generating massive fictitious rigid-body rotations (e.g., $10^4$ to $10^6$ radians). Floating-point precision loss (limited to 16 decimal digits for `Float64`) completely corrupted the local coordinate transformations and local displacement recovery ($d_{\text{elem}} = T d$). This numerical noise leaked in-plane forces into colossal, artificial out-of-plane bending moments ($M_{\text{oop}} \approx 400 - 700\text{ N}\cdot\text{m}$ vs elastic capacity $54.7\text{ N}\cdot\text{m}$), causing all struts to turn bright red in the dashboard (max utilisation $>9000\%$, FoS = 0.0) even in benign operating points.

**What was decided:**
- **Full 6-DOF Inertia Relief Formulation:** Apply D'Alembert's Principle to perfectly equilibrate both the translational forces and the rotational/torsional moments of the system before passing it to the static FEA solver. Since the ring is a flat, symmetric polygon in the local ring frame, its mass is distributed symmetrically among $n$ identical knuckles of radius $R$ at local coordinates $(x_j, y_j)$. We formulate the angular D'Alembert inertial reaction force corrections as follows:
  1. *Translational Inertia Relief (3 DOFs):*
     $$\Delta \vec{F}_{\text{global}, j} = -\frac{\vec{F}_{\text{net}}}{n}$$
     This perfectly zeroes the net global force: $\sum_{j=1}^n \vec{F}_{\text{global}, j} = \vec{0}$.
  2. *Torsional Inertia Relief (1 DOF - in-plane rotation about local z-axis):*
     Given the net torsional moment $M_z = \sum_{j=1}^n (x_j F_{y,j} - y_j F_{x,j})$, the D'Alembert reaction forces at each vertex must oppose $M_z$ proportionally to their radial distance. For a flat ring of radius $R$, the corrective forces are tangential:
     $$\Delta F_{x, j} = + \frac{M_z y_j}{n R^2}, \quad \Delta F_{y, j} = - \frac{M_z x_j}{n R^2}$$
     This cancels the net torque perfectly: $\sum (x_j \Delta F_{y,j} - y_j \Delta F_{x,j}) = -M_z$.
  3. *Rotational Inertia Relief (2 DOFs - out-of-plane pitch/yaw about local x and y axes):*
     Given net out-of-plane moments $M_x = \sum y_j F_{z,j}$ and $M_y = \sum -x_j F_{z,j}$, the out-of-plane D'Alembert reaction forces at each vertex oppose these moments:
     $$\Delta F_{z, j} = - \frac{2}{n R^2} (M_x y_j - M_y x_j)$$
     This cancels out-of-plane moments perfectly: $\sum y_j \Delta F_{z,j} = -M_x$ and $\sum -x_j \Delta F_{z,j} = -M_y$.
- **Algorithm:** In `analyse_ring`, we compute $M_x, M_y, M_z$ in local coordinates and subtract/add the respective corrective forces. This mathematically guarantees that all net forces and moments in the local frame are zeroed to machine precision ($<10^{-13}$), removing all fictitious translations and rotations.
- **Alternatives Considered:**
  - *Pinning arbitrary nodes/DOFs:* Introducing fixed/pinned nodes violates the free-floating boundary conditions, introducing artificial reaction forces and asymmetric stresses that corrupt the physical load distribution.
  - *Increasing the regularisation parameter $\varepsilon$:* Increasing $\varepsilon$ suppresses fictitious motions but acts as a stiff artificial ground spring, which constrains ring deformation and artificially inflates local beam forces.

**Results, Rationale & Physical Design Limits:**
- **Numerical Zeroing:** All fictitious rigid-body motions are eliminated, reducing translational displacements to $\approx 10^{-15}\text{ m}$ and rotations to $\approx 10^{-16}\text{ rad}$. Floating-point precision is fully preserved.
- **Visual Accuracy:** The spacer struts in the interactive dashboard now accurately show realistic, physical, and highly differentiated colors corresponding to actual structural bending and compression, rather than a uniform red warning.
- **Real physical torque waves:** The simulation now clearly reveals physical torsional propagation waves running up and down the TRPT shaft, validating the dynamic multibody line tension coupling.
- **Physical Design Limit at $t = 1.26\text{ s}$:** With the numerical artifacts eliminated, we observe that at $t = 1.26\text{ s}$ (during peak transient power transmission of $8.21\text{ kW}$ and a TRPT twist of $181.1^\circ$), the worst-beam strut utilization reaches **$302.8\%$** (FoS $\approx 0.33$). 
  - *Spacer Rings (Rings 1 to 13):* Remain perfectly safe, with utilization ratios between $0.6\%$ and $1.5\%$, proving the spacer ring sizing is structurally sound.
  - *Ground-end Ring (Ring 14):* The high utilization of $302.8\%$ occurs on the ground-end ring which directly reacts the PTO torque and shear. This is **physically real**, indicating that the ground-end ring structure under peak transient dynamic torque waves is under-designed. A wider ring radius or larger tube diameter is physically required at the ground end to handle peak dynamic torque transients.

**Status:** Active.

---

## [2026-04-30] Phase K — v5 campaign results: BEM-coupled rotor radius closes the n_lines loop

**Context:** The v4 campaign found n_lines = 8 at the upper search bound in all 60 islands and
the audit (entry below) established this was an artefact: more lines always improved Euler
buckling resistance at zero aerodynamic cost because rotor radius R was a fixed input from
`SystemParams` with no Cp(n_lines) coupling. v5 closes the loop by deriving R
self-consistently from n_lines via a BEM Cp model, so Cp degradation from over-solidity
translates into a larger R, higher thrust, and higher shaft mass.

**What was decided (v5 formulation):**

- Rotor radius R is no longer a fixed input. It is derived per candidate design: given n_lines,
  chord geometry, and a BEM Cp(σ, TSR) surface, compute the σ that maximises Cp, find Cp_max,
  then back-calculate R from `P_rated = 0.5ρv³πR²Cp_max·η`.
- BEM Cp surface fitted from a sweep over n_lines ∈ {3…12}, TSR ∈ {3…10}, solidity
  σ = n_lines × chord_eff / (2π × R). Stored in `src/bem_cp_model.jl`.
- All other physics unchanged from v4 (Euler FOS ≥ 1.8, Torsional FOS ≥ 1.5, L/r spacing, DLF).
- n_lines upper bound kept at 8: strip theory is not validated above n = 6; raising the bound
  pending CFD/panel-method confirmation.

**Results — 10 kW winner:**

| Parameter           | Value                               |
|---------------------|-------------------------------------|
| Mass                | **11.470 kg** (+8.3 % vs v4)        |
| n_lines             | 8 (unanimous across all 60 islands) |
| Beam profile        | Circular                            |
| r_hub               | 1.600 m                             |
| r_bottom            | 0.340 m                             |
| target_Lr           | 2.0                                 |
| Cp (BEM-derived)    | 0.453                               |
| R (self-consistent) | 5.12 m (vs fixed 5.0 m in v4)       |

**Campaign summary across all runs (10 kW):**

| Campaign | Constraint set                          | Best mass    | Δ vs v3   |
|----------|-----------------------------------------|--------------|-----------|
| v2       | Beam buckling only                      | 2.808 kg     | — (torsionally infeasible) |
| v3       | Beam + torsion (cylindrical forced)     | 15.435 kg    | baseline  |
| v4       | Beam + torsion (taper free, fixed R)    | 10.587 kg    | −31.4 %   |
| **v5**   | **Beam + torsion (taper free, BEM R)**  | **11.470 kg**| **−25.7 %** |

**n_lines = 8 is robust under BEM coupling.** The Cp penalty at n_lines = 8 solidity
(σ ≈ 0.18 for the winner geometry) relative to n_lines = 5 canonical (σ ≈ 0.11) is
approximately 3–4 %, translating to ~2 % larger R, ~3 % higher thrust, ~2 % higher shaft mass.
The structural benefit of 8 vs 5 lines (shorter polygon segment → lighter beams) outweighs
the aerodynamic penalty. n_lines = 8 is the unanimous choice across all 120 islands
(60 v4 + 60 v5), across both 10 kW and 50 kW configurations.

**Strip theory validity flag:** BEM strip theory is well-validated for n_lines ≤ 6. At
n_lines = 8, blade-to-blade interaction (wake interference, solidity effects, potential-flow
blockage) is not captured. Cp values at n_lines = 8 are provisional. CFD or panel-method
validation is required before adopting n_lines = 8 for hardware.

**Figures generated (committed to master):**

- `figures/report/fig_trpt_system.png`, `fig_elevation_angle_trade.png`,
  `fig_structural_efficiency_profile.png`, `fig_tulloch_wacker_chart.png`,
  `fig_cp_contour.png`, `fig_nlines_mass_curve.png`, `fig_campaign_geometry_evolution.png`,
  `fig_campaign_progression.png`, `fig_design_space.png`, `fig_fos_landscape.png`
- `figures/fig_k_beam_profile_mass.png`, `fig_k_nlines_v4_v5.png`,
  `fig_k_Lr_sensitivity.png`, `fig_k_taper_vs_mass.png`, `fig_k_torsional_binding.png`,
  `fig_k_v4_v5_mass_comparison.png`

**In progress:** `TRPT_AWE_Forum_Report_v3.docx` — builds on v4 and v5 results for external
presentation.

**Open questions for v6:**
1. CFD/panel-method validation of n_lines = 8 Cp (strip theory not validated at n > 6).
2. Joint β + structural optimisation: β fixed at 30° throughout v2–v5; cold-start and
   lift-kite analysis suggest optimum near β ≈ 26°. v6 should free β alongside the
   structural parameters.
3. Dynamic torsional loading and fatigue: all campaigns size against a static peak envelope.
   Cyclic tether tension (1P, 2P rotor harmonics) and fatigue life are not modelled.

**Status:** Active. v5 (11.470 kg) is the current best physically-consistent TRPT shaft
design. The +8.3 % mass penalty vs v4 is the cost of aerodynamic self-consistency.

---

## [2026-04-25] Phase J — v4 campaign results: taper recovery yields 31 % mass reduction vs v3

**Context:** The v3 campaign (Phase I) established the first torsionally-constrained minimum-mass
TRPT shaft design. It identified 15.435 kg as the 10 kW optimum, but that campaign forced a
cylindrical shaft profile (`taper_ratio = 1.0`) to isolate the torsional constraint as the new
physics. The v4 formulation restored taper freedom and replaced the five-parameter axial profile
family with a single `target_Lr` variable that enforces a constant L/r ratio across all shaft
segments via a geometric-series ring spacing.

**What was decided (campaign setup):**

- **Formulation:** 9 design variables per island — `Do_top`, `t_over_D`, `beam_aspect`,
  `Do_scale_exp` (taper), `r_hub`, `r_bottom`, `target_Lr`, `knuckle_mass_kg`, `n_lines`.
  Ring count `n_rings` is derived, not free.  `target_Lr ∈ [0.4, 2.0]`.
- **Beam profiles:** Circular, Elliptical, Airfoil (3 families).
- **Power configs:** 10 kW and 50 kW (2 configs).
- **Islands:** 60 = 3 beams × 5 Lr initialisation zones × 2 seeds × 2 power configs.
- **Optimiser:** Differential Evolution, F = 0.7, CR = 0.9, pop = 64, stall restart at 1 500
  generations; 168 h total budget ≈ 2.8 h per island.
- **Constraints:** beam buckling FOS ≥ 1.8 (hard); torsional collapse FOS ≥ 1.5 (hard).
- **Objective:** minimise TRPT shaft mass (kg) subject to both constraints being feasible.

**Results — 10 kW winner:**

| Parameter          | Value                |
|--------------------|----------------------|
| Mass               | **10.587 kg**        |
| Beam profile       | Circular (or Elliptical — identical mass) |
| r_hub              | 1.600 m              |
| r_bottom           | 0.336 m              |
| Tether length      | 30.0 m               |
| target_Lr          | 2.0                  |
| n_rings (derived)  | ≈ 19                 |
| n_lines            | 8                    |
| Do_top             | 0.039 m              |
| Do_scale_exp       | 0.49 (tapered)       |
| t_over_D           | 0.02                 |
| Beam FOS           | 1.80 (at constraint) |

**Results — 50 kW:**

- Circular/Elliptical: 79.51 kg (beam FOS = 1.80, feasible)
- Airfoil: 749.50 kg (airfoil profile penalty large at 50 kW scale)

**Comparison vs previous campaigns (10 kW):**

| Campaign | Constraint set          | Best mass | Notes                              |
|----------|-------------------------|-----------|------------------------------------|
| v2       | Beam buckling only      | 2.808 kg  | Torsionally infeasible — invalid   |
| v3       | Beam + torsion (cylindrical) | 15.435 kg | Taper forced to 1.0            |
| **v4**   | **Beam + torsion (taper free)** | **10.587 kg** | **−31.4 % vs v3**    |

**Key finding — taper restoration:**

Restoring taper freedom (freeing `Do_scale_exp` from its v3-implicit cylindrical value)
reduces optimum mass from 15.435 kg to 10.587 kg — a 31.4 % saving under identical
torsional and beam constraints.  The winning `Do_scale_exp` = 0.49 gives a shaft that tapers
smoothly from hub (Do = 39 mm, r = 1.6 m) to a narrow ground ring (r = 0.34 m); the beam
tubes at the ground end are proportionally thinner, saving steel where the torsional load is
lowest.

The v4 mass (10.587 kg) is still 3.8× heavier than the v2 taper-and-beam-only result
(2.808 kg), confirming that torsional constraint adds real mass, not just formulation cost.
Taper does not "undo" the torsional penalty; it recovers the mass that the forced-cylindrical
assumption artificially added to v3.

**Convergence robustness:** All 20 islands in the 10 kW circular + elliptical groups
converged to the same design parameters (mass = 10.587 kg, target_Lr = 2.0) regardless of
initial Lr zone or seed, confirming the DE found a single global minimum.  The 10 kW airfoil
group converged to a distinct, heavier solution (70.78 kg), confirming that airfoil beam
profiles are structurally inferior at this scale.

**Figures generated:**
- `figures/fig_v4_pareto.png` — mass by group (all 60 islands), log-scale
- `figures/fig_v2_v3_v4_comparison.png` — mass and FOS comparison across campaigns
- `figures/fig_v4_geometry.png` — side-elevation of the winning shaft (≈19 rings, 30 m tether)
- `figures/fig_v4_island_heatmap.png` — 60-cell mass heatmap

**Alternatives considered:**
- Continue v3 search with cylindrical assumption and more compute time — ruled out; cylindrical
  is demonstrably sub-optimal and the 31 % gap is physically justified, not a search artefact.
- Run v4 with 50 kW as the primary target — done in parallel; 50 kW winner is 79.5 kg
  (circular), forming the design-space anchor for future 50 kW structural work.

**Status:** Superseded as the current reference by v5 (11.470 kg with BEM-coupled R). v4 remains
the structural lower bound — the minimum mass achievable if Cp is truly independent of n_lines.
Future work should validate the winning geometry against a higher-fidelity structural model.

---

## [2026-04-25] n_lines Cp independence assumption in v4 (resolved in v5)

**Context:** The v4 campaign found n_lines = 8 (the upper bound) in both 10 kW and 50 kW
winners. Power (10 kW / 50 kW) entered v4 only via a fixed `r_rotor` in `SystemParams`. There
was no Cp(n_lines), Cp(TSR), or Cp(solidity) term in the v4 objective. CT = 1.0 was a fixed
conservative BEM ceiling. More lines was always structurally better (shorter polygon segments →
higher Euler resistance), with zero aerodynamic cost — so the optimiser saturated n_lines at
the upper bound as an artefact, not as a physically validated aerodynamic optimum.

**Decision:** Accept v4 as the minimum-mass shaft design conditional on Cp being independent of
n_lines. Flag v4 as structurally valid, aerodynamically unverified.

**Resolution (v5, 2026-04-30):** v5 implements BEM-coupled rotor radius. n_lines = 8 still
wins unanimously across all 120 islands, confirming the structural benefit outweighs the Cp
penalty at this solidity. The n_lines = 8 preference is robust within the BEM strip model but
not validated at n > 6 by higher-fidelity methods (see v5 entry above).

**Status:** Resolved for the BEM-strip model. CFD/panel-method validation pending for n_lines = 8.

---

## [2026-04-22] Ground ring deployment constraint: maximum radius 1.5 m

**Context:** The ground ring of the TRPT shaft is the lowest ring — closest to the ground
station, anchored and connected to the drive train. Its radius sets the physical footprint of
the ground structure (rotor anchor frame, bearing housing, guide ropes). In the v2 optimiser,
`taper_ratio` was bounded below (taper_ratio ≥ 0.15, or 0.5/r_hub for small systems) to
prevent geometrically degenerate designs. The v4 formulation replaces `taper_ratio` with
`r_bottom` as an explicit design variable. Without an upper bound on `r_bottom`, the optimiser
could select a ground ring radius approaching the hub radius (nearly cylindrical) — maximising
structural efficiency but requiring a large, difficult-to-transport ground anchor structure.

**Choice made:** `max_ground_radius = 1.5 m` as the hard upper bound on `r_bottom`. Designs
with `r_bottom > 1.5 m` are returned as infeasible by `evaluate_design`. The parameter is
configurable — `search_bounds_v4` and `evaluate_design` both accept a
`max_ground_radius` keyword argument with default 1.5 m. The lower bound on `r_bottom` is
0.3 m (minimum structural ring capable of carrying rope attachment geometry without the beam
centroid overlapping the rope).

**Alternatives considered:** Deriving the ground ring constraint dynamically from the ground
station footprint model. This would require the ground station geometry as a system parameter
— accurate but coupled. A simpler alternative of using `taper_ratio` bounds as before (≥ 0.15
of r_hub ≈ 0.3 m for 10 kW) would work for a single power class but doesn't scale correctly
when r_hub changes with power rating.

**Why this choice:** 1.5 m ground ring radius fits within a standard flatbed trailer width
(2.4 m) with margin for structural frame and anchoring — a practical deployment constraint
for the 10 kW field trials. A 50 kW system would require revisiting this bound (r_hub ≈ 4–5 m
suggests r_bottom up to 2.0–2.5 m may be acceptable). Making it a keyword argument means it
can be changed per power class without changing the function signature.

**Consequences:** The v4 optimiser will not discover designs with ground ring radius above
1.5 m. If future site access improvements allow larger ground structures (e.g., permanent
offshore installation), the bound should be raised. The lower bound 0.3 m guards against
structurally nonsensical designs; raising it risks missing valid extreme-taper configurations.

**Status:** Active.

---

## [2026-04-22] v4 ring spacing: variable positions targeting constant L/r per segment

**Context:** In v2 and v3, polygon spacer rings are placed at uniform axial intervals along
the 30 m tether, with ring radii interpolated along one of five profile families (linear,
elliptic, parabolic, trumpet, straight-taper). The torsional collapse analysis showed that
uniform spacing with a tapered geometry creates severely non-uniform L/r ratios per segment:
thin bottom segments (small r) get the same axial spacing L as wide top segments (large r),
giving them a much higher L/r ratio. This drives two problems simultaneously:
(a) thin bottom segments are in the Euler buckling danger zone (P_crit ∝ 1/L²), and
(b) the optimiser is forced toward taper_ratio → 1.0 (cylindrical) because any taper with
uniform spacing makes the bottom segments structurally expensive and the optimiser eliminates
taper to equalise the segment lengths.

**What was decided:** v4 replaces the (n_rings, taper_ratio, axial_profile) triplet with two
design variables: `r_bottom` (ground ring radius, bounded) and `target_Lr` (target L/r ratio,
common to all segments). Ring positions are no longer inputs to the optimiser — they are
computed from the constant-L/r constraint via `ring_spacing_v4()`. The number of rings n_rings
is an output: determined by the geometry, not the optimizer.

**Physics:** For a linear taper from r_top to r_bottom, constant L/r implies radii form a
geometric series. The key relationships:
- Segment axial length: L_i = target_Lr × r_mid_i (shorter near ground, longer near hub)
- Ring radii ratio: r_{i+1}/r_i = k, where k = (2 - α×target_Lr)/(2 + α×target_Lr),
  and α = (r_top - r_bottom)/tether_length is the taper slope
- Euler buckling capacity: P_crit ∝ I/L² ∝ r² (for Do ∝ r^0.5 scaling) / L²
  → with L = c×r: P_crit ∝ r²/(c×r)² = 1/c² = constant across all rings ✓
- Compression load N_comp ∝ T_line ≈ constant (dominated by axial thrust / n_lines)
- Result: FoS ≈ constant across all rings → no wasted structural margin anywhere

Mass scales as ∝ D² × L ∝ r × L = r × target_Lr × r = target_Lr × r². Bottom rings are
lighter (smaller r) AND have shorter span — doubly efficient. Drag loss scales as ∝ D × L ∝ r
× target_Lr × r = target_Lr × r² (same scaling as mass — consistent trade-off).

**Alternatives considered:** Uniform spacing (v2/v3) — proven above to be wasteful for tapered
designs. Manually specified ring positions — maximum flexibility but too many variables for a
DE search and no physical structure. Geometric-series spacing with n_rings as integer input
(rather than target_Lr as continuous input) — preserves the physics but loses the natural
parametrisation and creates discontinuities when n_rings rounds.

**Why this choice:** target_Lr is a smooth, physically meaningful continuous parameter (the
slenderness ratio is a canonical beam design parameter). The optimizer can gradient-follow it
continuously while n_rings adjusts discretely in the background. This is more natural than
optimising n_rings directly. The constant-L/r constraint is also the correct structural analogy
to "keep all segments at the same point on the Euler buckling curve" — a classical optimal
design principle.

**Consequences:** The v4 formulation removes the axial profile family variables
(axial_profile, profile_exp, straight_frac) — they become redundant since ring positions are
fully determined by (r_bottom, target_Lr, r_hub, tether_length). The dimensionality drops from
12 DoF (v2) to 9 DoF (v4). Results are NOT directly comparable with v2/v3 campaign winners
without re-running both; the v4 formulation searches a different manifold of the design space.
The v4 campaign should be run after v3 to compare minimum-mass winners at the same FoS
threshold.

**Status:** Active.

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

Tulloch (PhD thesis, University of Strathclyde) and Wacker (unpublished analysis, Windswept internal) derived
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

**Status:** Resolved (2026-04-22). The torsional collapse constraint was implemented as a hard
feasibility gate in v3 (see the v4/v5 campaign entries above). All campaigns from v3 onwards
enforce Torsional FOS ≥ 1.5 alongside Euler buckling FOS ≥ 1.8. This entry is retained for
historical context — it describes the gap as it existed during Phase C–H (v2).

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

---

## Knowledge Pipeline Decisions

*These decisions were made during the 2026-06-22–23 K1 knowledge extraction sprint.
They live here because the pipeline serves KTD.jl's literature grounding.
Full session record: `docs/reports/knowledge-pipeline-sprint.md`.*

### [2026-06-22] Single-doc GPU processor for industry documents

**Context:** Initial approach used persistent K1 GPU server (localhost:8000). Crashed after
4–5 requests due to GPU memory accumulation.

**Decision:** Switched to single-doc processor — each cron tick loads the K1 model fresh,
processes ONE document, then frees GPU memory.

**Rationale:** Eliminates server OOM. Trade-off: ~20s model load overhead per doc, but
reliable. Of 45 industry docs, none lost to crashes after the switch.

**Status:** Deployed in `ingest_one_industry.py`. Cron paused 2026-06-23.

### [2026-06-22] Cursor + skip logic for academic ingestion

**Context:** Initial `k1_ingest.py` re-processed all 540 papers on every run. 64 papers
(patents/catalogues) produced empty graphs, wasting 14 reads per batch.

**Decision:** `~/.k1_ingest_cursor` tracks last-processed filename. Skip gate checks for
existing `graph.json` before processing. Empty graphs are also skipped.

**Rationale:** Idempotent ingestion. No wasted GPU on known-empty or already-processed papers.

**Status:** Deployed. Cursor file at `~/.k1_ingest_cursor`.

### [2026-06-22] JSON repair over clean-output enforcement

**Context:** K1 4B model produces near-valid JSON with common failures: unterminated
strings, markdown code fences, trailing commas.

**Decision:** Accept imperfect K1 output and repair post-hoc rather than constrain
K1 generation (which would reduce extraction quality).

**Rationale:** JSON repair is deterministic and cheap. Prompt constraints to force
perfect JSON reduce extraction quality. Repair handles 95%+ of failures.

**Status:** Deployed in `k1_server.py` and `k1_ingest.py`.

### [2026-06-22] max_tokens=4096 + paragraph-boundary chunking

**Context:** Initial max_tokens=2048 caused frequent JSON truncation. Papers with
many findings produced partial graphs.

**Decision:** Increased to 4096 tokens output. Input text chunked on paragraph
boundaries at 6000-char windows.

**Rationale:** Doubled token budget nearly eliminated truncation. 4096 is the practical
limit for K1 4B on RTX A4500 (20 GB VRAM). Paragraph-aware chunking preserves
semantic units.

**Status:** Deployed in both `k1_ingest.py` and `ingest_one_industry.py`.

### [2026-06-23] Phase prioritization: 1 → 3 → 3b

**Context:** Multiple analysis phases compete for attention. Need Porto-ready materials.

**Decision:** Phase 1 (collaboration map) → immediately useful for networking.
Phase 3 (citation lineage) → ground claims in literature.
Phase 3b (web validation) → pressure-test highest-risk claims before being challenged.

**Rationale:** Collaboration map is the most immediately useful deliverable. Citation
lineage prevents embarrassment. Web validation catches K1 graph blind spots. Phases
4 (CSV anchoring) and 5 (paper synthesis) deferred.

**Status:** Phases 1, 3, 3b complete. Phases 4, 5 planned.

### [2026-06-23] All crons paused for Porto preparation

**Context:** Ingestion complete (540 academic + 45 industry). Continuous cron
notifications generate noise during focused preparation.

**Decision:** Paused all three ingestion crons. GPU freed. Signal notifications stopped.

**Status:** All crons paused. AWS Paper Ingest, K1 Paper Ingest, Industry Doc Ingest
all in 'paused' state as of 2026-06-23 15:17.

### [2026-06-29] Dashboard v2 — per-ring/per-rotor panels

**Context:** Prototype panels developed (torque chain, ring health, rotor power
gauges, twist view, config & controls). `ExtendedSimFrame` + `capture_extended()`
added to `src/sim_frame.jl` providing per-ring and per-rotor data. All existing
tests pass — the extension is backward-compatible (wraps SimFrame, doesn't modify it).

**Decision:** Create `build_dashboard_v2()` in `src/visualization.jl` alongside
the existing `build_dashboard()`. The v1 dashboard (3D viewport + HUD) stays
working. `scripts/interactive_dashboard.jl` gets a `--v2` flag to select the
new layout.

**V2 layout:** 6-row responsive grid
- Row 1: Cockpit strip (7 KPIs, integrated from separate window)
- Row 2: Torque chain | Ring health bars | Rotor gauges (vertical) | Config & Controls
- Row 3: Twist view | Tension chain | 3D viewport
- Row 4: Event log + Playback controls

**Responsive sizing:** Switch from `Fixed()` to `Relative()` and `Auto()` column
widths so the dashboard scales to any screen size (laptop + desktop).

**Implementation steps (ordered, test each):**
1. Create `build_dashboard_v2()` skeleton — same Figure, same 3D viewport, new grid
2. Capture `ExtendedSimFrame`s alongside existing `SimFrame`s in pre-compute loop
3. Add cockpit strip as row 1 of the main Figure (remove separate window)
4. Add bar chart panels (torque chain, ring health, tension chain) with `@lift`
5. Add rotor power gauge panel (vertical stack, concentric rings)
6. Add twist view panel (polar, looking down shaft axis)
7. Add Config & Regen Controls panel (read-only labels for now)
8. Switch to Relative sizing
9. Wire `--v2` flag in `interactive_dashboard.jl`
10. Run full test suite after each step

**Status:** Steps 1-4 ✓. Steps 5-10 paused pending v2 interactive controls refactor.

### [2026-06-30] V2 scenarios blocked — grid conflict

**Context:** V2 layout uses `fig[1,1:4]` for cockpit strip. V1 `_rerun!` machinery
is coupled to `fig[1,1]` (controls column) and `fig[1,3]` (HUD column). The two
grids collide. V2 returns early before the shared scenarios/controls code.

**Decision:** Paused. Need to either (a) extract `_rerun!` into a parameterised
function that both layouts call, or (b) define v2-specific controls in the v2
grid. Both are ~150 lines. Best done with display available for verification.

**What works:**
- `--v2` flag in interactive_dashboard.jl passes `layout=:v2` to build_dashboard
- V2 renders the grid, cockpit strip, ring health bars, 3D viewport
- V2 displays pre-computed frames (from v1 pipeline) correctly
- `ExtendedSimFrame` capture integrated into both pre-compute and `_rerun!` loops
- Ring health bars update via `ext_frames_obs` in the `on(frame_obs)` handler

**What doesn't:**
- Scenario buttons, slider, playback controls, config switching in v2

### [2026-07-09] Parametric Design Explorer (Pluto.jl + MeshCat.jl)

**Context:** Aligning on spatial hardware design nuances (such as ring spacing, tapering, blade span offsets, spoke-tie boundaries, and material constraints) between human designers and AI agents via natural language is challenging and prone to translation errors. The GLMakie dashboard runs locally and is non-visual to agents, Grasshopper/Rhino requires a Windows environment, and TeX diagrams are static. A shared, interactive, code-as-data 3D playground is needed.

**Decision:** Implemented **Path A: The Simulation-First Route (Pluto.jl + MeshCat.jl)**. Created `notebooks/design_explorer.jl` as a standalone reactive Pluto notebook. Fixed the sibling dependency `CoaxialAutogyroStacking` path mapping in `Manifest.toml` from `/home/rod/...` to `/home/rodbot/...` to allow full compilation.

**Rationale:**
- **Pluto.jl** notebooks are standard Julia files that are fully readable and writable by AI agents, making code-sharing straightforward.
- **MeshCat.jl** renders Three.js WebGL scenes in the browser, providing a shared 3D viewport that Pluto embeds natively in cells.
- **Fast Feedback Loop:** Moving a slider triggers a fast static settle solver (`settle_to_operational_state`) under wind load, updating ring/tether/blade geometry and HUD safety metrics (FoS, buckling utilization) in real-time.
- **Performance Guard:** Added a checkbox to toggle dynamic time-domain ODE simulations (2s duration), preventing slider drag lag while still enabling playback animation of transient torsional oscillations.

**Status: Completed.** Resolved several environment initialization and execution errors:
- **Manifest Cell Collision Fix:** Discovered that Pluto reserves the zero-UUID cell `# ╔═╡ 00000000-0000-0000-0000-000000000002` for internal `PLUTO_MANIFEST_TOML_CONTENTS`. Writing custom environment initialization code (like `Pkg.activate`) inside it causes Pluto to overwrite and delete it on save. Resolved by moving the environment initialization block to a custom cell UUID (`c9092282-...`), which Pluto respects and persists.
- **Duplicate Imports:** Removed redundant local `using Printf` statements inside `let` blocks. Since the initialization cell now runs successfully first, the top-level `using Printf` is available globally, and removing local ones resolved the duplicate import error.
- **PlutoUI Widget Naming:** Restored `@bind run_dynamic CheckBox` (uppercase B), which is the correct exported widget name in PlutoUI (lowercase casing was incorrect).
- **geometry.jl API Alignment:** Fixed arguments in `attachment_point` calls in the telemetry HUDs to remove an extra `j+1` argument, matching the 7-argument signature in `src/geometry.jl`.
- **structural_safety.jl API Alignment:** Updated `ring_safety_frame` calls to include the nominal state vector `u0_custom` as the second argument, matching `src/structural_safety.jl:72`.
- **FoS Reduction:** Replaced the invalid field access `sf.min_column_fos` with `minimum(f.fos for f in sf; init=Inf)` to correctly extract spacer ring buckling safety margins.
- **Headless-safety:** Wrapped the reactive `run_dynamic` variable in a `try...catch` block in the simulation cell to prevent `UndefVarError` when evaluating the notebook headlessly.

