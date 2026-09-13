# Handover — settle rebuild: the bow, the guard, and the static solver (2026-09-12, session 2)

**Status:** working tree **CLEAN**, 28 commits ahead of `origin/master`, nothing
pushed (Rod's standing choice).
**The settle is still not valid.** The guard is landed and failing in 5 recorded
places. The static solver's harness is fixed and verified, but the solve does not
converge. The diagnosis of *why* is solid and is the main deliverable of this
session.

Read this file first, then `docs/agents/physics-topology.md` (mandatory before any
geometry/tension/load-path work). The physics sections §3–§9 of
`handovers/handover-2026-09-11-settle-ode-coherence.md` remain valid; its §1/§2 are
superseded. The previous handover
(`handover-2026-09-12-session-state-and-preload-rootcause.md`) is superseded by
this one except for §2 (how to run Julia here).

---

## 1. Running Julia here — unchanged

```bash
scripts/ktd-julia test/runtests.jl            # fast suite, ~2m48s, 2086 pass / 5 broken
scripts/ktd-julia test/acceptance_runtests.jl # acceptance, 8 files, ~18 min
scripts/ktd-julia scratch/<script>.jl         # any probe
scripts/ktd-format                            # JuliaFormatter (Blue)
```

Plain `julia --project=.` **fails** here (stacked-depot problem, not a broken repo).
`/tmp` does **not** persist between shell calls — write logs to
`.julia_depot/logs/` instead. Both have bitten this session.

---

## 2. The headline physics result: the shaft BOWS

This is the finding that reframes everything else, and Rod confirmed it against the
real machine ("a bit of bowing, like catenary sag across the length of the
turbine... not very visible in the 1.5 kW system but is surely there").

On the 30°-tilted axis, gravity splits relative to the shaft:

| component | value |
|---|---|
| along the shaft | 143.2 × sin(30°) = **71.6 N** |
| perpendicular to the shaft | 143.2 × cos(30°) = **124.0 N** |

Note "perpendicular to the shaft" is the **down-slope direction in the shaft
plane**, not horizontal sideways. It makes the column bow.

For the transmission tension to balance the hub's resultant, the column must tilt
out of the design axis by

```
sin θ = 124 / T_transmission ≈ 124 / 1589 = 0.078   →   θ ≈ 4.7°
```

Over the 18.8 m column that is **≈1.5 m of offset at the hub**. So the settle is
*not* looking for the design-axis geometry; it is looking for where a tilted
flexible column hangs. That single fact explains every symptom chased this session:
the multi-million-step settle, the bearing "whipping about", the first-frame jerk,
and why the axial balance closed while the lateral one did not.

**OPEN DESIGN QUESTION:** is ~1.5 m of bow acceptable in a flown machine, or should
the design reduce it (more lines, higher pretension, steeper axis)? Rod's position:
some bowing is inevitable, and if larger turbines genuinely do this he wants to know
it. If the real machine does *not* bow that much, the model's lateral compliance is
wrong and that is a modelling finding, not a solver problem.

---

## 3. Measured facts from this session (all verified, do not re-derive)

| Fact | Value | Evidence |
|---|---|---|
| The lift chain is **disconnected** | bridles 0.0000 N at settle and at all 25 samples of a 6 s run; rest 6.462198 m vs achieved 4.658 m | `scratch/preload_bridle_engagement.jl` |
| Bridle geometry is **right**, the rest length is wrong | 4.658 m 3D at the operating point = apex ~31° from axis / ~59° at the ring plane (Rod: "59 sounds about correct") | `scratch/chain_fix_probe.jl` |
| `bearing_offset = 6.0` is a **placeholder** | never chosen; came from other tested systems. 6.0 m offset *is* a valid equilibrium | Rod 2026-09-12; `scratch/assembly_relax_trial.jl` |
| A **resting state exists** | whole-assembly relaxation converges (1030 → ~10 m/s²) for every bridle length tried | `scratch/assembly_relax_trial.jl` |
| The **backline is the altitude limiter** | goes taut by 0.0072 m and takes the 143 N lift surplus (431 N lift vs 288 N weight) | `scratch/assembly_force_audit.jl` |
| The **axial balance closes** | hub axial residual +66.6 N → −0.32 N when relaxed | `scratch/hub_creep_check.jl` |
| The **lateral** balance is the slow mode | hub sags sideways and keeps creeping | same |
| Bridles carry **~123 N**, not ~431 N | at the 6.0 m offset, i.e. ~29 % of the assumed lift-chain load | `scratch/assembly_relax_trial.jl` |
| All-rotor thrust | main rotor +309 N, expansion ring 8 +914 N, ring 7 +820 N = **2044 N total**. The main rotor is only ~15 % | `scratch/preload_thrust_budget.jl` |
| Top segment is **sound** | stretch 1.0003, tension 264.1 N = design preload (1588.7/6), matching measured torque | `scratch/rope_node_check.jl` |
| Closed form is **dimensionally correct** | true axial torque from ring positions reproduces 377.598 N·m on segments 1–6 | `scratch/preload_torque_dimension.jl` |
| Segments **7 and 8 under-carry torque** | 324.5 and 228.5 N·m against the 377.6 N·m operating torque | same — **open item** |
| Transmission carries **no perpendicular load at rest** | hub perpendicular force = −125.20 N = gravity alone | `scratch/bow_modes.jl` |
| **A global sideways ring motion is STIFF** | 0.5 m move → hub force −125 N → −204,086 N (k ≈ 3.5e5 N/m) because the pinned ground anchor stretches the lines | `scratch/bow_modes.jl` |
| Preload fixed point (corrected sign) | converges in 8 iters to **1155.09 N**, residual −0.0065 N, contraction 0.1949 | `scratch/preload_fixedpoint_conv.jl` |
| Ground ring mass = 1e30 kg | **deliberate** numerical anchor fix; exclude it from mass sums. Real airborne mass 29.31 kg | `scratch/mass_audit.jl` |
| Current `ω_eq` | **12.983466 rad/s** (k=2.24). A run has been observed returning ω = 4.842 — resolve before quoting any torque | this session |

---

## 4. The settle-validity guard — the acceptance test

`test/test_settle_validity.jl`, wired into `test/runtests.jl`. Currently
**2 pass / 5 `@test_broken`** (fast suite: 2086 pass, 5 broken, exit 0).

Definition of a valid settle (Rod, 2026-09-12):

| # | condition | status |
|---|---|---|
| V1 | **rotation present and uniform** — `ω = 12.983466`, spread 0 | **PASS** |
| V1b | **structural** velocity (rotation removed) ~0 | PASS |
| V2 | hub / bearing / sky axial residuals small | **FAIL**: −479.75 / +226.92 / +147.25 N |
| V3 | every line above the ground ring **taut** | **FAIL**: bridles 0.0000 N |
| V6 | smooth handoff — no first-frame jerk | **FAIL**: max node accel 10310 m/s² (~1000 g) |

`@test_broken` is deliberate: it keeps the suite green (AGENTS.md never-commit-red)
*and* **warns the moment an assertion starts passing** — that warning is the signal
to promote the line to `@test`.

**V1 wording trap:** "velocities ≈ 0" means **structural** velocity only. Rotation
must be non-zero (a 0-rpm handoff means no power at the PTO). A node's raw
translational velocity contains `ω × r` ≈ 31 m/s at the hub rim and is *supposed*
to be non-zero.

---

## 5. The static solver — harness FIXED and verified, solve NOT converging

`scratch/static_solve2.jl`. This is where the work stopped.

**Formulation (believed correct):** Newton/LM on the ODE's own force residuals
(node accelerations, mass-scaled to force) and torque residuals (ring angular
accelerations), with the aerodynamics **frozen** (ω at the operating point, kite at
its equilibrium offset). Frozen aero makes this a *structural* solve, not a time
march. A root-find on F(x)=0 is insensitive to how soft the slow lateral mode is,
which is exactly what dynamic relaxation could not handle.

**Verified working** (the script errors out rather than proceeding if any check
fails — this self-checking is the single most valuable thing to keep):

```
R1  residual responds to a perturbation of dof 1     non-zero
R2  residual responds to a hub perturbation          non-zero
    Jacobian max|J| = 1.75e7, all columns non-zero, finite
    column 1 matches a hand-computed difference to 0.0
    LM steps accepted at full step=1.000
    force-based residual (305 N, not 1017 m/s²)
```

**Fixed this session:**

1. `du` was allocated `2N+2Nr` = 328 while the ODE writes to `6N+2Nr` = 948.
2. A variable named `perturb!` was **both an array and a closure**, so
   `perturb!(a,b,c)` parsed as array indexing and every Jacobian column came back
   identical (Jacobian all-zero).
3. A captured/reused `du` buffer made successive residual evaluations return the
   same object. Allocate per call.
4. Forming the **normal equations `J'J`** squares the condition number; with
   `max|J| ≈ 1e7` the bow-carrying directions were lost in double precision and
   every accepted step was ~1.2e-5 m. **Solve the least-squares step by QR** on the
   augmented system `[J; sqrt(λ)I]`, never form `J'J`.
5. **Per-DOF column scaling** is needed: DOFs span 1e-3 m rope motions to 1 m bow
   motions.

**STILL BLOCKING — the diagnosis, which is the real result:**

200 LM iterations moved the hub perpendicular offset only **0.3 mm** against a
required **~1.5 m**, with `||F||_inf` stuck at 251 N and λ oscillating 3e-2…1e-1.

And the cause is now measured, not guessed. From `scratch/bow_modes.jl`, translating
the **whole** ring stack perpendicular to the shaft:

| delta | hub F_perp | k |
|---|---|---|
| 0.01 m | −217 N | 8.1e3 N/m |
| 0.05 m | −749 N | 1.1e4 N/m |
| 0.50 m | −204,086 N | 3.5e5 N/m |

So a global sideways motion is **very stiff**, because the pinned ground anchor means
it stretches the transmission lines. **The bow is therefore not a translation — it
is a large geometric rearrangement in which the transmission lines REORIENT to carry
the perpendicular weight while their lengths stay near-constant.** The intermediate
configurations on that path are heavily stretched, so a local step method sees a
spurious energy barrier and creeps.

**NEXT MOVE (recommended):** constrain the step to stay near the
**constant-transmission-length manifold**, or drive the bow directly by prescribing
the transmission direction and solving for the ring positions along it — rather than
letting an unconstrained local step wander through stretched states. Options:
manifold following, a homotopy/continuation in the applied perpendicular load, or
solving for the ring positions given an assumed transmission axis direction.

**Do NOT repeat:** an earlier version of this session's diagnosis said "slave the
rope nodes to the ring geometry". That was **wrong** and is refuted by the stiffness
measurement above. The free-node formulation is the right model; the step just needs
to respect the near-inextensibility.

---

## 6. Mistakes made this session — recorded so they are not repeated

Every one of these was a harness/instrumentation error that was briefly mistaken for
a physics finding. This is the dominant failure mode of the session.

| # | Mistake | Correction |
|---|---|---|
| 1 | Took the printed spec's fixed-point sign on trust | `T_top -= 0.7·m_hub·a_ax` is **inverted**. The rope hangs below the hub and pulls down-shaft, so `a_ax > 0` ⇒ T_top too LOW ⇒ **`T_top += 0.7·m_hub·a_ax`**. Measured `df/dT = −1.073`, contraction 0.1949 |
| 2 | Reported "velocities ≈ 0" for V1 | Means **structural** velocity; rotation must stay. Raw velocity = `ω × r` ≈ 31 m/s |
| 3 | Claimed rope nodes over-stretched by 1.29 MN | Compared node 137 (line 1) with node 152 (line 6). Measured properly: ratio 1.0003. **Retracted** |
| 4 | Reported a 1e36 kg node mass | Node 1's deliberate **1e30 kg ground-anchor fix**. My sum included the anchor. No force was affected |
| 5 | Hunted a "124 N phantom lateral force" | It is simply **gravity's component perpendicular to the tilted shaft**. And the `hub_perp` column was `norm(d − dot(d,sd)·sd)` with `sd` = the hub's **own** direction — **identically zero**, so it measured nothing |
| 6 | Quoted a lateral stiffness of ~500 kN/m | The probe re-interpolated rope nodes along **straight chords**; the lines are **twisted helices**, so it produced a fake force 5 orders too large. Probe marked INVALID in-file |
| 7 | Four separate harness bugs inside the solver | See §5 items 1–3. Fixed by building a **self-checking** script |
| 8 | Confused a rotor "hub" with the transmission's hub, and used "bridles (cyan lines)" as one thing | See `physics-topology.md` §2: four distinct named links |

**The lesson:** the tools were wrong more often than the physics. Build the check
first — a script that refuses to proceed unless its own sanity assertions pass.

---

## 7. Documentation landed this session (do not re-create)

- **`docs/agents/physics-topology.md`** (NEW, mandatory pre-read) — the four named
  links with endpoints, the load path, the taut-chain rule, bridle geometry and the
  angle convention, the backline as altitude limiter, the per-ring rotor-model rule,
  an 8-point pre-flight checklist, the silent-truncation catalogue, measurement
  traps. Referenced from `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`,
  `docs/agents/domain.md`, `instrument-trust-log.md`, `stale-phrases.md` and
  `scripts/doc_currency_check.py`.
- **`CONTEXT.md`** — the structure diagram was **wrong** (it showed the lift line
  going straight into the lift bearing with no sky anchor, backline or bridles) and
  is corrected. Vocabulary extended with every line name.
- **`docs/agents/domain.md`** — quick-start fixed (`scripts/ktd-julia`, not
  `julia --project=.`), 8 new gotchas.
- **`docs/agents/instrument-trust-log.md`** — 9 new fault-ledger rows; header drift
  fixed; the stale-phrase scan made precise (skips prohibitions/history, strips
  markdown emphasis, reports line numbers) and now scans the topology page.
- **`DECISIONS.md`** — a 2026-09-12 entry recording Rod's rulings (below).

---

## 8. Rod's rulings recorded 2026-09-12

1. **Naming.** The topmost rotor is the **main rotor**. "Hub rotor" is retired.
   Everything below it is the transmission for its torque.
2. **Any rotor may be a banked-blade expansion rotor, including the main rotor.**
   Where banked blades are fitted, the banked-blade expansion model **REPLACES** the
   cp/ct disc model at that ring — never both. This **supersedes the 2026-08-22 hub
   exclusion**. Still **not implemented** (see §9).
3. **The lift chain is always in tension**, providing 1.5 × airborne weight
   vertically at the lift bearing throughout operation. The topmost kite is launched
   first, pulls the rig into a tensile state, and that state persists.
4. **Bridles:** all the same fixed length, set before launch, forming a **shallow
   cone at the APEX** so they crush the ring less. Shallow apex ⇒ more axis-aligned
   ⇒ less radial compression; enough banking can make the ring **tensile**.
5. **The backline is an altitude limiter**, partially elasticated in the field. It
   takes the lift surplus (§3) — confirmed by measurement.
6. **Taut-chain invariant:** every line above the ground ring must be in tension at
   the operating point. Slack is a defect, never a resting state.

---

## 9. Open work, in priority order

1. **Finish the static solver** (§5). Constrain the step to near-constant line
   length. Then the settle becomes a real equilibrium solve and V2/V3/V6 should
   start passing — the guard will say so.
2. **Re-derive the load split** between the lift chain and the transmission. The
   bridles carry ~123 N, not the ~431 N the preload formula assumes, so the
   `+ T_cyan` term is right in direction and wrong in magnitude. The preload
   (`design_axial_preload`) must be re-derived once the chain is genuinely loaded.
3. **Bear damping decision.** `bearing_tr_damp = 0.99994` was added deliberately in
   `e83f6ca` (2026-05-18) *"to suppress off-axis precession... Without transverse
   dissipation the bearing can precess indefinitely"*, but it was added to
   `simulate()` and **never ported to `run_canonical_sim!`** (born later in
   `12bc91b`). The canonical loop — the one the evaluator and campaign use — has
   **no bearing damper at all**, and the bearing is measurably undamped (1.7 mm →
   0.48 m off-axis with 9.8 m/s transverse inside 0.5 s). Rod was never happy with
   the number as unphysical (it stands in for drag on the fitting, rope hysteresis,
   and rotor gyroscopic stiffness). **Decide:** port it, derive a physical value, or
   gate the wobble. Related: the bow's ~10 s lightly-damped lateral mode is probably
   the same mode as the wobble.
4. **Implement the banked main rotor** (§8.2). Must be done together:
   `expansion_params_from_rotors` silently `continue`s on the top ring
   (`builders_util.jl:90`) and the same guard is duplicated at `ring_forces.jl:263`;
   the main-rotor thrust is hardcoded at `hub_gid` (`ring_forces.jl:215`);
   `expansion_airborne_mass` books the main rotor *plus* the expansion sum
   (`expansion_analysis.jl:59-62`) so a banked top rotor would be charged twice.
5. **Re-derive loads → `SIZING_FOS_MARGIN` → window → the seed question.** The
   seed's FoS (1.31–2.31 vs a 2.5 floor) was measured with the lift chain
   disconnected and the transmission 27 % over-preloaded, and
   `SIZING_FOS_MARGIN` was itself tuned (1.15→1.3) against an artefact. **Do not
   re-baseline the red acceptance tests; they pin a real safety signal.** Only after
   this can anyone say whether a new campaign seed is needed. My expectation, to be
   tested not assumed: the corrected preload is *lower*, so the beams are
   under-sized and FoS should move *up*.
6. **Two unexplained items:** segments 7–8 transmit only 324.5 / 228.5 N·m of the
   377.6 N·m operating torque (§3); and a returned settle state was observed at
   ω = 4.842 instead of `ω_eq` = 12.983. Resolve the ω one before quoting any torque.
7. **Test-suite hygiene (pre-existing, not caused here):** `handovers/README.md` is
   missing 8 entries; `handover-2026-08-26-recovery-backlog.md` may want a
   SUPERSEDED banner; 20 of ~50 live tests still use the legacy `params_10kw` and
   only 3 carry the `ERA PIN` header, so 17 assert physics on a machine the pipeline
   never builds.

---

## 10. Where to start, in order

1. Read `docs/agents/physics-topology.md`, then §2 and §5 above.
2. Run `scripts/ktd-julia test/runtests.jl` — expect 2086 pass / 5 broken.
3. Fix the static solver step (§5). **Put it in `src/` with the guard as its test,
   not in `scratch/`** — every harness bug this session lived in throwaway probes,
   where a typo masqueraded as a physics finding for several runs.
4. When V2/V3/V6 start passing, re-derive the load split and the preload (§9.2).
5. Then the damping decision, the banked main rotor, and the loads/FoS re-derivation.

**One standing caution.** This session produced a lot of diagnostics and several
were wrong in ways that were reported as findings before being checked. The fix is
not more care in prose but more *executable* checking: assert the invariant in the
script before trusting its output, and put the durable ones in `test/`.
