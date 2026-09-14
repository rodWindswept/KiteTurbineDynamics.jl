# Handover: lift chain, the realisability floor, and the ring-plane gap (2026-09-13)

**Status:** working tree **DIRTY and RED**. There are 6 modified files and 4 new
scratch probes, **nothing committed**. HEAD is `86217d7`, 29 commits ahead of
`origin/master`, nothing pushed (a standing choice by Rod).

**Read first:** this file, then `docs/agents/physics-topology.md` (mandatory
before any geometry/tension/load-path work). `handovers/handover-2026-09-12-settle-rebuild-bow-and-static-solver.md`
remains valid for §5 (the static solver harness) and §6 (harness-bug catalogue).

**One-line state:** the lift chain was disconnected by a *length bookkeeping
error*, not a force error. That error is now fixed in the tree and the chain
engages. Fixing it exposed that the settle is a **placement plus a 0.16 s
relaxation, not an equilibrium**, which is why 2 fast tests are red. Phase 1b
(the static equilibrium solve) is the next task and is specified in §7.

---

## 1. Running Julia here: unchanged

```bash
scripts/ktd-julia test/runtests.jl              # fast suite, ~3 min
scripts/ktd-julia test/acceptance_runtests.jl   # acceptance, 8 files, ~18 min
scripts/ktd-julia scratch/<probe>.jl            # any probe below
scripts/ktd-format
```

Plain `julia --project=.` **fails** in this sandbox (stacked-depot problem).
`/tmp` does **not** persist between shell calls. Write logs to
`.julia_depot/logs/`. Julia buffers stdout when redirected. Read the log file
rather than expecting live output.

---

## 2. Suite state: read this before trusting anything

| tree | result |
|---|---|
| HEAD `86217d7` (clean) | **2086 pass / 5 broken / 2091**, exit 0 |
| this working tree, before the `sim_frame.jl` fix | **2084 pass / 2 fail / 5 broken** |

The 2 failures are both `test/test_settle_preload_consistency.jl`:

- `:79`, achieved vs intended preload error **0.673** (threshold 0.15)
- `:107`, the `(n_lines=4, rotor_count=3)` case, error **114.0** (threshold 0.6)

The second is worse than "unconverged" and is **not yet diagnosed**. Treat it as
an open question, not as a tuning target. The `src/sim_frame.jl` edit landed
*after* that suite run, so the suite has not been run against the current tree
at all. **Run the suite first thing.**

---

## 3. Finding 1: the lift chain was disconnected by a length error (FIXED)

`scratch/diag_lift_chain.jl` (self-checking force audit). At the operational
settle, before the fix:

| link | rest L₀ | actual L | state |
|---|---|---|---|
| cyan (sky↔bearing) | 5.0000 | 5.0023 | taut, 230.6 N |
| **bridle ×6** | **6.4622** | **4.658** | **SLACK, 0.000 N** |
| lift line | 25.0000 | 25.0000 | gate **OPEN**, T = 459 N |
| backline | 15.2295 | 14.2300 | slack by 1.00 m |

Force audit (identified contributors matched `m·du` to <0.7 N, so the audit
closes): the **lift bearing** had cyan +180 N up, gravity −2.9 N, bridles 0 N,
net **+141 N up → 764 m/s²**. The **sky anchor** had net +268 N up → 894 m/s².

**Root cause.** The bridle rest length was `√(6.0² + 2.4²) = 6.4622 m`, cut for a
bearing **6.0 m** above the rotor. But the equilibrium of the chain puts the
bearing at **3.99 m** (the cyan is 5.0 m and the bearing hangs at its full length
below the sky anchor), where the real bridle gap is
`√(3.99² + 2.4²) = 4.658 m`. The bridles were **1.80 m (39 %) too long** and
could never reach. The cone geometry itself was right: 3.99 m axial /
4.658 m 3D / **31.0°** from the axis / **59.0°** at the ring plane, all six rest
lengths equal.

