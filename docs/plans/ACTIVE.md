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

### ▶ 2. Resolve the back-line contradiction, then re-derive the load split — NEXT

**Rod's ruling (2026-09-15): at the design point the back line is NOT slack.** It
resists the resultant forces at the sky anchor and carries residual vertical
tension, because the lift line over-lifts (1.5 × airborne weight). It may go
slack in operation when wind or lift drops. That is an off-design state, not the
design point.

**Why this is a live conflict, not a stale note.** The ruling agrees with the
2026-09-12 standing rulings ("the backline is an altitude limiter, partially
elasticated in the field. **It takes the lift surplus — confirmed by
measurement**") and with the taut-chain invariant, which is also in `AGENTS.md`.
But the **live code implements the opposite**:
`design_axial_preload`'s docstring says the back line "is an altitude limiter and
is slack at the design point" (`initialization.jl:1053-1054`), and 2026-09-13 §4
chose slack deliberately, because a **taut** back line drops `T_top` to 1150 N,
below the 1274.47 N torque-transmission floor — i.e. the design stops being
realisable. So the taut/slack choice is not cosmetic: it decides whether the seed
can transmit its rated torque at all.

**Measured, not assumed:** at a 3.99 m bearing offset, taut → `T_top` = 1150.0 N
(unrealisable, −124.5 N); slack → 1344.7 N (realisable, +70.2 N)
(`scratch/design_chain_preload.jl`, 2026-09-13 §4).

**Status (2026-09-16).** Two of the four pieces are done and committed. What
remains is the **bungee remit** and one rigging figure. Do not re-do 1 or 2.

1. ✅ **The offset question is settled, and the derivation has landed in source.**
   `2d6233b` removed `BEARING_OFFSET_DESIGN` and made `bridle_bearing_offset(r_top)
   = r_top / tand(31°)` (`initialization.jl:21`) the single authority. Every call
   site derives it (`:191`, `:950`, `:1483`, `ring_forces.jl:524`). `7fa059e`
   removed the two `effective_radii` branches, so the cone reads the topmost ring's
   resting radius everywhere. The remaining `effective_radii` reads are the
   expansion-rotor paths, which is correct. The change preserves behaviour today.
   Construction now closes the latent trap, so convention no longer holds it shut.
2. ✅ **The taut load split is measured where the ruling needs it.** The closed form
   reproduces the 09-13 record exactly (taut `T_top` 1149.8 N vs 1150.0, slack
   1344.7 N exact), so the numbers stand at this seed's geometry. At the design
   point (lift 70°, taut) `demand` = **1.147** against a 0.9524 target. That is past
   the torsional cliff, not inside a thin margin. The floor computes to
   **1388.2 N**, not the record's 1274.47 N. Two criteria and a stale ring mass
   explain that 8.9 % gap (§7 of the 2026-09-15 handover), so quote 1388.2 N.
3. ▶ **The bungee remit: model the back line as the field rigging describes it,
   then re-derive the load split from that. OPEN.** `grep -i bungee src/` is empty.
   The code is still a single rigid catenary (`ring_forces.jl:510`), the sky-anchor
   solve is still **slack** (`initialization.jl:958`), and the docstring still says
   the line "is slack at the design point" (`:1053-1058`). The ruling contradicts
   all three. This is the dominant gap. Until the taut bi-linear element is in
   `src/`, no evaluator run reflects the ruling.
4. ○ **Rigging engagement (Rod, 2026-09-15):** soft through the climb, engaging at
   the target elevation (normally 30°), so at the design point it is taut but only
   just engaged. The band length and stiffness that set how sharply it engages are
   **still to be specified**. Carry them as parameters if no field figure exists.
   This is the one figure the bungee remit needs from outside the model.

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

Effect on the suites:

- **Acceptance 4/8 -> 5/8.** `test_evaluator_v13` flips FAIL -> PASS. So the
  re-seed buys **one of the four**. The three that remain have THREE DIFFERENT
  causes and no single fix (corrected 2026-09-16; they are not one problem):

  | test | failure | what it is |
  |---|---|---|
  | `test_gate_v13` | A5: a broken-line machine must hard-reject | the gate is **not latching a rope break**. A safety-detector defect, not power or realisability |
  | `test_settle_lowk_honest` | `status = reject`, `P_end = 0.0` | the low-k path rejects |
  | `test_physics_path_ode` | P1: seed not healthy under DEFAULT physics | the default-physics path |

  The last two are plausibly realisability/settle related; **A5 is not**, and I
  previously conflated all three. Each needs its own diagnosis.
- **Fast suite stays 2139 pass / 0 fail / 1 broken.**

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

**Files (2026-09-16).** `ring_forces.jl:510` (rigid catenary, no bungee),
`initialization.jl:958` (sky-anchor solve still slack),
`initialization.jl:1053-1058` (docstring says "slack at the design point"),
`parameters.jl:384` (`EA_back_line` still 314 kN, labelled 2 mm). All four must
change together. A partial edit leaves the ruling in the docs and not in the code.

### 3. Finish the static equilibrium solver (dynamic relaxation)

The settle *places* the machine and relaxes it briefly; it does not solve for
equilibrium. That is why the hub and sky-anchor force residuals and the
first-frame acceleration still fail, and why the re-seed candidate cannot land
(2026-09-14 handover §6.4).

Method: dynamic relaxation with kinetic damping (Barnes) on the existing force
evaluator. Prototype in `scratch/` first, against one known settle, with the
three failing assertions in `test/test_settle_validity.jl` as acceptance.

Discipline that makes or breaks it:

- Call the force path with velocities zero, so the rope material damper and the
  aerodynamic drag vanish and the force field is conservative. Do **not** reuse
  `multibody_ode!` wholesale.
- Scale the fictitious mass per degree of freedom (≈ local stiffness). Degrees of
  freedom span 1e-3 m rope motions to 1 m bow motions; uniform mass will crawl.
- A global sideways move of the ring stack is very stiff (0.5 m → 204 kN,
  k ≈ 3.5e5 N/m). The bow is *not* a translation — it is a rearrangement in which
  the lines reorient at near-constant length. An unconstrained local step sees a
  spurious energy barrier. Keep the step near the constant-transmission-length
  manifold.
- The 2026-09-13 probe that ran 2 M steps used viscous relaxation. Kinetic
  damping is the specific reason to expect a different outcome — not a guarantee.

**Done when:** `test/test_settle_validity.jl` passes, and the settle and the ODE
agree on the bowed shape.

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

- [ ] Acceptance suite 8/8, **unrebased**.
- [ ] Back-line contradiction resolved (item 2). **Ruled 2026-09-16: the line is
  taut and bi-linear. The code change is the bungee remit.**
- [ ] Load split re-derived (item 2). **Not yet. This needs the taut element in
  `src/` and the static solver.**
- [ ] V2 / V3 / V6 promoted.

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
