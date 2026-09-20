# ACTIVE.md — the current priority list

**Single source of truth for what we are doing next.** Supersedes the priority
lists inside every handover (including the 2026-09-14 handover §12). One item per
session. If a session's work is not the current item, it is a detour and should
be named as one.

Last updated: 2026-09-16.

## Standing rules

1. **Every damper in the model must be justified.** No unexplained stabilisers on
   the load path. `lin_damp` survives only as a declared, pinned numerical
   stabiliser — never as a load-shaping knob. See `DECISIONS.md` [2026-09-15].
2. **Campaigns run behind the exit gate**, not before it.
3. **A probe that does not assert is not cited.** Numbers lifted from
   `scratch/` without an assertion do not enter a decision.
4. **Re-derive nothing about the structure.** Run the pre-flight checklist in
   `docs/agents/physics-topology.md` before geometry, tension or load-path work.

## Sequence

### ✅ 1. Land the six-week-review rulings — 2026-09-15

Three rulings recorded in `DECISIONS.md` [2026-09-15]: 5 kW design first; bow is
an output not a constraint; wobble is gated. Damping inventory source-verified and
the four mislabelled `# bearing damper retention factor` comments corrected.

### ✅ 2. Resolve the back-line contradiction, then re-derive the load split — LANDED 2026-09-20

**Rod's ruling (2026-09-15): at the design point the back line is NOT slack.** It
resists the resultant forces at the sky anchor and carries residual vertical
tension, because the lift line over-lifts (1.5 × airborne weight). It may go
slack in operation when wind or lift drops. That is an off-design state, not the
design point.

