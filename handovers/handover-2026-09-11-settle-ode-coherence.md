# Handover — settle↔ODE coherence fixed; preload derivation + FoS shortfall are the open blockers (2026-09-11)

**Status:** one verified `src/` change in the working tree (uncommitted). Fast suite
green, acceptance 5/8. Next agent's first task: replace the hand-built axial
preload formula with a kernel-derived one, then re-derive loads / margin / window.
Read `docs/plans/2026-09-11-settle-ode-coherence.md` first — it is the live plan.

---

## 1. Running Julia in this sandbox (read this first)

* `/snap/bin/julia` **does not work** (`cannot create transient scope: DBus error …
  [Process 3 is a kernel thread, refusing.]`, exit 46). Use the raw binary.
* Canonical invocation, from the repo root:

  ```bash
  JULIA_DEPOT_PATH="$PWD/.julia_depot:/home/rodbot/.julia" \
    /snap/julia/165/bin/julia --project=. --startup-file=no <script>
  ```

* Acceptance tests spawn child processes — prefix `PATH="$PWD/.julia_depot/bin:$PATH"`
  or they cannot find `julia`.
* `~/.julia` is **read-only** (EROFS) and `/tmp` does **not** persist between
  commands. Everything goes in the repo-local `.julia_depot/`.
* `shell` calls are stateless: pass `workdir`, do not rely on `cd` persisting.
* JuliaFormatter is **not** installed in the project environment, so the two files
  changed in this session have not been auto-formatted. Run it before committing if
  you can make it available.

## 2. Standing constraints (do not violate)

* **Campaigns are paused.** A short `--gen 1` campaign was pre-authorised once the
  R7 code was green; it has now been run (see §7). Do not launch another without
  explicit go-ahead.
* The **six static guards** are done and pushed (`b427143`) — do not redo them.
* **NAS brain sync belongs to Hermes** — do not touch it.
* The **imported desktop sessions are read-only** — do not resume or edit them.
* `git` head is `853d551`. Everything from R7–R10, R11 and this session is
  **uncommitted in the working tree**.

## 3. What this session delivered

### 3.1 The settle↔ODE coherence fix (verified, in the tree)

**Symptom.** Every ODE run began with a large jerk and then spent ~100 s "winding
up": cumulative twist climbing 42.5° → 294°. Measured baseline at the returned
state (`scratch/r7_settle_residual.jl`):

| quantity at t=0, old settle | value |
|---|---|
| `max‖a‖`, free nodes | 3.83e3 m/s² (**390 g**) |
| `max‖F‖` at any node | **3.05e3 N** (≈10× the line tension) |
| `max|τ|` residual over rings | **87.3 N·m** (23 % of τ_gen) |
| cumulative Δα / first segment | 42.51° / 6.58° |

`n_op = 30 000` and `150 000` gave **bit-identical** output, so the operational
settle was fully converged — the defect was structural, not "settle too short".

**Root cause (this supersedes §2.16 of the shaft-windup workstream).** The preload
restore set each segment's ring **axial gap** for the *untwisted* line and only
then applied the twist. Because

```
chord² = L_ax² + r_a² + r_b² − 2·r_a·r_b·cos Δα
```

the twist term alone stretches the line. At the Δα = 6.58° the old bisection
converged to, that twist strain was **1.6e-3 — six times** the intended preload
strain (2.7e-4). The segment therefore behaved ~7× too stiff in torsion and the
settle returned a ~7× under-twisted state; the ODE then relieved it by shortening
the transmission — that *is* the wind-up.

Evidence that it is tension, not "frame softness":

| | settle (old) | run (t=20 s) |
|---|---|---|
| first-segment twist | 6.58° | 48.85° |
| line tension | 1947 … 601 N | 301 … 208 N |
| transmitted torque | 188,188,188,188,292,595,652,447 | 188,188,188,188,292,596,667,597 |
| ring lateral offsets | 0.000 m | 0.002–0.032 m |

Torque identical, twist 7× different, chord within 1.6 %, lateral motion
negligible. §2.16's "270× torsionally softer frame / rings move laterally to hold
the chord" is **wrong** — carrying a SUPERSEDED banner in
`docs/plans/2026-09-10-shaft-windup-workstream.md`; do not act on it.

