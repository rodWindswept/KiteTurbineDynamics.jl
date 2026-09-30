# Proposal — correct the TRPT over-twist criterion to Tulloch (2021)

**Date:** 2026-09-25
**Status:** PROPOSAL. Nothing in `src/` is changed. Needs Rod's approval, then tests,
then code, in that order.
**Evidence:** `docs/validation/2026-09-25-trpt-tulloch-model-crosscheck.md`
**Source of truth:** `docs/validation/tulloch-thesis-extract.txt` (full thesis text,
19,670 lines) and `Tulloch, PhD Thesis Final Submission.pdf`, Strathclyde 2021,
Windswept drive `03_Engineering/Academic Uni & Research/Strathclyde/`.

---

## 1. The defect in one paragraph

The repo caps, gates and floors the TRPT twist at

    δα* = 2·asin(L / √(2(L² + 2r²)))          L = ring separation, r = max(r_a, r_b)

and calls that "Tulloch's δα*", "the discrete geometric crossing limit". It is neither.
Tulloch's over-twist limit is `δcrit` from (4.34)/(5.4), a function of the tether length
over the ring radius **only**, and for `l_t < r_a + r_b` — a tether shorter than the sum
of the two radii — **no such limit exists at all**: the tethers cannot reach the axis, so
they cannot cross, and the section is limited by tether strength and ring strength
(§5.3.1, §3.1.3). The formula in the repo is the torque-peak angle of a different
kinematic (fixed ring gap, stretching tether), and not an accurate one. Ten of the
twelve segments of the live campaign seed are in the "cannot cross" class, so the repo
has been enforcing an angle limit on a machine the thesis says has no angle limit, and a
limit 44° tighter than the thesis where one does exist.

**Where the damage is, and where it is not.** The same formula also sets the ODE's
torque ceiling (`rope_forces.jl:515–569`). That ceiling was my first suspicion as the
cause of the observed wind-up. It is not. Measured against Tulloch's own torque law with
the ring separation contracting as (4.30) requires, the clamp permits 93–110% of the
transmitted torque at every twist from 30° to 100° on the seed's segment classes — it
cuts at most 7%, near 70°, and its cap value crosses Tulloch's curve at 90°. It creates
no cliff, and it does not manufacture the wind-up. Correct it for consistency, and
expect a small effect.

The damage is in **classification and margin**, and it is large:

1. **The gate is a false verdict.** `twist_collapse_check` reports "the lines have
   crossed" at `Δα ≥ δα*`. On the campaign seed that is 54.0°, where the lines have not
   crossed and, for ten of twelve segments, cannot cross. Recorded effect: the campaign
   seed was declared crossed at 58.93° (2026-09-20), and the L/r 1.2 machine was refused
   at a ratio of 74 047 (2026-09-25).
2. **The floor over-tensions the shaft.** A false verdict at 54° is what raised `F_top`,
   and preload drives line tension, ring compression, ring mass and ring FoS demand.
3. **The controller freezes 45° early.** The 5° collapse-margin freeze measures against
   δα*, so the ramp stops at ~49° where the thesis allows 100°.
