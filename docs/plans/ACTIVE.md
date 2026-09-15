# ACTIVE.md — the current priority list

**Single source of truth for what we are doing next.** Supersedes the priority
lists inside every handover (including the 2026-09-14 handover §12). One item per
session. If a session's work is not the current item, it is a detour and should
be named as one.

Last updated: 2026-09-15.

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

**Work in order:**

1. **The offset question is settled — no re-run needed.** `physics-topology.md:139`
   records the derived offset as 3.99 m at a 2.4 m top-ring radius, which is the
   5 kW seed. So the 09-13 taut/slack numbers were taken at the correct geometry
   for this seed and they stand. (The placeholder defect was applying 3.99 m to
   *every* genome regardless of radius, not the value itself.)
2. **Model the back line as taut at the design point** and re-derive the load
   split from that. Expect the realisability floor to bind. If it does, the fix is
   a design change — see the lever below — not a return to slack.
3. **Rigging (Rod, 2026-09-15):** the back line is soft through the climb and
   engages at the target elevation (normally 30°). So at the design point it is
   taut but only just engaged, carrying residual tension. The code models a rigid
   catenary (`EA_back_line = 314 kN`, `parameters.jl:384`) with no elastic. The
   band length/stiffness that sets how sharply it engages is **still to be
   specified**; carry it as a parameter if no field figure exists.
4. **Design lever if the floor binds: lower the lift-line elevation, not the
   margin.** 70° → 65° raises the downwind force at the sky anchor by 28% for a
   3.7% rise in lifter tension, and most of it lands on the shallow cyan line —
   which is what raises bearing preload. Raising the margin 1.5 → 1.6 costs 6.7%
   on every component and scales the lifter stack. See `DECISIONS.md`
   [2026-09-15]. Magnitudes to be re-run on the seed geometry before use.

**Done when:** the load split is re-derived with a taut back line at the derived
offset, and the back-line model used matches the field rigging.

**Back-line spec (Rod, 2026-09-15).** 5 kW system: **3 mm Dyneema**, with **8
sections of 4 mm bungee sewn in series** along the line. Each bungee rests at
30 cm and is at **40 cm at full backline tension**; as tension drops those 8
sections contract and shorten the line by up to **8 × 10 cm = 80 cm**. The
bungees do **not** add extension to the Dyneema — the Dyneema does not stretch.
The bungee is the only compliance, and it is what gives the line 80 cm of soft
travel. At full tension the Dyneema is taut and the line is at its hard length.

- Model: a **bi-linear, tension-only element**. Soft over 0–80 cm of extension,
  stiffness `k_soft = T_design / 0.8` N/m — 8 springs in series, each carrying the
  full line tension and stretched 10 cm at design, so **no extra field data is
  needed**. Hard beyond that at the Dyneema's `EA ≈ 707 kN`. The design tension is
  itself the unknown being solved, so this is a self-consistent iterate.
- The code today is a **single rigid catenary** (`ring_forces.jl:510`) with no
  bungee. `EA_back_line` is 314 kN (labelled 2 mm) at Daisy scale and 700 kN
  (3 mm) in the 10 kW set (`parameters.jl:384`, `:305`); the 5 kW value must be
  set to the 3 mm figure.
- Consequence for the ruling: at the design point the line sits at its **hard
  length** — bungee fully extended, Dyneema taut — which is exactly "taut at
  design". The 80 cm of soft travel is what lets it slack off-design, and the
  hard length is what caps the sky anchor's altitude.

**Latent trap in the bearing offset — fix before banked main rotors land.**
`bridle_bearing_offset` is called from three places (all `initialization.jl`):
construction at `:191` from `ring_radii[end]`; design preload at `:946` and settle
placement at `:1478` from `sys.effective_radii[hub_ri]`. They agree **today only
because `effective_radii` is a copy of the nominal radii** (`:270`) and the
per-step expansion update was removed on 2026-06-14 (`ring_forces.jl:335`). The
re-seed candidate carries a **banked main rotor**, at which point `effective_radii`
must start differing from the nominal radius and the bearing node will be built at
one offset while the preload and settle assume another. Single-source the offset.

**Result (2026-09-15, `scratch/taut_backline_angle_sweep.jl`).** The closed form
reproduces the 09-13 record exactly (taut `T_top` 1149.8 N vs 1150.0; slack
1344.7 N exact), so the chain is validated before any of it is read.

- **At the design point (lift 70°, back line taut): `T_top` = 1149.8 N and
  `demand` = 1.147** — past the torsional cliff (1.0), not merely inside a thin
  margin.
- **The floor at this operating point computes to 1388.2 N, not the 1274.47 N on
  the record** — an 8.9 % discrepancy, unresolved. It moves the clearing angle, so
  trace it before quoting either number.
- **The lift-angle lever works, monotonically and asserted:** `T_cyan` rises and
  `T_back` falls as the angle drops.
- **Clears the floor at el ≤ 50°; the back line slacks at el ≤ 30° → valid band
  31°–50°, 19° wide.** At 65° it is still 185 N short, so "slightly" is not
  enough — the change is ≈ 20°.
- Cost at 50°: `T_lift` 563 N vs 459 N (+23 %); `T_back` 228 N vs 351 N.
- **Off-design (bungee):** `k_soft` = 439 N/m over the 0.80 m; at design the line
  sits exactly at its hard stop, so any lift reduction moves it into the soft
  region. It stays taut down to ≈ 0 lift, then goes slack and the cyan line alone
  carries.