**Fix.** `_matched_place_twist` in `src/initialization.jl` solves the pair
`(Δα, L_ax)` together per segment, in closed form, so the line carries the intended
preload `T_s = F_ax[s]/n_lines` at its final twist:

```
chord  = chord0 · (1 + T_s / EA_single)
sin Δα = τ_target · chord / (n_lines · T_s · r_a · r_b)
L_ax   = √(chord² − r_a² − r_b² + 2·r_a·r_b·cos Δα)
```

`O(Nr)` arithmetic, no ODE calls, no per-eval cost — it *replaces* the pinned
position restore and the separate twist bisection. `design_axial_preload` was
extracted (and exported) so the intended preload is testable. The legacy
torque-chain bisection is retained **unchanged** for the `lift_device === nothing`
path (control-map / calibration scripts and several tests use it); the rope-node
interpolation was moved out of the bisection so both paths share it.

**Verified** (`scratch/r7_tension_settle_vs_run.jl`, campaign seed, honest
k = 2.24, 60 s):

| | old | new |
|---|---|---|
| first-segment twist at t=0 | 6.58° | **51.94°** |
| cumulative Δα at t=0 | 42.5° | **277.43°** |
| line tension at t=0 | 1947…601 N | **283…265 N** (= the design preload) |
| over 60 s | climbs to 294° | 277.4 → **299.7° then flat** |
| ω_gnd | 12.98 → 13.2 | 12.98 → 13.24 |
| generator power | ≈5.1 kW | ≈5.2 kW steady |

The transmission comes out **0.63 m shorter** (18.805 → 18.173 m). Rod's
correction (2026-09-11): this is *not* the tether line shortening — it is the
transmission axis shortening under torsional deformation, as the set of lines
wraps around the axis. Accepted.

### 3.2 Fast test guard

`test/test_settle_preload_consistency.jl` (new, wired into `test/runtests.jl`,
~24 s): asserts the settled line tension equals `F_ax/n_lines` within 15 %, and
the first segment is past 30°, on the campaign seed and a 3-rotor geometry; plus a
documented looser-bound testset for the tilt limitation (§6.1).

**Fast suite: 2084/2084 green** (42 files).

## 4. NEXT TASK (Rod's call, 2026-09-11): derive the axial preload from the kernel

`design_axial_preload` was lifted **verbatim** out of the old initialiser, so the
fix inherited its formula. Rod flagged the reasoning and the model confirms he is
right:

```julia
thrust   = 0.5*ρ*v_ref^2*π*R^2*0.8*cos(β)^2      # already the AXIAL thrust
F_aero_z = thrust*sin(β) - W                      # treats it as horizontal
F_top    = F_aero_z/sin(β) + T_cyan               # = thrust - W/sin(β) + T_cyan
```

* The ODE applies thrust **along the shaft axis**: `src/ring_forces.jl:215` does
  `forces[hub_gid] .+= thrust_mag .* tether_dir` with
  `tether_dir = normalize(hub − ground)`. Correct — the disc plane is
  perpendicular to the shaft — and `cos²β` at `:208` is the normal-wind
  projection. So the `·sin(β)` then `/sin(β)` round-trip is numerically neutral
  but conceptually wrong.
* The weight term is **not** neutral: `−W/sin(β)` resolves a *vertical* load
  axially, where the axial component of gravity is `−W·sin(β)`. At β = 30° that
  is −384 N vs −96 N; at β = 70°, −1.06 W vs −0.94 W. The sign also silently
  assumes the lift kite, not the shaft, carries the weight.
* **The gap is already measurable**: the ODE settles to 301 → 208 N/line while
  the formula prescribes 283 → 265. The residual ~8 % twist drift (277.4 → 299.7°
  over 60 s) is consistent with the ODE still relaxing what the formula got wrong,
  so this is on the critical path, not cosmetic. Unseparated: how much of the gap
  is the direction error vs the crude constants (`0.8` instead of `ct_at_tsr(λ)`,
  `rotor.wind_factor`, `v_wind_ref` instead of hub-height wind).

**The current fast guard does NOT cover this.** It asserts
`achieved == F_ax/n_lines`, which is a *self-consistency* guard and would pass
with a wrong `F_ax`. A correctness guard is needed.