4. **The DE understates capacity by ~20%** on the segments where δcrit exists
   (`τ_cap` = 0.1953 against Tulloch's Q_max = 0.2436 for segment 9), and applies a hard
   FoS floor of 1.5 to a quantity with no thesis meaning on the rest.
5. **A possible unjustified design bound.** The `L/r ≥ 1.0` seed bound is attributed to
   Tulloch (§7 item 4) and does not appear in the thesis.

---

## 2. What is verified correct — do not touch

| Element | Tulloch | Repo |
|---|---|---|
| Torque law `τ = n·T·r_a·r_b·sinΔα/chord`, `chord² = L²+r_a²+r_b²−2r_a r_b cosΔα` | (4.28)–(4.31), (5.2) | `initialization.jl:1708–1721`, `ring_forces.jl:470–472` |
| Zero twist → zero torque | (4.31) | same law |
| Twist shortens the ring spacing | §3.5, §4.6 | `trpt_matched_place` |
| Per-line tension-only springs between rigid rings | §4.7 multi-spring | `rope_forces.jl` |
| Drag split in two, applied to the nearest ring | §4.5.2, §4.6 | `rope_forces.jl:437–446` (half per end) — the SPLIT is verified. Whether the drag **torque** reaches the shaft is NOT: the drag is added to node forces only, never to `torques[]`. See WP2b. |
| 180° runaway guard ≈ the crossing event | §3.1.3, §4.4 | `ring_forces.jl:467` (`0.95π`) |
| 22° cone, taper to keep ring compression low | §3.1.3 | `objective_evaluator.jl:147` |
| Rope break at 3.5% strain (SK99) | §3.1.3 failure modes 2/3 | `ROPE_BREAK_STRAIN` |

The sin-law demand check is Tulloch's own continuum limit and is correct. Keep it.

---

## 3. The corrected criterion (specification)

Work per segment, from the same quantities the torque law already uses — the segment's
own tether length `l_t` (the repo's `chord`, at its operating tension) and its two
attachment radii `r_a`, `r_b`.

    disc = (l_t² − r_a² − r_b²)² − 4·r_a²·r_b²
         = (l_t² − (r_a+r_b)²)·(l_t² − (r_a−r_b)²)

**Case A — `disc ≥ 0`, equivalently `l_t ≥ r_a + r_b`.** An over-twist limit exists.

    cos δcrit = [ r_a² + r_b² − l_t² + √disc ] / (2·r_a·r_b)        (4.34, the + root)
    τ_max     = n_lines · T_s · r_a · r_b · sin(δcrit) / l_t        (4.31 at δcrit)

The `+` root is the torque maximum and it always lies in [−1, 1] when `disc ≥ 0`. Take it
alone. Do not select between roots. A static test asserts it is a maximum by checking τ at
δcrit ± 3°.

**Case B — `disc < 0`, equivalently `l_t < r_a + r_b`.** The tethers cannot reach the
axis, so there is no crossing and no stability limit. The geometry's own end stop is the
rings meeting, at

    δ_touch = acos( (r_a² + r_b² − l_t²) / (2·r_a·r_b) )

which for equal radii reduces to the identity `2·asin(l_t / 2r)`. Past δ_touch the rings
cannot stay apart, so the limit is strength and not geometry: rope break at 3.5% strain
and the ring compression/buckling FoS, both of which the repo already models. **No twist
gate, no torque clamp.**

Verified numerically before it was written down: equal radii R = 0.575, l_t = 1.60 →
δcrit = 100.36°, confirmed a maximum against its neighbours at ±3°; l_t = 2R → 180.0°;
l_t = 0.886 → no limit, rings meet at 100.79°; l_t = 3.60 at R = 2.40 → no limit, meet at
97.18°; Tulloch's Fig 5.25 case (R = 0.4, l_t = 1.0) → 104.48°; R = 0.4, l_t = 4.0 →
90.58°. The identity `acos(1 − l_t²/2R²) = 2·asin(l_t/2R)` holds to 1e-9.

**Open item, not for this change.** The angle at which the lines physically touch, as
distinct from the stability limit and from the 180° axis crossing, has its own curve in
Fig 5.27. No reliable transcription of it exists in the repo. Do not encode a second
angle until someone reads that equation in the thesis text. The 180° crossing condition
is safe as it stands: the lines can reach the axis only when `l_t ≥ r_a + r_b`, because
at 180° the attachment points sit an in-plane distance `r_a + r_b` apart.

Checks against the thesis:

| geometry | this spec | Tulloch |
|---|---|---|
| R = 0.4 m, l_t = 1 m, Fx = 500 N | δcrit = 104.5°, τ_max = 100.0 N·m | Fig 5.25: 104°, 100 N·m |
| ϕ → ∞ | δcrit → 90° | Fig 5.27, minimum 90° |
| l_t = 2R | δcrit = 180° | Fig 5.27 at ϕ = 2 |
| l_t < 2R | no limit | §5.3.1: "not possible for the torsional deformation to reach 180°" |

**What replaces each current use.**

1. **ODE torque clamp** (`rope_forces.jl:566`): saturate at `τ_max` of Case A. In Case B
   apply **no** saturation — torque rises with twist as (4.31) says. This is the change
   that lets a wound shaft actually deliver torque again.
2. **ODE collapse gate** (`objective_evaluator.jl:302–325`): Case A → reject when
   `|Δα| ≥ δcrit`; Case B → do not gate on twist at all. Keep the near-180° guard in
   `ring_forces.jl:467` as a hard numerical backstop, unchanged.
3. **Preload floor** (`initialization.jl:1602–1645`, `:2631–2642`): enforce the sin-law
   demand (correct, keep) and the Case A crossing ratio; drop the Case B ratio.
4. **Placement refusal** (`initialization.jl:1819` area): refuse on Case A violation
   only.
5. **Controller margin** (`soft_ramp_controller.jl`): `margin_i = δcrit_i − |Δα_i|` in
   Case A; in Case B freeze on ring FoS and rope strain, which the controller already
   reads, and delete `_δα_star` for those segments.
6. **DE torsional capacity** (`trpt_optimization.jl:934`): `τ_cap` becomes `τ_max` of
   Case A at the segment's own tether length; for Case B report the tether-tension and
   ring-compression margins instead of a torque FoS. `OPT_TORSION_FOS_REQUIRED = 1.5`
   then applies only to Case A segments — decide in §7 whether to keep it as a margin
   on the stability boundary at all.

**One authority.** All of the above call one exported function, for example
`trpt_twist_limit(r_a, r_b, l_t)::NamedTuple{(:has_limit, :dcrit, :tau_max, :disc)}`.
Four independent copies of a physics criterion is how the repo got here.

---

## 4. Inventory — every site that carries the wrong criterion

**`src/` (7 files, 11 sites)**

| # | Site | Use | Class |
|---|---|---|---|
| 1 | `initialization.jl:1413–1431` `max_segment_cross_ratio(u, sys)` | criterion, state form | criterion |
| 2 | `initialization.jl:1446–1460` `max_segment_cross_ratio(place, sys)` | criterion, placed form | criterion |
| 3 | `initialization.jl:1602–1645` `design_axial_preload` floor | `F_top *= max(demand, cross)·1.05` | preload escalation |
| 4 | `initialization.jl:1860–1880` `trpt_matched_place` refusal | raises on `cross_worst ≥ 1` | refusal |
| 5 | `initialization.jl:2631–2642` settle equilibrium closure | `cross_eq` gates a preload raise | preload escalation |
| 6 | `objective_evaluator.jl:302–325` + `:700–704` | hard reject of the ODE window | gate |
| 7 | **`rope_forces.jl:515–569`** | **torque clamp `τ_sat` in the ODE** | **physics** |
| 8 | `ring_forces.jl:453–479` | damper guard + `T_est`/`k_sec` from a fixed-gap strain | physics (damping) + F4 |
| 9 | `soft_ramp_controller.jl:19–27, 45–49` + impl | `_δα_star`, 5° freeze | controller |
| 10 | `trpt_optimization.jl:926–938` | `τ_cap`, `min_torsional_fos` | DE hard constraint |
| 11 | `objective_v6.jl:768`, `objective_v10.jl:623`, `KiteTurbineDynamics.jl:155` | penalty + export of `twist_collapse_check` | DE penalty |

**Presentation:** `dashboard_v2.jl:527–537` (over-twist flag), `dashboard_panels.jl:40`
(law text — correct as written), `sim_frame.jl:42` (`delta_alpha_deg`).

**`scripts/` (20 files)** — `ode_gate_v13.jl`, `run_v13_5kw.jl`, `tulloch_margin_audit.jl`
(implements the wrong pair as `tulloch_critical`/`tulloch_torque_cap`),
`torsional_collapse_check.jl`, `daisy_ramp_settle.jl`, `daisy_ramp_test.jl`,
`record_ramp_traces.jl`, `record_tuned.jl`, `sweep_v10_postfix.jl`,
`sweep_v10_ring_detail.jl`, `refine_k_priority_rows.jl`, `refine_r1_edge.jl`,
`refine_r2_edge.jl`, `refine_r3_edge.jl`, `p2_checks.jl`, `diag_seg_twist.jl`,
`test_blade_scaled.jl`, `video_claims_analysis.jl`, `control_map_hunt.jl` consumers.

**`test/`** — `test_trpt_realisability.jl` (pins demand and crossing values in §A, §A2,
§E), `test_evaluator_v13.jl` (B6).

**`docs/`** — `DECISIONS.md` [2026-09-20] findings 1 and decisions 3 and 6;
[2026-08-14] torque-saturation entry; [2026-09-25] refusal entry;
`docs/agents/physics-topology.md` §3.2 (the "tighter discrete geometric crossing
limit" sentence); `docs/plans/2026-06-27-soft-ramp-kmppt-v2.md`;
`docs/plans/2026-06-30-control-first-campaign.md`;
`docs/reports/2026-06-30-control-map-findings.md`; `docs/TRPT_Optimisation_Monograph.md`.

---

## 5. Work packages

One package per commit. A failing test first, then the smallest code change that passes
it, then the fast suite, then an acceptance run for any `src/` physics change. A
`DECISIONS.md` entry per package. No package lands on an uncommitted tree.

**WP0 — clear the deck.** The working tree has 11 modified `src/` files and
`test/test_trpt_realisability.jl` is red at line 131; `settle_to_operational_state` on
the campaign seed raises from `trpt_matched_place`. Decide, commit or park that work
before anything here lands. Nothing in this proposal can be measured on a tree whose
seed refuses.

**WP1 — criterion authority.** Add `trpt_twist_limit(r_a, r_b, l_t)` per §3, with the
Case A/B split and the root selection. No call site changes yet.
Tests: table-driven against (5.4) — ϕ = 2.5 → 104.5°, ϕ = 5 → 92.5°, ϕ = 10 → 91.2°,
ϕ → ∞ → 90°; `l_t = 2R` → 180°; `l_t < R_a+R_b` → `has_limit = false`; the Fig 5.25
case → 100.0 N·m; and the seed's own twelve segments → ten "no limit", two 100.3°.

**WP2 — the ODE torque clamp (`rope_forces.jl`).** A consistency change, not a rescue.
Measured, the clamp permits 93–110% of Tulloch's torque over 30–100° on the seed's
classes, so it is nearly inert on these machines and the acceptance traces should barely
move — that is the prediction to falsify. What is wrong with it is provenance and form:
it caps at `τ(δα*)` of a fixed-gap derivation, where Tulloch's ceiling is `τ_max` at
`δcrit`, and it applies a ceiling at all on segments that have no δcrit. Saturate at
Case A `τ_max`; apply no saturation in Case B; keep the 0.95π guard as the numerical
backstop. Tests: static — on a seed segment at Δα = 70° the transmitted torque equals the
rope-derived (4.31) value; a Case B segment at 70° is equally untouched; acceptance —
one 30 s window on the campaign seed, twist and power within a few percent of the
present tree. **Risk:** low, but it touches the ODE, so it goes with WP3, not alone.

**WP2 repair (done, c104737).** The first attempt at WP2 capped each bay in the
line-tension basis, `T_lines·r_a·r_b·sin(δcrit)/l_t`. That product is the peak only at the
limit itself, so the cap bit below δcrit wherever `sin δ > sin δcrit`, and it vanished on
the ϕ = 2 corner: a ϕ = 2.01 bay was cut to 0.66 of its capacity at 60° twist and to zero
at exactly 2.0. The capacity now uses the factored peak form, which is finite at the
boundary, and the tension-basis helper is deleted.

**WP2b — does the drag torque reach the shaft?** Open, and it may be the largest single
error in the TRPT path. The drag force is halved and added to node *forces*
(`rope_forces.jl:437–446`); it is never added to `torques[]`. Whether its tangential
component becomes a shaft torque depends on how a force on a ring attachment node maps
into the ring spin DOF, and nobody has traced that. **Test:** in steady wind, the torques
the bays apply to the rings must sum to the line-drag torque. Do this before WP3b, because
WP3b reads power traces and a missing loss corrupts them.

**WP2c — the drag coefficient decision** (Rod's answer: 1.2 for the scaled campaigns, 2.7
for Daisy-class prototypes, loss reported at both) lands with WP2b, because the size of
the loss is what the test measures.

**WP2d — the transition cone angle.** `objective_evaluator.jl:145` labels `cone_slope_deg
= 22.0` a "TRPT cone half-angle (Tulloch/Jensen reference)" and `objective_v10.jl:264`
uses it as a slope. The thesis says the Daisy TRPT "was designed to have a cone angle of
22°" (extract line 5739) without saying whether that is the apex angle or the half-angle.
If it is the apex angle, the per-side slope is 11° and the repo's transition cone is twice
as steep. The figure settles it, not the sentence. This is the same class of defect as the
one this plan repairs: a citation nobody quoted.

**WP3 — gate and refusal.** `twist_collapse_check` and the two
`max_segment_cross_ratio` methods use the authority. Case B stops gating.
Tests: `test_evaluator_v13.jl` B6 re-based on δcrit; a seed segment at Δα = 70°
(Case B) must PASS the gate.

**WP4 — preload floor and settle closure.** Enforce the sin law and Case A only.
Tests: `test_trpt_realisability.jl` §A and §E re-baselined with the criterion named in
the comment, as that file's own re-baseline rule requires. Expected: the seed's
`F_ax[end]` falls from the raised profile toward the bare taut-split value it was
measured at (1163.72 N on the 2026-09-22 fixture), and the placed twist rises from
~51° to whatever the sin-law floor allows (≤72.25°).

**WP5 — controller margin.** `margin_i = δcrit_i − |Δα_i|` for Case A; ring FoS and
rope strain for Case B. Delete `_δα_star`. Tests: the controller freezes on a Case A
violation and does not freeze on a Case B segment at 70°.

**WP6 — DE capacity and FoS.** `τ_cap` → `τ_max` for Case A; Case B handled by the
existing tension and compression terms. Re-run the seed screen and report the change in
`min_torsional_fos` and in ring mass at fixed power before any campaign. **Expect the
L/r gene's floor to become non-binding** if the crossing floor was the reason for it.

**WP7 — drag coefficient.** One decision (§7), then one value in the ODE
(`TETHER_DRAG_CD`), the prototype builder and the objectives. Report the torque loss at
the rated point against Tulloch's 4.9 N·m (CDt = 1.2) and 9.9 N·m (CDt = 2.7).

**WP8 — re-baseline and record.** `DECISIONS.md` entry superseding [2026-09-20] items
1/3/6; `physics-topology.md` §3.2 corrected; the monograph and the control-map report
annotated; every campaign CSV that carries a physics-era stamp re-stamped and the
affected rows marked, not deleted.

**WP9 — campaign decision.** Re-run the V13 5 kW screen and the soft-ramp k_mppt sweep
only after WP1–WP6 are green and accepted. Do not run a campaign against a mixed tree.

---

## 6. What becomes invalid (honesty list)

- Every `min_torsional_fos`, `collapse_margin_deg` and `twist_crossed` column, and every
  campaign row rejected on those columns.
- The soft-ramp controller tuning (the 5° freeze and the k_mult sweeps) — the freeze was
  triggered by a bound that is 45° tighter than the thesis limit.
- The seed family's preloads, and everything downstream: ring compression, ring mass,
  beam sizing, FoS demand, economics.
- The L/r 2.0 → 1.5 re-seed rationale, and the L/r 1.2 refusal in
  `test_trpt_realisability.jl` §E.
- `scripts/tulloch_margin_audit.jl`'s conclusions, which are built on the wrong pair.
- Any handover or report that quotes "δα* ≈ 54.01°" or "crossing ratio 1.0911" as a
  physical limit.

Provenance: stamp the physics era change on the affected CSVs (Rod's convention:
git hash + physics era + geometry fingerprint). This is a physics-era boundary, not a
tweak.

---

## 7. Decisions for Rod

1. **Drag coefficient.** 1.0 (textbook Dyneema, current), 1.2 (Tulloch's simulation
   default), or 2.7 (what fits his Daisy-8 field data, and what `daisy_builder.jl`
   already uses)? I recommend **2.7 for the Daisy-class prototypes and 1.2 for the
   scaled campaigns**, recorded, with the loss reported at both.
2. **Keep a stability margin at all?** `OPT_TORSION_FOS_REQUIRED = 1.5` on a stability
   boundary is a policy choice, not a Tulloch result. Recommend keeping it as ≤ 1.5 on
   Case A segments only, and setting it in one constant with the policy written down.
3. **Does the ϕ < 2 class need any twist guard of its own?** My recommendation: no angle
   guard, and rely on the rope-break strain and the ring compression FoS the repo
   already computes. But this class covers ten of twelve segments on the seed, so it is
   the decision with the widest blast radius. Worth a day of ODE probing before it is
   fixed in code.
4. **The `L/r ≥ 1.0` seed bound.** `scripts/compute_seeds.jl:141, 170` attributes it to
   Tulloch ("L/r can be as high as 6; minimum ~1.0 for stability"). The thesis's ratio
   is tether length over ring radius (Figs 5.27, 5.29); I cannot find an L/r minimum of
   1.0 anywhere in it. Treat this as an unverified attribution and check it before it
   keeps constraining the search.
5. **Sequencing.** WP0 first. I recommend WP1, WP2, WP3 as one reviewed batch, because
   the clamp and the gate must agree or the ODE will disagree with its own screen.

---

## 8. Verification programme for "authoritative and verified valid"

This defect survived because a formula entered the code labelled with a citation and was
never checked against the source. The repo has the full thesis text in-tree. The
following closes the class of error, not just this instance.

1. **Claim register.** One table in `docs/validation/`: every Tulloch citation in the
   repo (42 files carry his name), each with `file:line`, the claim, the thesis
   equation or page, and a verdict — verified / unverified / wrong. Verbatim quotes with
   extract line numbers, in the style of
   `docs/validation/tulloch-hoop-compression-extract.md`, which is the good precedent.
2. **Check every physics constant attributed to him.** Start with the ones already
   suspected: the numbers in `scripts/daisy_builder.jl` (Cp = 0.20, CDt = 2.7, rigid-wing
   Configuration 8, the taper radii), `scripts/compute_seeds.jl` (the L/r bounds),
   `bem.jl` and `aerodynamics.jl` where the thesis's Cp/λ and rotor data are quoted.
3. **A test per verified claim** where the claim is testable. A formula in a comment is
   a claim with no guard until a test holds it.
4. **Standing rule for the repo:** a physics formula may not carry a citation until the
   citation has been read and quoted in the doc that introduces it. `AGENTS.md` is the
   right home for that rule.

---

## 9. Expected effect, as predictions to falsify

| Quantity | Now (wrong criterion) | After WP1–WP6 | Predicted by |
|---|---|---|---|
| Seed top preload | raised until Δα/δα* ≤ 0.952 | falls toward the bare taut-split profile | crossing floor was the binding criterion (2026-09-20 record) |
| Placed twist | ~51° ceiling | rises to the sin-law bound, ≤ 72.25° | Tulloch: no limit for ten segments |
| ODE torque past 54° | capped at τ(δα*), 93–110% of Tulloch | equals τ_max at δcrit (Case A), uncapped (Case B) | small change; the ODE traces should barely move |
| `twist_crossed` hard rejects | fired at 54–63° on the seed family | should not fire below δcrit, and never on a Case B segment | `objective_evaluator.jl:322` |
| Controller freeze point | ~49° | ~δcrit − 5°, or ring FoS / rope strain in Case B | `soft_ramp_controller.jl` margin |
| Ring compression and ring mass | inflated by preload | falls | preload → tension → compression chain |
| L/r gene floor | binds at 1.0 | becomes non-binding | gate removal |

Two things this change does **not** explain, and which must not be presented as fixed by
it: the 62-revolution wind-up recorded at L/r 1.2 (`DECISIONS.md` [2026-09-25]), which may
have its own cause, and the destructive resonance at `k_mult = 4×`. Re-run both against
the corrected criterion and see whether they stand. If they stand, they are the next
question, not evidence for restoring a mis-derived ceiling.

If those do not move, the diagnosis is incomplete and the next session should say so
rather than proceed.

---

## 10. What this proposal is not

It is not a rewrite of the TRPT model. The torque law, the line model, the load path and
the drag split already match the thesis. It changes one criterion, the three consequences
that were built on it, and the record. It stays inside the existing architecture,
and every change is behind a test.