**Why earlier attempts failed.** The lift direction was never the problem: the
lift line is taut (L = L₀ = 25.000) and its gate is **OPEN**. Re-aiming the lift
at the sky hook, or hauling the sky hook down toward the bearing, cannot shorten
a bridle. The chain was too long to reach, not losing tension.

**Second, independent defect in the same place.** `initialization.jl` set
`bridle_L0 = norm(bearing_pos0 .- pa_attach)`, the rest length *equal to the
design gap*, i.e. **zero strain**. A tension-only line that must carry preload
has to be cut **shorter** than its design gap. The same pattern holds for the
cyan (`CYAN_L0` is both the placement offset and the rest length).

---

## 4. Finding 2: the tautness of the backline decides torsional realisability

`scratch/design_chain_preload.jl`. The two static sections (orientation verified
against `ring_forces.jl:209-215`, not assumed):

```
ŝ = ground→main-rotor = [cos β, 0, sin β]      ("up-shaft")
rotor thrust acts along +ŝ   (downwind. The hub is downwind of the ground station)
bridles pull the rotor +ŝ and the lift bearing −ŝ
gravity axial component = −W·sin β

Section A: lift bearing alone:   n·T_b·cos θ = T_cyan·(cyan_dir·ŝ) − W_bearing·sin β
Section B: cut TRPT below rotor: T_top = T_thrust + n·T_b·cos θ − W_rotor·sin β
```

At the 3.99 m design point, `T_lift = 459 N` at 70° elevation:

| backline at design | T_cyan | T_bridle | T_top | vs floor 1274.47 N |
|---|---|---|---|---|
| **taut** (what `design_preload_from_sky_anchor` assumes) | 155.5 N | 30.0 N | **1150.0 N** | **−124.5 N → unrealisable** |
| **slack** (its actual design role) | 350.1 N | 67.8 N | **1344.7 N** | **+70.2 N → realisable** |

The backline is an **altitude limiter, not a load path** (Rod 2026-09-12), so it
*is* slack at the design point. The whole lift projection then lands on the cyan
line and the required preload rises clear of the floor. **The plan §2.4.1
"unrealisable preload" blocker was an artefact of modelling the backline as
taut.** The closed form reproduces the fixed-point value in the plan (1150 vs
1155.09 N), which is a good independent check. **No new seed is needed for this
reason.**

The old `design_axial_preload` had three defects, all now replaced. Thrust was
evaluated as 1868 N against 1068 N from the kernel. Weight was resolved as
`−W/sin β` where the axial component is `−W·sin β` (factor 4 at 30°). The mass
of the kite was charged at the rotor with a taut backline.

**Do not write "+70.2 N on the backline".** In that case the backline carries
**exactly zero**. +70.2 N is the margin of the **TRPT top tension** over the
minimum tension needed to transmit the torque.

---

## 5. Finding 3: the realisability floor is tight, and the ODE torque instrument was wrong

`scratch/reconcile_realisability.jl`. Two estimates disagreed ~2.5×:
closed-form floor → `sin Δα ≈ 0.95`. The settled ODE state → `sin Δα ≈ 0.38`.

**The 0.38 came from a broken instrument.** `capture_extended`
(`src/sim_frame.jl`) computed torque with a **uniform** `L_seg =
tether_length/n_seg = 2.35 m`, the **mean radius squared**, and an
**equal-radius chord**. The real axial gaps of the seed run **0.93 m → 4.79 m**
and `r_a ≠ r_b` (it is a cone). Thus it reported 180…660 N·m across segments all
carrying 377.6 N·m, up to 2.6× wrong. **Fixed** to the real geometry
(`r_a·r_b`, real axial gap, `chord = √(L_ax² + r_a² + r_b² − 2 r_a r_b cos Δα)`).

**Verdict on the same settled state, with the fixed law:**