**Spec** (§2.4 of the coherence plan, with the full code sketch): demote the old
formula to a first guess, then close a scalar fixed point on the ODE's own hub
axial balance — place the geometry, evaluate the hub's net axial residual with
`multibody_ode!` (no time integration), correct `T_top -= 0.7·m_hub·a_ax`,
converge at `|m_hub·a_ax| < 1e-2 N` (sign: hub accelerating *up*-shaft ⇒ rope
pulling too hard ⇒ reduce). Traps:

* Reuse `_matched_place_twist` so the geometry stays consistent with the twist
  solve.
* Not circular: `T_top` is set by aero + gravity + lift/bridle, not by the twist.
* **Fallback**: if it does not converge, return `nothing`/throw and record it —
  do **not** silently fall back to the old expression.
* `_preload_first_guess` keeps the old formula **only** as a start value, so the
  two can be compared and the error quantified.
* Validate across a **β sweep (30/45/60/70°)** and ≥2 ring counts, and assert the
  kernel-derived `F_ax` reproduces the ODE's measured segment tensions at the
  settled state.

Then, in this order: re-derive loads → re-check `SIZING_FOS_MARGIN` and the seed's
structural margin → re-check the window → only then re-baseline anything.

## 5. Acceptance status — 5/8, and the two "failures" that matter

Full diagnosis: `docs/plans/2026-09-11-settle-fix-acceptance-reds.md`.
`PASS`: evaluator_v13, rope_break, rotor_power_realism, settle_drag_alignment,
jtheta_no_reversal. `FAIL`: gate_v13, settle_lowk_honest, physics_path_ode.

**Verdicts:**

1. **`test_gate_v13` A5 — stale trigger, re-baseline.** The latch is a *strain*
   limit, `ROPE_BREAK_STRAIN = 0.035` (`src/rope_forces.jl:31`, applied `:370-377`,
   gated at `scripts/ode_gate_v13.jl:175-176`), so it is tension-independent and
   still physically sound at 283 N (healthy strain 2.7e-4). The fixture's thin line
   (`test/test_gate_v13.jl:82`, d = 0.00025 → scaled 0.000456) had a design preload
   strain of only 1.73 % and was crossing 3.5 % *because of* the inflated preload.
   Fix: `:82` d → 0.00020 (measured `line_broken=true, ok=false, P=10.32 kW,
   ω=16.64, clearance 2.89` — all three A5 checks pass). Better fixture: lower
   `e_modulus`, so the break does not happen during the settle.
2. **`test_settle_lowk_honest` A3 — stale test config over a REAL defect.**
   `seed_genome_x()` (`test/test_settle_lowk_honest.jl:53-54`) applies **legacy
   14-D clamps `xr[8]`/`xr[10]` to the canonical 10-D genome**, so `bank_bottom`
   0 → 3 and `blade_scale_bottom` 0.7 → 1.0. That over-loaded machine settles past
   the crossing limit (ratios 1.06–1.16). Consequence: the twist-collapse sentinel
   (`src/objective_evaluator.jl:790-793`) **zeroes `P_mean`/`P_end`/`FoS`** — so
   `P_end = 0.0` is *not a measurement*, and `FoS_min = Inf` made the `FoS > 2.5`
   check pass spuriously. Fix the indices to `xr[4]`/`xr[6]` (as
   `test/test_settle_preload_consistency.jl:49-51` does). **Do not re-baseline
   `P_end`.**
3. **`test_physics_path_ode` P1 — REAL regression (FoS), the headline.**
   `status=reject`, `P_mean = P_end = 5.1390 kW`, `FoS_min = 2.3139`,
   `twist_crossed=false`. **The corrected state does not stall** — it makes rated
   power at healthy twist. The only failing gate is `FoS_min < fos_hard = 2.5`
   (`src/objective_v12.jl:149`). The pre-change 2.78 that was recorded as `:ok` was
   **inflated by the under-twisted start**. P1's `CFG` also omits
   `tether_diameter`, building 0.003 vs the campaign 0.003651 — and that is *not*
   FoS-neutral (rope self-weight feeds the beam load,
   `src/trpt_optimization.jl:443`); with the campaign tether the seed reads
   **FoS 1.83 (5 s) / 1.31 (20 s)**. So P1's 2.314 is the optimistic figure.