- **Two preload levers that do not touch the lift line: `n_lines` (x[4]) and
  `target_Lr` (x[3]).** Measured on a 3 × 3 grid
  (`scratch/levers_linecount_ringdensity.jl`). Worst realisability demand at the
  design preload, ✓ = at or under the 0.952 target:

  | lines \ L/r | 2.0 | 1.5 | 1.2 |
  |---|---|---|---|
  | 6 | 1.147 ✗ | **0.871 ✓** | 0.697 ✓ |
  | 8 | 1.005 ✗ | 0.764 ✓ | 0.612 ✓ |
  | 10 | 0.890 ✓ | 0.677 ✓ | 0.543 ✓ |

  **Both analytical predictions made for this were wrong, and the measurements
  say why:**
  - **`target_Lr` is the clean lever.** The floor scales *exactly* with it —
    1388 / 1050 / 840 N at L/r 2.0 / 1.5 / 1.2, ratios 0.757 and 0.605 against
    0.75 and 0.60. Demand ∝ chord, as the formula gives. Lower L/r ⇒ more rings
    (n_seg 8 → 12 → 17) ⇒ shorter chords.
  - **`n_lines` does NOT reduce demand at fixed tension.** The floor sits at
    ~1389 N at 6, 8 *and* 10 lines. The bridle-term cancellation is algebraically
    real, but whatever cancels the `1/n_lines` in `τ_max` cancels it too.
    `n_lines` helps only *indirectly*, by changing the design: `T_thrust` rises
    1067.6 → 1205.6 → 1340.4 N and the lifter is sized to a heavier machine, so
    `T_top` rises 1149.8 → 1316.4 → 1489.5 N.
  - **Cleanest single fix: 6 lines at L/r 1.5 clears** — no extra lines, no
    lift-angle change, no extra back-line duty. Cost: n_seg 8 → 12, i.e. 50 %
    more rings (mass, drag, complexity).
  - **`T_thrust` moves with `n_lines` because the *rotor* does**: `R_rotor`
    3.6572 → 3.7679 → 3.8704 m and `A_sw` 31.14 → 34.27 → 37.22 m². Mechanism
    identified; a design coupling, not a physics bug.
  - **MASS — and it reverses the ranking.** L/r is near mass-neutral: at 6 lines,
    L/r 2.0 → 1.5 moves airborne mass 29.31 → 29.22 kg (**−0.3 %**) for a floor of
    1388 → 1050 N. `n_lines` is the expensive one: 6 → 10 lines is 29.31 → 64.48 kg
    (**+120 %**) for a floor of 1388 → 1390 N. **So pull L/r, not lines.** (Ring
    mass +3.4 % for +50 % rings — the closed-form sizing makes each ring lighter
    as spans shorten.) Via `scratch/diag_floor_mass_and_thrust.jl`.

**Realisability floor — the 1388 vs 1274 N question is RESOLVED.**
`docs/plans/2026-09-11-settle-ode-coherence.md` §2.4.1 holds **T_top ≥ 1274.47 N**
at `sin Δα ≤ 1` (the cliff). The code's floor is at `demand ≤ 1/1.05`
(`TRPT_REALISABILITY_TENSION_MARGIN = 1.05`). Measured: margin 1.00 → **1321.31 N**,
margin 1.05 → **1388.18 N**, ratio **1.0506 = exactly the margin**. The residual
3.7 % against 1274.47 N is the axial profile — the plan used **15.613 N/segment**,
the code uses **3.903 N** (`p.m_ring = 0.7958 kg` against the plan's implied
≈ 3.18 kg; ring mass moved during the mass-model audit). Two criteria and a stale
ring mass, **not a contradiction**.

**Still open for Rod:** the 5 % margin absorbs only ≈ +5 % torque, and the wind-up
transient (rotor descending as the twist engages, power and torque rising) eats
exactly that margin. Raise the margin, or gate on measured peak `demand`.

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
- [ ] Back-line contradiction resolved (item 2).
- [ ] Load split re-derived (item 2).
- [ ] V2 / V3 / V6 promoted.

Plus the wobble gate, evaluated at the design operating point over ≥ 120 s with
only justified damping active:

- [ ] No line above the ground ring goes slack through the excursion.
- [ ] FoS ≥ target at the **cycle peak**, not the mean.

## Noted for later (Rod, 2026-09-15)

Levers against gust demand on the torsional margin, roughly cheapest first:

1. **Raise `TRPT_REALISABILITY_TENSION_MARGIN` a few percent** above 1.05. Cheap
   and immediate; it buys torque headroom directly, at the cost of preload and
   therefore lifter tension. Document the chosen margin and what it is sized
   against.
2. **A generation governing routine** — back the torque demand off when the
   transient asks for more twist than the shaft can deliver, rather than relying
   on a static margin.
3. **Backline release / rotor tilting** — let the machine tilt or pay the back
   line out to shed the transient instead of absorbing it.

4. **Realisability margin vs gust transient** — aspirational, further down the
   road: record the torque margin a gust actually consumes. The 5 % steady margin
   does not cover the wind-up transient (rotor descending as the twist engages,
   torque rising). Cross-logged in `docs/lift/README.md`.

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