| seg | r_a | r_b | real L_ax | real chord | T_s | Δα | true τ | sin Δα |
|---|---|---|---|---|---|---|---|---|
| 1 | 0.575 | 0.575 | 0.927 | 1.171 | 228.7 | 77.0° | 377.6 | 0.974 |
| 2 | 0.575 | 0.575 | 0.922 | 1.171 | 228.0 | 77.8° | 377.6 | 0.977 |
| 3 | 0.575 | 0.575 | 0.917 | 1.171 | 227.4 | 78.5° | 377.6 | 0.980 |
| 4 | 0.575 | 0.575 | 0.912 | 1.171 | 226.7 | **79.4°** | 377.6 | **0.983** |
| 5 | 0.575 | 1.175 | 1.367 | 1.601 | 226.1 | 41.3° | 377.6 | 0.660 |
| 6 | 1.175 | 2.400 | 2.983 | 3.271 | 225.4 | 18.9° | 377.6 | 0.324 |
| 7 | 2.400 | 2.400 | 4.776 | 4.801 | 224.8 | 11.8° | 329.9 | 0.204 |
| 8 | 2.400 | 2.400 | 4.788 | 4.801 | 224.1 | 8.5° | 238.2 | 0.148 |

**So the floor was right: the binding segment is 4 at Δα = 79.4°, sin = 0.983,
which is 10.6° from the 90° collapse cliff.** Realisable, but *tight*. This is a
design constraint to widen (more lines, larger attachment radius, or lower
`k_mppt`), not a pass. State the margin as a **twist angle and a % of the
cliff**, never as "+N N above a floor".

The fix independently reproduces the `preload_torque_dimension.jl` result from
the handover. That is 329.9 / 238.2 against its 324.5 / 228.5 N·m, so a second
instrument validates it.

**Also remember:** realisability must be checked **per segment against the torque
that segment carries**, not against the global 377.6 N·m.

### 5.1 Torque increases going DOWN the shaft, and that is correct

The seed has **three rotors, at ring indices 7, 8, 9**. The generator is at ring
1. Each rotor injects at its own ring, so the accumulated torque grows downward:

```
seg 8 (rings 8↔9): 238.2 N·m   main rotor alone
  + 91.7 injected by the expansion rotor at ring 8
seg 7 (rings 7↔8): 329.9 N·m
  + 47.7 injected by the expansion rotor at ring 7
seg 6 and below  : 377.6 N·m   uniform → the generator extracts k·ω² = 377.6
```

`238.2 + 91.7 + 47.7 = 377.6`. The injections sum exactly to the generator load.
The property "377.6 N·m" is the **ground/generator load**, i.e. the sum over
rotors. The top segment carries only the 63 % share of the main rotor. If the
bottom carried *less* than the top that would be the anomaly.

**This closes the open item in the handover**: "segments 7 to 8 transmit only
324.5 / 228.5 N·m of the 377.6 N·m operating torque, unexplained". It was never
a defect. It is distributed torque injection. Should be recorded in
`DECISIONS.md`.

---

## 6. Finding 4: the ring plane is not a physical degree of freedom (NOT fixed)

**This is a prerequisite for a trustworthy campaign and is still open.**

- `src/dynamics.jl:23-52` builds **one global** ring-plane basis for the whole
  machine: `shaft_dir = hub_pos/|hub_pos|` (the radial of the hub from the
  **ground origin**, not the local centreline). Then it tilts that basis by
  `tilt_angle = min(0.1 · |bearing offset⊥|, π/6)`, where `TILT_SCALE = 0.1`
  rad/m is a tuneable constant, clamped at 30°.
- That basis is then used for **every TRPT sub-segment**
  (`rope_forces.jl:257,268`, non-bridle branch), while **bridles use a different
  basis** (`shaft_perp_basis(shaft_dir)`). That is a basis split.
- The code contradicts itself. `geometry.jl:72` says the basis is "for dashboard
  visualization". `ring_forces.jl:598` says it is "**NOT suitable for physics
  computations**". `docs/plans/2026-05-12-disc-tilt-redesign.md` states the
  first constraint as "**One basis per ring per step**" and records that the
  split caused uneven bridles, pulsed shaking and the bearing running away.
