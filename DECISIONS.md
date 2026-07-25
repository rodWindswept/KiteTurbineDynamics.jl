# DECISIONS.md — KiteTurbineDynamics.jl

Running log of architectural and physical decisions. One entry per decision, newest at top.
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