**Therefore: the R7 beam sizing is optimistic.** The seed is genuinely below the
2.5 floor in every window measured. Note also that the earlier
`SIZING_FOS_MARGIN` bump 1.15 → 1.3 (which took P1 from 2.448 to 2.783) was tuning
a margin against a window that was itself an artefact. The FoS trace oscillates in
a ~2 s limit cycle, so a **min-over-long-window** baseline is the honest one. Do
**not** re-baseline either red to a passing status — that pins a real safety signal.

## 6. Known limitations, carried forward

### 6.1 Ring-plane tilt → up to ~35 % tension error

`_matched_place_twist` uses the law of cosines for a ring plane **perpendicular**
to the shaft axis. The ODE's real attachment planes are tilted by
`_tilted_ring_basis` (driven by the bearing offset). The tilt shifts the chord by
~0.1 mm — small absolutely, but large next to the ~0.3 mm intended preload strain —
so where the settled tilt is significant the achieved tension runs ~35 % high. A
14-segment constant-radius geometry trips it; the campaign seed and the 3-rotor
geometry are exact. **Twist — and so the wind-up fix — is unaffected**, because Δα
does not depend on `L_ax`.

**Two corrections were attempted and both failed.** Do not retry them blind:

1. A second pass after the operational settle using the settled tilt basis →
   oscillating tensions (2.3× error).
2. A bisection on the exact chord → the tilt can make the chord non-monotone in
   `L_ax`; replacing it with a closed-form quadratic gave the *same* bad result, so
   the error is elsewhere in that approach. It needs a proper debug, not a patch.

Repro: `scratch/r7_case_check.jl` prints both geometries side by side.

### 6.2 Also open

* The legacy 14-D genome clamps appear in other test/diagnostic call sites — the A3
  bug is one instance; sweep for others.
* `view_campaign_genomes.jl` and several `scratch/` diagnostics still index 14-D.
* Museum-pin *testsets* inside live files (first 7 of `test_builders_v10.jl`;
  testsets 4–6/8–9 of `test_ring_spacing_v4.jl`) were not split out.
* The `lin_damp = 0.05` rope damper is an artificial numerical crutch with no
  physical basis that dominates the structural loads (off: 95–606 N; on: 90–217 N).
  Mislabelled "bearing damper" in `evaluate_windowed`.
* The ~10 s lateral wobble is a real lightly-damped mode; line drag cannot damp it
  (line Re ≈ 1500, ζ ≈ 0.001). Reframed as a **wobble-policy decision**: structural
  damper vs dynamic amplification factor vs wobble gate.

## 7. Campaign evidence (why the settle fix came first)

The pre-authorised short `--tag r7rebase` campaign ran to completion: **3 islands ×
20 genomes, ZERO valid**. Statuses 52 `reject`, 5 `reject_twist`,
3 `clearance_reject`, 0 `ok`. The seed itself makes 5.1 kW but FoS 1.63. Best FoS
seen 4.80 (3.7 kW, rejected on power). Nothing in the design space cleared the
windowed FoS gate while the start state was 7× under-twisted.
Telemetry: `scripts/results/v13_5kw_masslift_len18.8_rotorcount_r7rebase/island_{1,2,3}/`.

## 8. Tether drag — validated, change not yet landed

`docs/plans/2026-09-11-tether-drag-validation.md`. `tether_curvature_factor = 0.5`
lives in `parasitic_drag_power` (`src/objective_v6.jl:246`, applied `:334`) — the
**static** estimator that feeds R7's equilibrium ω. It is not on the live ODE path.

The equivalence is now derived from Tveide's own source, not hypothesised
(`solved_drag_coefficient_multiplier`, `src/TetherDragODESolver.jl:291-301`):

```
factor_KTD = multiplier · 4·r1³ / (r0³ + r0²r1 + r0·r1² + r1³)
```