- Root architecture: `docs/plans/2026-05-09-free-rotor-dynamics.md:129-171`.
  RingNodes are point masses + twist only. Asymmetric bridle tension produces
  twist torque but **no ring-plane tilt**. Rod stated a preference there for
  **Option A: individual vertex nodes**. `2026-05-12-disc-tilt-redesign.md`
  is **ON HOLD and requires explicit approval from Rod before execution**.

**Why it matters now:** in a bowed column the tether paths split into a long
(belly) and a short side, torque redistributes, and the ring planes tilt. The
model cannot represent any of it. `scratch/diag_bow_shape.jl` measured the
consequence. Changing only the bridle rest length changed the proxy tilt in the
model from 0.69° to 5.17°. It also changed the bow from **0.116 m** (max at ring
8) to **0.776 m** (max at ring 7). That is, the bow magnitude is set by a tuning
constant, not by the mechanics. Both runs had `max accel 123 to 249 m/s²` after
2 M steps, so the relaxation never converged either.

**Also measured in that probe:** slack TRPT lines are real and sit on the
**belly** side (segment 7, `L0=6.4622`: back lines 275.5 / 521.5 N, belly lines
153.3 / **8.7** / 19.2 N). The ruling by Rod is that TRPT lines and the bridle
cone may slack occasionally, while only the lift line, cyan line and backline
must stay connected. That is what a bowed column actually does.

The 1.5 m bow figure in the previous handover is a **rigid-tilt estimate**
(`sin θ = 124/1589` over 18.8 m), not a solved catenary, and it is sensitive to a
preload now known to be wrong. Do not treat it as a result.

---

## 6a. Phase 1a: vertex-node rings, per-ring (DECIDED 2026-09-13, Rod)

**Decision.** Individual vertex nodes, **per ring**, replacing the single ring
centre + twist DOF. This executes `docs/plans/2026-05-09-free-rotor-dynamics.md`
Phase 2 **Option A** (a preference Rod stated) with its scope extended from
hub-only to **per-ring**, and it supersedes the on-hold
`docs/plans/2026-05-12-disc-tilt-redesign.md` (whose "Option A" was the cheaper
2-DOF plane). Rod said that if there is time to compute this, we should go for
the vertex-node rings per-ring. The compute cost is accepted. See below.

**Shape of the change.**

- `RingNode` (centre + `α` + `ω`) → `n_lines` **`VertexNode`s** per ring, each a
  free 3-DOF particle, plus **rigid beam spring-dampers between adjacent
  vertices** around the polygon (with a closure check).
- Ring mass (`m_ring` + knuckle mass) distributes over the vertices. The twist
  inertia `inertia_z` retires. The vertices carry it as `m·R²`.
- **Every attachment becomes a real vertex position**: TRPT sub-segment ends,
  bridles, expansion-rotor vertices. `attachment_point` and
  `_tilted_ring_basis` leave the physics path, which **deletes the
  `TILT_SCALE = 0.1` proxy and the `is_bridle` basis split by construction**.
  The whole of §6 becomes moot rather than patched.
- Twist `α` per ring becomes a **derived** quantity (mean azimuth of the
  vertices) for telemetry. Ring torque is applied as tangential forces at the
  vertices.
- Ground ring stays fixed (all its vertices pinned). Rotor thrust / expansion
  forces distribute to the vertices (or apply at the vertex centroid with the
  equivalent moment).

**Tests that must gate it.**

1. **Symmetric-limit regression (the important one).** A straight, symmetric
   design must reproduce the current profile: run `test_settle_preload_consistency.jl`
   and the `reconcile_realisability.jl` table, and get the same result. That
   means segments 1 to 6 at 377.6 N·m, **binding segment 4 at Δα ≈ 79.4°**
   (sin 0.983). If that moves, the refactor is not behaviour-preserving in the
   symmetric limit and must not land.
2. **Static asymmetric-load tilt**: a known transverse load must tilt a ring to
   the analytic moment-balance angle within 5 % (Phase 2 item 6 in the plan).