**Why this was a live conflict.** The live code previously implemented the
opposite (`design_axial_preload` docstring said the back line was "slack at the
design point", projecting sky forces onto the cyan line).

**Status: LANDED 2026-09-20.** Both halves are complete and verified across both
suites (Fast 2149/2149, Acceptance 8/8):

1. ✅ **The offset question is settled:** `bridle_bearing_offset(r_top) = r_top / tand(31°)`.
2. ✅ **The bungee element has landed (`21cf73b`):** Bi-linear, tension-only element
   `back_line_tension` with `EA_back_line` = 700 kN (3 mm Dyneema).
3. ✅ **Taut 2×2 load split landed (`src/initialization.jl`):**
   `_sky_anchor_taut_split` calculates the exact 2×2 planar balance of the lift,
   back, and cyan lines. Closed-form circle intersection (`_sky_anchor_design_pos`)
   places the sky anchor within 6.4 mm of settled equilibrium.
4. ✅ **Calibrated operating tension:** `BACK_LINE_T_DESIGN_N = 320.0 N`, giving
   `k_soft = 400.0 N/m` over 0.80 m soft travel, landing precisely on the hard stop
   at operating equilibrium (measured settled back line: 319.90 N).
5. ✅ **Pre-placement at contracted hub:** Settle places the machine first, then
   sizes preload and lift-chain geometry from the contracted hub `ctrs[Nr]`.
6. ✅ **Discrete geometric crossing limit enforced:** `design_axial_preload` and
   settle closure enforce both continuum demand cliff and geometric crossing limit
   `δα* = 2·asin(L/√(2(L²+2r²)))`.
7. ✅ **Polish DR retuned:** `OPERATIONAL_POLISH_DT = 5e-5` (80 000 iters) reliably
   converges across the non-smooth bi-linear hard stop.

**Bungee remit - definition of done.** The back line becomes a **bi-linear,
tension-only** element. It stays soft over 0-80 cm of extension at
`k_soft = T_design / 0.8` N/m (8 bungee sections in series, each carrying full line
tension and stretched 10 cm at design, so **no extra field data is needed**). It
goes hard beyond that at the Dyneema `EA ≈ 707 kN` (3 mm). At the design point the
line sits at its **hard length**: bungee fully extended, Dyneema taut. That is
exactly "taut at design". The 80 cm of soft travel is what lets it slack
off-design. The design tension is itself the unknown in the solve, so this is a
**self-consistent iterate**. It cannot close before the static solver lands
(item 3), because the iterate needs an equilibrium the settle does not yet produce.
`EA_back_line` (`parameters.jl:384`, currently 314 kN labelled 2 mm) must carry the
3 mm 5 kW figure.

The probe measures `k_soft` = **439 N/m** over the 0.80 m off-design, consistent
with `T_design / 0.8`.

**Elevation is the expensive lever, not the clean one.** Lowering the lift-line
elevation raises the downwind force at the sky anchor by `cot(el)`, and that force
lands on the shallow cyan line as bearing preload. 70° → 65° is +28 % for a 3.7 %
rise in lifter tension, and the cyan line reaches ≈ 2.31× its 70° duty at 50°. The
2026-09-15 record treated this as the lever of first resort. The measured floor and
mass numbers below reverse that ranking. **Pull `target_Lr` first. Hold the
elevation lever for the case where L/r alone cannot clear.** See `DECISIONS.md`
[2026-09-15]. Magnitudes to be re-run on the seed geometry before use.

**The elevation band is a budget increase, not a clean fix.** `T_cyan` rises and
`T_back` falls monotonically as the angle drops. The floor clears at el ≤ 50° and
the back line slacks at el ≤ 30°, so the valid band is **31°-50°, 19° wide**. At 65°
the design is still 185 N short, so "slightly" is not enough. The change is ≈ 20°.
However, that clearing is paid for, not solved. At 50° `T_lift` is 563 N against
459 N (**+23 %**) and the cyan line carries **≈ 2.31×** its 70° downwind duty. The
**clean** fix is `target_Lr` (x[3]), which scales the realisability floor **exactly**
with the chord: 1388 / 1050 / 840 N at L/r 2.0 / 1.5 / 1.2. At 6 lines, L/r 2.0 →
1.5 moves airborne mass 29.31 → 29.22 kg (**−0.3 %**), because the closed-form
sizing makes each ring lighter as spans shorten. **So pull L/r. Treat the band as
the fallback if L/r alone ever proves insufficient.** The two have never been
measured together. Ring count rises 8 → 12 → 17, which is +50 % rings at L/r 1.5.

`n_lines` (x[4]) is **not** a lever for demand. The floor sits at ~1389 N at 6, 8
and 10 lines. It changes the design indirectly, because the *rotor* grows with it
(`T_thrust` 1067.6 → 1205.6 → 1340.4 N). It is also the expensive axis: 6 → 10
lines is 29.31 → 64.48 kg (**+120 %**). Detail: 2026-09-15 handover §7.

**The re-seed is APPLIED (2026-09-16, `04a31bf`).** `seed_genome(5.0)` now carries
`g[3]` target_Lr **1.5**. Measured: `status=ok`, `P_end` **5.1465 kW**, `FoS`
2.599, `twist_crossed=false`, 13 rings, lift chain connected (T_cyan 349.0 N,
T_bridle 67.6 N).

> **CORRECTION (2026-09-16, later the same day). The `FoS` 2.599 in that record is
> VOID.** It was measured with the **unscaled 0.003 m tether**, whereas every
> campaign and gate path sets `tether_diameter = p_base.tether_diameter`
> (scaled, **0.003651 m**; `run_v13_5kw.jl:71`, `run_v13_5kw_masslift.jl:179`).
> `test_physics_path_ode.jl` was the outlier that omitted it. Re-measured on the
> honest line (`scratch/diag_p1_tether_kick.jl`): 0.003 m + `kickstart_s=2.0`
> gives FoS 2.054 (reject); 0.003 m + `kickstart_s=0.0` gives **2.599, status ok**
> — the recorded figure exactly; the scaled line gives **1.506 to 1.547, reject**.
> So the record describes a machine with a thinner line than the protocol
> requires. Do not quote 2.599. See the sizing-model entry below and
> `DECISIONS.md` [2026-09-16].

Effect on the suites:

- **Acceptance 6/8 -> 8/8 (2026-09-16).** All eight files green, including the two
  that carried the FoS-floor defect (`test_physics_path_ode` P1, 5 s window, and
  `test_settle_lowk_honest` A3, 20 s window). The cause was **not** the sizing
  margin and **not** a profile mismatch: the closed-form ring **load** model was
  3.7x low. `HELIX_LOAD_FACTOR` 0.32 -> 1.2 and `MIN_RING_DO_M` = 10 mm. Detail
  and the measured tables: `DECISIONS.md` [2026-09-16]; probes
  `scratch/diag_margin_fos_components.jl`, `scratch/diag_helix_calibration.jl`,
  `scratch/probe_do_floor_margin.jl`.
- **Fast suite 2144 pass / 0 fail / 1 broken** (was 2139; +5 new assertions).

The earlier 4/8 -> 5/8 note is retained below for the record. Its three-failure
table was superseded the same day by the sizing-model fix above; `test_gate_v13`
A5 was fixed separately by the per-line break-detection work (Concern 0).

**Superseded note (2026-09-16, earlier).** Acceptance 4/8 -> 5/8:
`test_evaluator_v13` flipped FAIL -> PASS, so the re-seed bought **one of the
four**. The three then-remaining were believed to have three different causes and
no single fix:

  | test | failure | what it is |
  |---|---|---|
  | `test_gate_v13` | A5: a broken-line machine must hard-reject | the gate is **not latching a rope break**. A safety-detector defect, not power or realisability |
  | `test_settle_lowk_honest` | `status = reject`, `P_end = 0.0` | the low-k path rejects |
  | `test_physics_path_ode` | P1: seed not healthy under DEFAULT physics | the default-physics path |

  The last two are plausibly realisability/settle related; **A5 is not**. The
  diagnosis above corrected this: the last two were one cause (the load model),
  and A5 was a third, separate one. Fast suite then: 2139 pass / 0 fail / 1 broken.

Landing it green needed two fixes that are worth keeping in mind:

1. **`test_trpt_realisability.jl` was coupled to the campaign seed.** It
   reproduces independently measured numbers (2026-09-13 handover: binding segment
   4, `demand[1]` ~ 0.974, twist 79.4°), but built through `build_case` ->
   `seed_genome`. Re-seeding moved the binding segment to 8 and turned 13 green
   assertions red for a change that **improved** the design (demand 0.974 ->
   0.7357, twist 79.4° -> 47.7°). It now pins its own frozen genome (`SEED_LR20`),
   a fixture that must NOT be updated when the campaign seed moves. 26/26.
2. **The settle horizon is not universal.** `test_settle_validity` reads the hub
   residual at 66.9 N at `n_op = 50_000` on the 13-ring seed where the 12-ring
   seed read 45.0 N. Measured: 66.9 / 52.33 / 43.54 / 41.71 N at 50 k / 150 k /
   300 k / 600 k, so it is convergence-limited with a floor near 42 N. The test now
   uses 300 000 (reads 47.5 N). **This is a workaround, not a fix** — the residual
   is the handoff imbalance the static solver exists to remove.

**Realisability floor — the 1388 vs 1274 N question is RESOLVED.**
`docs/plans/2026-09-11-settle-ode-coherence.md` §2.4.1 holds **T_top ≥ 1274.47 N**
at `sin Δα ≤ 1` (the cliff). The code's floor is at `demand ≤ 1/1.05`
(`TRPT_REALISABILITY_TENSION_MARGIN = 1.05`). Measured: margin 1.00 → **1321.31 N**,
margin 1.05 → **1388.18 N**, ratio **1.0506 = exactly the margin**. The residual
3.7 % against 1274.47 N is the axial profile — the plan used **15.613 N/segment**,
the code uses **3.903 N** (`p.m_ring = 0.7958 kg` against the plan's implied
≈ 3.18 kg; ring mass moved during the mass-model audit). Two criteria and a stale
ring mass, **not a contradiction**.

**Ruling (2026-09-16): gate on the measured peak demand. Do not raise 1.05 to cover
the transient.** The margin and the wind-up transient are different quantities at
different phases. The margin is a *steady-state* realisability criterion
(`sin Δα ≤ 1`), not a transient allowance. The measurement also supplies the basis
that the margin must be documented against. Details in the wobble-gate section
below.

**Back-line spec (Rod, 2026-09-15).** 5 kW system: **3 mm Dyneema**, with **8
sections of 4 mm bungee sewn in series**. Each bungee rests at 30 cm and sits at
**40 cm at full backline tension**. As tension drops, those sections contract and
shorten the line by up to **8 × 10 cm = 80 cm**. The bungees do **not** add
extension to the Dyneema, which does not stretch. The bungee is the only
compliance. At full tension the line is at its hard length.

**Measured** (`scratch/taut_backline_angle_sweep.jl`). The lift-angle lever works
monotonically (asserted). Off-design the line stays taut down to ≈ 0 lift, then
goes slack and the cyan line alone carries.

**Files — state at 2026-09-16 (CORRECTED; the earlier list was stale).**
`ring_forces.jl:544` — bi-linear bungee element, **LANDED** (`21cf73b`).
`parameters.jl:305` — `EA_back_line` = **700 kN**, the 3 mm figure,
**LANDED**; `:389` keeps 314 kN as the correct 1.5 kW base, because `mass_scale`
multiplies it. `initialization.jl:1026` — sky-anchor balance **STILL SLACK**,
now explicitly DEFERRED. `initialization.jl:1125-1133` — the docstring records
the deferral instead of asserting slack is correct. So the element half is DONE;
the balance half is blocked on item 3, which is why item 3 comes next.

### 3. Finish the static equilibrium solver (dynamic relaxation) — ✅ LANDED 2026-09-19

**Status 2026-09-19: LANDED.** The solver is `_polish_operational_equilibrium!` in
`src/initialization.jl`, run as the final pass of `settle_to_operational_state`
(`operational_polish=true` by default, on both the lift and the legacy paths).
Barnes kinetic damping, per-node fictitious mass from local stiffness, positions
only; `omega` and `alpha` asserted untouched. Cost **+1.7 %** on a 300 000-step
settle. V6 is promoted and the fast suite is 100 % green with 0 broken.

**THE FORCE PATH IS THE FULL HANDOFF PATH, NOT THE DRAG-FREE ONE — the prototype's
prescription was superseded and its premise falsified (Rod, 2026-09-19).** The
prototype relaxed with the node translational velocities zeroed. That meets the
drag-free metric (284.5 → 71.4 m/s²) but makes the state the ODE actually receives
**worse**, because applying the orbital velocity at handoff injects the drag as an
unbalanced shock. Measured, same settled state, both variants converged, 20 000
iterations (`scratch/probe_dr_variants.jl`):

| variant | drag-free acc0 | handoff acc0 | V2 hub axial |
|---|---|---|---|
| no polish | 284.5 (29.0 g) | 17 468 (1781 g) | +14.5 N |
| drag-free DR (the prototype) | 71.4 (7.3 g) | 18 610 (worse) | +162.3 N |
| **drag-included (landed)** | 17 681 (1802 g) | **293 (29.9 g)** | **−2.65 N** |

The drag was removable because it was **unbalanced**, not because it was an
operating-point force already in balance: the [2026-09-16] claim that "no
equilibrium solver could have removed that" is false. The landed polish re-derives
the orbital velocity field each iteration and balances the FULL field (gravity,
rotor thrust/torque, elastic tension **and** steady-state spinning-cable drag),
removing 98.3 % of the first-frame acceleration and balancing the hub axially to
under 3 N. Full entry: `DECISIONS.md` [2026-09-19].

V6 now gates on the STRUCTURAL nodes (< 10 g; measured 7.53 m/s², 0.77 g) plus the
largest unbalanced node FORCE (< 200 N; measured 89.6 N). The raw per-node
acceleration is reported but not gated — near the floor its argmax is always the
2.25 g cable node, so a ~0.7 N residual reads as ~300 m/s².

**An equilibrium-side realisability guard is IN (Rod, 2026-09-19).** The settle
measures the worst-segment demand at the SOLVED equilibrium and, if past `1/1.05`,
scales the top preload, re-places and re-runs **only the DR**
(`polish_realisability_max_corrections`, default 2). It fires zero times on both
the campaign seed (demand 0.588) and the v13 winner (measured **0.511** — the
≈1.06 that motivated the change was an estimate, and it was wrong).

**B6's apparent failure was a harness bug, now fixed.** The polish looked like it
destabilised the winner into a twist limit cycle (ratio 0.27 → 1.674), but only
because `v13_cfg` left `ObjectiveConfig.tether_diameter` at its **unscaled
0.003 m** default while `gate_design` and every campaign path use the scaled
**0.003651 m** — B6 and B6b were scoring two different machines, and the 32 %
thinner line is far softer in torsion. `test/test_evaluator_v13.jl` now passes
`tether_diameter=p.tether_diameter`, the same alignment as `7014445`; B6 is `:ok`
(`P_mean` 5.40 kW, `FoS_min` 12.88, `max_ratio` 0.531). `DECISIONS.md`
[2026-09-19].

**REMAINING:**

1. ✅ Port the prototype into `src/initialization.jl` — done 2026-09-19.
2. ✅ Promote V6 — done 2026-09-19 (both assertions are plain `@test`).
3. Re-run BOTH suites. Fast suite green; the **acceptance suite has not yet been
   re-run** on this change and must be before any merge (it touches `src/`
   physics).
4. Item 2's load split below is the remaining physics, and the polish supplies the
   equilibrium it was blocked on. Measured 2026-09-19: the equilibrium tension is
   0.96x–1.32x the design preload per segment, and `demand` at the equilibrium
   tension is **0.588** against the 0.9524 target — so the taut split has real
   headroom, where the 2026-09-13 closed form said it was 124 N short.
5. The other half of the definition of done below — that the settle and the ODE
   agree on the bowed shape. `acc0` alone does not establish it.

The spec that was followed, retained because it is what made it work:

The settle *places* the machine and relaxes it briefly; it does not solve for
equilibrium. That is why the hub and sky-anchor force residuals and the
first-frame acceleration still fail, and why the re-seed candidate cannot land
(2026-09-14 handover §6.4).

Discipline that makes or breaks it:

- ~~Call the force path with velocities zero, so the rope material damper and the
  aerodynamic drag vanish and the force field is conservative.~~ **SUPERSEDED
  2026-09-19** (see the status block above and `DECISIONS.md` [2026-09-19]). The
  landed polish evaluates the FULL handoff field instead — the orbital velocity
  field is re-derived each iteration — because a drag-free equilibrium is not the
  equilibrium the ODE integrates, and relaxing without drag then applying the
  orbital velocity injects the drag as an unbalanced shock. Do **not** reuse
  `multibody_ode!` wholesale as an integrator.
- Scale the fictitious mass per degree of freedom (≈ local stiffness). Degrees of
  freedom span 1e-3 m rope motions to 1 m bow motions; uniform mass will crawl.
- A global sideways move of the ring stack is very stiff (0.5 m → 204 kN,
  k ≈ 3.5e5 N/m). The bow is *not* a translation — it is a rearrangement in which
  the lines reorient at near-constant length. An unconstrained local step sees a
  spurious energy barrier. Keep the step near the constant-transmission-length
  manifold.
- The 2026-09-13 probe that ran 2 M steps used viscous relaxation. Kinetic
  damping is the specific reason to expect a different outcome — not a guarantee.

**Done when:** `test/test_settle_validity.jl` passes — ✅ 2026-09-19 — and the
settle and the ODE agree on the bowed shape, which is **still open**.

### 4. Explore the 5 kW design space

The model-space analysis. Run behind the exit gate below.

### 5. 1.5 kW Daisy-scale validation

Before the report, not before the 5 kW work (review recommendation 4 is
reversed).

### 6. Report, then Alicante prep

The Daisy calibration plus the model-admissibility story is the publishable unit.
The end-October Alicante visit stands; prep starts once the 5 kW space has been
explored and openly reported.

## The lift requirement — nail this down (added Rod, 2026-09-15)

**The record for this now lives in `docs/lift/README.md`** — options, methods,
hypotheses, results, conclusions, and the requirements we place on lift systems as
the machine scales. Add entries there; do not re-derive here.

The lift line is a hard-coded assumption: `T_ref = 1.5 · m_airborne · g / sin(el)`
with `el = 70°` (`lift_kite.jl:214-216`). Nothing on the record derives the 1.5,
the elevation, or the envelope they must cover. Define and document:

- **The vertical margin** — what 1.5 × airborne weight is actually for (gusts,
  settle transients, dynamic overshoot), and what it must cover.
- **The elevation** — as a design variable, with the trade below.
- **The tension envelope and rate limits** — flat (`const_tension=true`) vs
  `(v/v_ref)²` scaling, and what the lifter can actually hold.
- **The resulting sky-anchor horizontal duty** — the safety case.

### Elevation is a design trade, not a tuning knob — and it does not load the back line

Holding the vertical requirement fixed at 1.5 × weight, lowering the elevation
raises the lift-line tension as `1/sin(el)` and the **downwind force at the sky
anchor** as `cot(el)`. That downwind force goes into the **cyan line** — the
shallow member — and so becomes *preload in the TRPT*, which is the whole point of
the lever. It does **not** go into the back line: the back line hangs
near-vertically from the sky anchor down to its ground anchor and deals in
vertical tension only. Measured on the seed:

| el | line tension | downwind force at sky anchor | back-line tension |
|---|---|---|---|
| 70° | 1.00× | 1.00× | 1.00× |
| 65° | 1.04× | 1.28× | 0.92× |
| 60° | 1.09× | 1.59× | 0.84× |
| **50°** | **1.23×** | **2.31×** | **0.65×** |
| 40° | 1.46× | 3.27× | 0.39× |

So lowering the elevation *reduces* the back-line load. What it does raise is the
load throughout the lift chain and the shaft — lifter duty, cyan line, bridle
cone, TRPT — which is the trade this item exists to size.

## Concerns

0. **Rope-break detection is per LINE now — landed, with a regression found and
   fixed in the process (2026-09-16).**

   `trpt_seg_map` (`rope_forces.jl:9`) keys on node-id range only, so every line
   in a bay accumulated into ONE slot and the tested strain was the bay
   **average**: an overloaded line diluted by its `n_lines−1` neighbours. Measured
   on the L/r 1.5 seed: per-line peak **0.022492** against a bay average of
   **0.020144** (bay 2, line 3).

   Landed in `ea78651`: per-line `(bay, line)` accumulation, single-line snap, and
   the **bridle cone and cyan line** now monitored (they are not TRPT chains, so
   `for s in 1:(Nr-1)` never watched them and a severed lift chain could not
   disqualify an evaluation). Tracked per bridle line, not summed.

   **Regression I introduced, then fixed (`c38bbf5`).** `ea78651` made
   `run_canonical_sim!`'s `breaks_enabled` default `false` and claimed the gate
   "reaches it through the evaluator". It does not — `ode_gate_v13.jl` calls
   `run_canonical_sim!` **directly**, so the gate silently lost break detection
   and a broken-line machine would have read `ok`: the exact bug A5 guards. The
   window now passes `breaks_enabled=true` (the 10 s relax stays false). Same
   omission audited at `control_map_hunt.jl` and `record_ramp_traces.jl`.

   **A5 re-baselined.** Its `tether_diameter` is a TUNED value, so it now pins a
   frozen genome (`SEED_LR15_FROZEN`) instead of tracking the campaign seed, at
   0.00016 (built ~0.292 mm), plus a **precondition check that the line actually
   broke**. Measured sweep with detection on: 0.00025 no break (the old value,
   premise dead); 0.00020 / 0.00016 / 0.00012 all break and reject. The old A5 was
   passing vacuously after the re-seed.

   Acceptance **5/8 -> 6/8** on this work.

1. **Back-line handling demand and safety.** Rod, 2026-09-15; one of the main
   reasons the **Shell Gamechanger 10 kW automation project was closed**. The back
   line has two jobs beyond carrying the design-point tension:
   - **Containment on TRPT failure** — the anchored back line is what prevents the
     lift line dragging the machinery away, or components flying free.
   - **Tensioned handling** — it carries the machine while raising and lowering it
     in tension, for deployment, recovery, and high-wind / high-altitude stalling.

   So its design load is the worst of **{design point, hoisting, break
   containment, high-wind handling}** — not the 351 N steady figure. **None of
   those cases is quantified yet.** Detail: `docs/lift/README.md`.

## 5 kW campaign exit gate

All four before a campaign launch:

- [x] Acceptance suite 8/8, **unrebased**. **(2026-09-16.)** The acceptance files
  themselves are unrebased. The one fixture that moved is the FAST test
  `test_trpt_realisability.jl`, re-baselined once for the corrected tube mass; its
  design improved on every axis (`DECISIONS.md` [2026-09-16]).
- [x] Back-line contradiction resolved (item 2). **Ruled 2026-09-16: the line is
  taut and bi-linear. The element landed in `21cf73b`.**
- [x] Load split re-derived (item 2). **LANDED 2026-09-20.** Both halves closed:
  **(a) ✅** equilibrium-side realisability guard in the settle, with geometric
  crossing limit; **(b) ✅** taut 2×2 split (`_sky_anchor_taut_split`) and
  circle-intersection sky anchor (`_sky_anchor_design_pos`) in `lift_chain_design`,
  calibrated to 320 N hard stop at the contracted hub.
- [x] V2 / V3 / V6 promoted. **(V6 2026-09-19, redefined on the full handoff path;
  V2/V3 earlier. The suite is 100 % green with 0 broken.)**

Plus the wobble gate, evaluated at the design operating point over **≥ 120 s with
only justified damping active**:

- [ ] No line above the ground ring goes slack through the excursion.
- [ ] FoS ≥ target at the **cycle peak**, not the mean.

**Gate window (ruled 2026-09-16): the 120 s starts after a relax, not at cold
start.** In evaluator terms that means `cfg.relax_s` long enough to discard the
wind-up, with `cfg.window_s ≥ 120`. `objective_evaluator.jl:696` only samples once
`t_cum > cfg.relax_s`, so a short relax measures the startup transient instead of
the operating point. `relax_s` defaults to 10.0 and the wind-up runs ~100 s, so the
relax must rise to at least that.

**Consequence: the gate does not cover the wind-up, and that is now a separate
measurement.** The workstream (`docs/plans/2026-09-10-shaft-windup-workstream.md`)
records the wind-up as "the first ~100 s of every run", with a sustained ≈ 10 s,
± 25 % limit cycle on the transmission-ring load. A post-relax window sees the
cycle but not the spin-up, so:

- Record the wind-up peak demand and the steady cycle peak **separately**, at the
  same operating point.
- The wind-up peak belongs to the **back-line handling cases** in Concerns, since
  it is the same class of transient as hoisting and recovery. It must not be left
  with no owner.
- The "transient" in the wind-up question then means spin-up specifically.

This is also the measurement basis for the margin ruling in item 2. Measure the
peak with `lin_damp = 0.05` and with it disabled. If the peak moves materially, the
gate is instrument-dependent until the `lin_damp` question in
`docs/agents/instrument-trust-log.md` is settled.

## Noted for later (Rod, 2026-09-15)

Levers against gust demand on the torsional margin, roughly cheapest first:

1. **Raise `TRPT_REALISABILITY_TENSION_MARGIN` a few percent** above 1.05. Cheap
   and immediate. It buys torque headroom directly, at the cost of preload and
   therefore lifter tension. Document the chosen margin and what it is sized
   against. **Superseded for the wind-up transient (2026-09-16): gate on the
   measured peak instead. This lever stays available if a *gust* case needs static
   headroom.**
2. **A generation governing routine** - back the torque demand off when the
   transient asks for more twist than the shaft can deliver, rather than relying
   on a static margin.
3. **Backline release / rotor tilting** - let the machine tilt or pay the back
   line out to shed the transient instead of absorbing it.

4. **Realisability margin vs gust transient** - aspirational, further down the
   road: record the torque margin a gust actually consumes. **Partly ruled
   2026-09-16: measure the peak first, then set the margin on it.** The 5 % steady
   margin does not cover the wind-up transient (rotor descending as the twist
   engages, torque rising). Cross-logged in `docs/lift/README.md`.

5. **STE style debt.** `.githooks/pre-commit` runs `ste-lint.py --fail-above 2.0`
   on staged markdown. `DECISIONS.md` sits at **3.34 violations / 100 words**
   (901 items, mostly em dashes and semicolons accumulated over ~3 000 lines), so
   any commit that touches it needs `--no-verify`. Cleaning it is a separate,
   mechanical task and should not be smuggled into a physics commit.

Not for now: the 5 kW space comes first. Recorded so these are not re-derived
later.

## On hold

- 10–50 kW systems — until the 5 kW space is reported.
- Landing the Tveide drag factor (≈ 1.09, measured but not landed) — refines drag
  power; does **not** unblock the wobble, so it is not on the critical path.
- A physically-justified lateral damping mechanism (review option (a)) — a
  research project; not required for the gate.