Falsifiable check: a belly-free straight taper predicts
`multiplier = Σr³/(4r1³) = 0.3277` at KTD geometry, and the high-tension solver
limit returns `1.007/3.052 = 0.330`. At KTD's operating point (305 N, zero twist)
the factor is **≈1.09**, so 0.5 under-estimates tether drag ≈2.2×. Since the live
ODE path already behaves as factor 1.0, landing this is itself a settle↔ODE
coherence fix. **Land it as a separate commit with its own acceptance run.**

Outstanding from Rod's brief: check `TETHER_DRAG_CD = 1.0` against Dunker (VIV
+300 %, galloping +210 %; KTD line Re ≈1500 is inside the VIV range), and confirm
Wacker's frame-drag finding and that ring-strut drag (`TUBE_DRAG_CD = 1.2`) is
counted once. Low-tension caveat: Tveide returns a negative efficiency ratio at
150–305 N, i.e. the method is at the edge of validity there.

## 9. Tethers.jl — assessed, do not adopt

`docs/plans/2026-09-11-tethers-jl-assessment.md`. **Use only as an offline
validation reference.** Rod's framing (recorded in the doc's §5 scope note):
Tethers.jl belongs to the **single-line yo-yo AWES** family — one tether, ground
station to kite, fixed rotation reference. It is **not** for the many individual
tethers of a TRPT shaft, and no TRPT result should be validated against it. The
source agrees: `Tether_quasisteady.jl:473-476` pins the ground end at the origin
and derives ω about that axis, there is no twist/torsion DOF or torsional
stiffness, drag is normal-only, and there is no internal damping. Its only
legitimate KTD use is the not-yet-built lift/back-line catenary
(`docs/plans/2026-05-08-multi-segment-lift-backline.md`), offline, via vendoring
the two QSM files (KTD's manifest already carries every dependency, so vendoring
adds no packages; importing the package pulls 209 and ModelingToolkit v11).

## 10. File map for this session

| Path | Role |
|---|---|
| `src/initialization.jl` | `design_axial_preload`, `_matched_place_twist`, restructured `settle_to_operational_state` |
| `test/test_settle_preload_consistency.jl` | new fast guard (2 testsets, ~24 s) |
| `test/runtests.jl` | wires the above in (now 42 files) |
| `docs/plans/2026-09-11-settle-ode-coherence.md` | **live plan** — root cause, fix, verification, §2.4 preload spec, §5 verdicts |
| `docs/plans/2026-09-11-settle-fix-acceptance-reds.md` | per-test diagnosis with evidence E1–E9 |
| `docs/plans/2026-09-11-tether-drag-validation.md` | Tveide validation + derived equivalence |
| `docs/plans/2026-09-11-tethers-jl-assessment.md` | Tethers.jl assessment + scope note |
| `docs/plans/2026-09-10-shaft-windup-workstream.md` | §2.16 carries a **SUPERSEDED** banner — diagnosis was wrong |
| `scratch/r7_settle_residual.jl` | first-frame residual probe (S4/S5) |
| `scratch/r7_preload_audit.jl` | intended vs achieved tension |
| `scratch/r7_tension_settle_vs_run.jl` | settle vs running tension/twist/power |
| `scratch/r7_settle_chord_fix.jl` | the verification run for the fix |
| `scratch/r7_case_check.jl` | tilt-limitation repro (both geometries) |
| `scratch/r7_settle_newton.jl`, `r7_settle_staged.jl` | the two **rejected** coupled-solver prototypes |

## 11. Where to start, in order

1. Read `docs/plans/2026-09-11-settle-ode-coherence.md` (§1 diagnosis, §2 fix,
   §2.4 the preload spec, §5 acceptance verdicts).
2. **Derive the preload from the kernel** (§4 above / plan §2.4), with the β-sweep
   correctness guard. This is the approved next task.
3. Re-derive loads → re-check `SIZING_FOS_MARGIN` and the seed's margin → re-check
   the window. The FoS shortfall is the real blocker.
4. Fix the two test defects (A3 indices, A5 trigger), then re-run acceptance and
   get it back to 8/8 with honest baselines.
5. Then the tilt limitation, then the drag-factor commit, then the wobble policy.
6. Only then re-run the campaign.

Nothing in `src/`/`test/` is committed. Do not commit until acceptance is green —
the current tree has a verified fix and three red tests, two of which are real
findings.