3. **Polygon closure**: assert the vertex polygon perimeter stays within
   tolerance under load.

**Compute (measure, do not assume).**

- DOF: `+6·(n_lines−1)·Nr − 2·Nr`. Seed (6 lines, 9 rings) ≈ **+250 states**.
- Sub-segments: `+n_lines·Nr` beam segments (seed: **+54** on ~250, ≈ +20 %).
- Expect roughly **+30 to 60 % per ODE eval**. At the measured ~195 s/eval that
  is ~250 to 300 s/eval, so **~22 to 36 h/island**, not the 87 s/eval or 7 to 9 h
  in the runbook.
- **Measure `stable_dt_for_system` before and after** and record it. Stiff beam
  springs may force a smaller `dt`, which multiplies the cost again.

**Order: 1a before 1b.** The equilibrium solver must be written against the final
state layout, or it gets written twice.

---

## 7. Phase 1b: the next task (executable spec)

The settle is a **placement plus a 0.16 s relaxation, not an equilibrium**. That
is now visible. With the chain disengaged it did not matter. Now the bridles
carry ~450 N and the two preload-consistency tests fail.

Build, **in `src/`** (not `scratch/`). Every harness bug this session lived in
throwaway probes where a typo masqueraded as physics:

1. **`solve_static_equilibrium(sys, u0, p; lift_device, wind_fn, omega_eq)`**.
   Run Newton/LM on the force residuals of the ODE (node accelerations,
   mass-scaled) and torque residuals (ring angular accelerations), with the
   **aerodynamics frozen** (ω at the operating point, kite at its equilibrium
   offset). A root-find is insensitive to how soft the slow lateral mode is,
   which dynamic relaxation cannot handle.
   - **Solve the least-squares step by QR on `[J; √λ I]`. NEVER form `J'J`**.
     With `max|J| ≈ 1e7` it squares the condition number and the bow-carrying
     directions are lost (this was measured: accepted steps fell to 1.2e-5 m).
   - **Per-DOF column scaling** (DOFs span 1e-3 m rope motions to 1 m bow motions).
   - **Constrain the step to the near-constant-line-length manifold**, or drive
     the bow by continuation on the applied perpendicular load. Measured: a
     *global* sideways ring translation is very stiff (217 N at 10 mm, k ≈ 3.5e5
     N/m at 0.5 m) because the pinned ground anchor stretches the lines, so an
     unconstrained local step sees a spurious energy barrier and creeps
     (200 LM iterations moved the hub 0.3 mm against a ~1.5 m target).
   - If it cannot converge, **raise**. Do not silently fall back.
   - Do **not** re-try the rejected approaches: full-state damped Newton on the
     ODE residual, staged positions-Newton + twist bisection, or unpinning the
     rings (`dt²·(F/m)` drift). See the 2026-09-11 plan §2.5.
2. **Put the guard in `test/` as the test for the solver**.
   `test/test_settle_validity.jl` already exists with 2 `@test` + 5
   `@test_broken`. Promote V2 (force balance) and V6 (smooth handoff, `< 10 g`)
   to `@test` as they start passing. **Restate V3 to the ruling by Rod**: the
   mandatory-taut set is the **lift line, cyan line and backline chain**. The
   **bridle cone and TRPT lines may slack**. The current V3
   (`bridle > 0.25 × lift_req`) encodes the superseded rule and must be
   replaced, not deleted.
3. Then the two `test_settle_preload_consistency.jl` reds should resolve
   legitimately. **Do not edit their expectations to pass.**

The known measurable targets are all in the tables above: bridles taut at
~68 to 107 N (bottom bridle tightest), bearing 3.990 m above the rotor, cone
31.0°/59.0°, binding segment Δα ≈ 79.4°.

---

## 8. Pre-flight checklist and traps

Run `docs/agents/physics-topology.md` §5 before any geometry/tension work. Added
this session:

- **The lift line is not a spring.** `T_lift` is an external force at the sky
  anchor, applied only while `|kite_pos − sky_anchor| ≥ 0.99·line_length`, else
  **zero** (`ring_forces.jl:494-506`). At the settle it sits *exactly* at L₀ =
  25.000, one lag-step from switching the whole lift off. That is brittle, and
  it will chatter in flight.
- **`capture_extended.segment_torque` was wrong until this session** and is
  telemetry-only (dashboard). If you read torque from anywhere else, check the
  radius and chord assumptions in the formula first.
- **The `1e30 kg` ground anchor is deliberate**. Exclude it from mass sums.
- **`_tilted_ring_basis` is not physics** (§6).
- **Julia buffers stdout, and `/tmp` does not persist.**
- **A green fast suite is not a launch signal** while 5 assertions are
  `@test_broken`.

---

## 9. Open decisions for Rod

1. ~~Ring-plane form (§6)~~. **DECIDED 2026-09-13: vertex-node rings,
   per-ring. See §6a for the spec.** The approval gate of the on-hold plan is
   satisfied.
2. **Lower-transmission margin:** segment 4 sits at Δα = 79.4° (10.6° from the
   cliff). Widen it (lines / attachment radius / lower `k_mppt`), or accept and
   gate on it?
3. **Backline design rest length:** set so it is slack at the operating point
   (dyneema stop above the sky position), per its altitude-limiter role. Confirm
   the ~2 m elastic band figure.
4. **Seed:** the realisability blocker in the plan is resolved, so the 5 kW v13
   re-run can keep the current seed. Confirm.

---

## 10. Files

**Modified (uncommitted):**

| file | change |
|---|---|
| `src/initialization.jl` | design constants (`BEARING_OFFSET_DESIGN = 3.99`), `lift_chain_design`, `apply_design_bridle_preload!`, rewritten `design_axial_preload`, design placement of bearing/sky |
| `src/sim_frame.jl` | `capture_extended` torque instrument fixed to the real geometry |
| `src/ring_forces.jl` | backline design constants single-sourced |
| `src/dynamics.jl`, `src/geometry.jl` | tilt-proxy reference uses the design constant |
| `test/test_settle_preload_consistency.jl` | `design_axial_preload` signature |

**New probes (all self-checking. They error out rather than print numbers if
their own assertions fail):**

| probe | answers |
|---|---|
| `scratch/diag_lift_chain.jl` | the chain force audit, §3 |
| `scratch/design_chain_preload.jl` | two-section design chain, backline taut vs slack, §4 |
| `scratch/reconcile_realisability.jl` | per-segment torque both ways, §5 |
| `scratch/diag_bow_shape.jl` | bow profile, slack partition, ring-plane error, §6 |

Logs: `.julia_depot/logs/lift_chain_after_place.log`,
`.julia_depot/logs/bow_L0_6.4622.log`, `.julia_depot/logs/bow_L0_5.2.log`,
`.julia_depot/logs/fastsuite_chainfix.log`.

---

## 11. Where to start, in order

1. `scripts/ktd-julia test/runtests.jl`: establish the real current state
   (expected: 2 fail, in `test_settle_preload_consistency.jl`).
2. Read `docs/agents/physics-topology.md`, then §3 to §7 above.
3. Diagnose the `:107` failure at `(n_lines=4, rotor_count=3)`. It is 114× off,
   which is not explained by unconvergence. Check whether the design chain is
   consistent at 4 bridles (bridle count, or `effective_radii`).
4. **Build Phase 1a (§6a): vertex-node rings, per-ring.** Decided. This is the
   next implementation task.
5. **Then Phase 1b (§7)**: the equilibrium solver, written against the state
   layout of 1a.
6. Then loads → `SIZING_FOS_MARGIN` → acceptance re-baseline → the 5 kW v13
   re-run.

**Standing caution.** This session produced several diagnostics and two of them
were wrong in ways that were reported before being checked (a broken torque
formula produced a "sin Δα = 0.38" margin that was really 0.983). The fix is not
more care in prose but more *executable* checking: assert the invariant inside
the script before trusting its output, and put the durable ones in `test/`.
