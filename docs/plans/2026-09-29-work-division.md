# Work division — 2026-09-29

**Status:** live dispatch. The lead owns this file. Update it when an item lands or a
ruling changes the order.
**Purpose:** one ordered list of the open work, its owner, and the item that blocks it, so
no two agents measure the same tree.

---

## 1. The measured baseline

Taken on this desktop, 2026-09-29.

| Item | State |
|---|---|
| `master` | `fac4c29`, level with `origin/master` |
| Working tree | DIRTY. 10 files modified (+462 / −190), 12 untracked paths. No commit since `fac4c29` |
| Parked branch `wip/d1-site-wind-and-refusal-2026-09-25` | 37 files, +657 / −192. **Pushed to origin 2026-09-29** |
| Parked branch `wip/f11-ring-end-velocity-2026-09-26` | 2 files, +103 / −1. **Pushed to origin 2026-09-29** |
| Fast suite | **2425 pass / 1 fail / 0 errored / 0 broken**, 10 min 31 s. Run 2026-09-29 by the lead on this tree |
| The single red | `test/test_wind_blocking.jl:168`, testset `expansion_params_from_rotors propagates wind_factor`. `0.9 ≈ 0.9085602964160698`. One assertion |
| Acceptance suite | NOT run on this tree |

The parked branches were local to one machine until today. That risk is closed.

## 2. Three sequencing facts that decide the order

1. **No physics measurement is valid on this tree.** The Tulloch plan's WP0 states the rule:
   no package lands on an uncommitted tree. The tree also holds a record defect — see W1.3.
2. **The T8 re-seed screen rests on the criterion that is being corrected.** Ten of the
   seed's twelve segments are in the "no limit" class of Tulloch (4.34). The screen's
   `crossing` column and its REFUSED verdicts use the retired formula. A re-seed against it
   is done twice.
3. **The banked top rotor is double-modelled today.** Verified in the source, not from the
   record: the string `disc_rotor_active` appears in `docs/agents/physics-topology.md:246-247`
   and in no line of `src/ring_forces.jl`. The disc branch runs unconditionally.

## 3. Workstreams

Order is dependency order. Each item names its evidence.

### W1 — Land the banked-top-rotor work (critical path, first)

Owner: **software-worker**. Gate: **software-validator**.

1. **B4 — gate the disc branch.** One ownership predicate, called by the routing and by the
   disc skip. Files: `src/ring_forces.jl`, `src/builders_util.jl`.
   Test: positive net torque at the design point, and at least 80 per cent of the plain-rotor
   spin on the same genome.
2. **Resolve the single red.** `test/test_wind_blocking.jl:168`. Classify first, then act:
   the input is 0.90 and the assertion reads `BF`. It is most likely one assertion.
3. **Correct the record.** `docs/agents/physics-topology.md:244-251` claims a guard that does
   not exist. A record that names a guard the code does not carry is the defect class of
   section 6 of the same document.
4. **Defer B5.** The banked sizing law needs the Phase 5 span law, which sits on the parked
   `wip/d1-` branch. Land that first, then B5.
5. **Gate, then commit in slices.** Fast suite green, then the eight acceptance files
   (~18 min). The commit needs both.

Evidence owed: the fast-suite summary line, the acceptance summary line, and the Slices.

### W2 — The Tulloch criterion, remaining packages (critical path, second)

Owner: **software-worker** for the code; **science-validator** for the re-baseline.
Blocked by W1.

- **WP3** — gate and refusal read `trpt_twist_limit`. A "no limit" segment stops gating.
- **WP4** — the preload floor enforces the sin law and Case A only. Expected: seed top
  preload falls, placed twist rises to the sin-law bound, ring mass falls.
- **WP5** — the controller margin uses `δcrit − |Δα|` for Case A, and ring FoS plus rope
  strain for Case B. Delete `_δα_star`.
- **WP6** — the DE capacity becomes `τ_max` of Case A.
- **WP2d** — the 22° transition cone: apex angle or half-angle. The figure decides, not the
  sentence. Owner for the reading: **aero-validator**.
- **WP8** — supersede `DECISIONS.md` [2026-09-20] items 1, 3 and 6; correct
  `physics-topology.md` section 3.2; re-stamp the physics era on every affected CSV.

WP3 and WP4 go as one batch with the clamp that already landed. The clamp and the gate must
agree, or the ODE disagrees with its own screen.

Evidence owed: `test_trpt_twist_limit.jl` rows 5 and 6, green; the re-baselined realisability
fixture with the criterion named in the comment.

### W3 — The T8 re-seed (critical path, third)

Owner: **science-validator**. Blocked by W2, and by a ruling from Rod on the levers.

The screen measured that line count alone cannot clear the crossing cliff. The levers are the
preload tension, the operating torque through `k_mppt`, the L/r gene, and the lifter margin.
Two of those are rulings, not measurements. Do not start before the ruling.

### W4 — The AeroDyn v5.0.0 driver field order

Owner: **aero-worker**. Independent of W1 to W3. Highest-leverage blocked item.

The run stalls because the driver format is positional and the field order is unknown. Two
routes, in order of cost:

1. Read the order from the AeroDyn v5.0.0 driver documentation.
2. Reuse the driver that produced the current `src/aerodynamics.jl` tables on 2026-06-10.
   That file exists and it parsed.

Trial and error is the wrong instrument for a positional format.

Unblocks: the settle-induction regression, and the expansion-rotor BEM cases.

### W5 — A BEM evaluation for every expansion rotor

Owner: **aero-worker**. Gate: **aero-validator**. Needs Rod's approval per its own section 8.

`docs/plans/2026-09-26-expansion-rotor-bem.md`. Run the main-rotor regression first: it is
the only case with a known answer, and it proves the pipeline.

Closes ledger row C8 (the Cp surface cannot price solidity) and supplies one of the two
candidate causes of the F13 factor.

### W6 — F13, the settle against the dynamics

Owner: **science-validator**. Blocked by nothing, but its polar branch needs W5.

The settle's expansion drive reads 5.695 kW against the dynamics' 2.010 kW, a factor of 2.833.
The decomposition is measured. The two candidate causes are the polar and the inflow the
settle reads. Test the inflow branch first: it needs no new table.

### W7 — The claim register

Owner: **software-validator**. Off the critical path. Directly on the "authoritative and
verified valid" objective.

`docs/plans/2026-09-25-trpt-tulloch-criterion-correction.md` section 8. One table: every
Tulloch citation in the repo, with `file:line`, the claim, the thesis equation or page, and a
verdict. The defect this closes is a formula that entered the code with a citation and was
never checked.

## 4. Decisions for Rod

| # | Decision | Why it blocks |
|---|---|---|
| 1 | The T8 levers: which of line count, preload, `k_mppt` and lifter margin may move? | W3 cannot start without it |
| 2 | Approve the expansion-rotor BEM cases | W5, and one branch of W6 |
| 3 | The wake de-rate: recalled 15 per cent, or the recorded 0.75× power? | It inverts which rotor takes the largest span |
| 4 | The Daisy anchor: 1.5 kW at 10 m/s, or 1.27 kW at the recorded Cp and area? | It sets the ladder's absolute scale |
| 5 | Schedule the spokes requirement recorded 2026-09-26 | It needs a workstream of its own |

## 5. Resource rules

1. **One Julia suite at a time on this machine.** Fast is about 3.5 minutes plus compile;
   acceptance is about 18 minutes. A second run steals the depot lock and the cores.
2. **The AeroDyn runs are a separate binary.** They can run beside a Julia suite.
3. **No physics measurement on a dirty tree.** Name the tree with every number, or wait.
4. **A validator reads the live repo state first.** `git log --oneline -5`, `git status
   --short`, `git diff --stat HEAD~1`. That reading is authoritative over any memory.
5. **F11 stays parked.** Its own plan makes F13 the gate on its magnitude.

---

## 6. Refresh: 2026-10-03 (lead) — repo-fitness items noted

The 2026-10-03 morning repo-fitness analysis names the closing gap. This section
records its intents and requirements in the live plan, not only in chat and
`docs/plans/test_list.md`. Where this section disagrees with §3, this section is
later.

**Intent.** The repo is the instrument for an AWE enthusiast to learn KTD, to
find the design veins worth exploring, and to see the scaling case. The physics
is honest, the results carry provenance, and the winner figures exist.

**Requirement.** Close the step from "strong engine" to "clean, green
checkout": the two red items below plus committing the gate-queue WIP.

| # | Item | State | Next action |
|---|---|---|---|
| 1 | Betz wind-normal projection | RED. `test_betz_ceiling_projection.jl` fails at the reconciliation check (`:231`), re-verified 2026-10-03. Test-list rows 2 and 3 are RED. Closes measured gate leniency of 1.9 % (bank) and 17.7 % (with the 30 deg elevation term) on the bank-derate winner. | Retire the inlined area literal at `objective_evaluator.jl:871` and route both ceilings through `betz_wind_normal_area`. |
| 2 | Acceptance winner repoints | RED. A1 / B6a / B6c / D wait for the derated winner (island 3, 21.698) in `gate_v13`, `evaluator_v13` and `settle_drag`. One cause, no unknowns. | Repoint all three winner paths. Read each check from its own harness, not from the fitness scalar. Detail: `docs/validation/2026-10-01-acceptance-red-inventory.md`. |
| 3 | Commit the gate-queue WIP | The tree holds the uncommitted gate queue; the main tree is still at `4d1b6c9` while origin moved to `f9f3182` (behind 3). `test/runtests.jl` includes three test files that are still untracked. | Land the queue onto `f9f3182` (not the local pointer) in a clean-worktree pass, per the shared-tree rule. The wiring slice goes atomic with it: `runtests.jl` plus the three test files in one slice, once item 1 turns `test_betz_ceiling_projection.jl` green and the `ode_gate_v13.jl` decode refactor is committed with `test_winner_decode_invariant.jl`. Until the pass lands, the main tree is pre-D1; standing rule 3 (no physics measurement on a dirty tree) applies. |
| 4 | D1 site-wind landing (the un-park land) | **LANDED 2026-10-03 on origin**: `bank-derate-cos2p65` at `f9f3182` (three commits: D1 slice `6f4cdbe`, dated DECISIONS entry + `:319` supersession `ac781a6`, fixture re-baseline `f9f3182`). Fast suite **2435/2435**, independently verified at the pushed tip (`docs/validation/2026-10-03-d1-landing-green-verification.md`). The re-baseline was a verdict flip: the L/r 2.0 seed is over the cliff, not repairable inside the 1.5x cap; Section C (L/r 1.5, the campaign seed) stays repairable. Power-split retirement, annulus-span sizing and chord law stay parked. | Rod: retire the L/r 2.0 seed, or keep it live? |

**Next gate chain.** Landed 2026-10-03: the merge pass and the fixture re-baseline. The variant sweep (about five lengths, roughly 1 h, under the frozen-anchor ruling) waits on the last two rulings — §5.3 tether diameter and §5.4 discrete-vs-continuous L. The sweep runner must read the site spec (`hellmann_exponent=SITE_DAISY.shear_exp`), never a re-typed literal; aero-validator's exponent guard covers the shipped library paths, and the script tier is deferred cleanup.

**Claims.** software-worker carries items 1 and 2; the item 4 merge pass landed. hermes carries the queue landing and the wiring slice (item 3). software-validator gates items 2 and 3; aero-validator carries the exponent guard. Rod holds the L/r 2.0 call and the §5.3/§5.4 rulings.

---

## 7. Refresh: 2026-10-06 (lead). Whirl-gate re-base and search-space expansion

Where this section disagrees with §3 or §6, this section is later. The decisions
behind it: `DECISIONS.md` [2026-10-06] (two entries).

**Intent.** Re-pin the sky-anchor whirl gates from the leaked n_b = 2 machine to the
flown 3-on-6 hex machine (Phase 9a re-base), land it on origin, then expand the 5 kW
search space across n_b ∈ {3, 5} × n_lines ∈ {3, 5, 6} with relative-value scoring.
No campaign re-run starts behind Rod's rulings.

### W8. Land the n_b = 3 hex re-base (Phase 9a sky-anchor gates)

Owner: **software-worker** (code in the CoAx repo, at a75bd1d). Gate:
**software-validator**.
Blocked by: nothing. Correction (2026-10-06, software-worker): a75bd1d is a CoAx
commit and has been live on the CoAx origin all along as `sky-anchor-boundary`,
also pinned as `sky-anchor-nb3-rebase` (same sha). KTD object-store searches miss it
because it lives in the CoAx repo. The earlier "must push" blocker is withdrawn.

- New pins: `whirl_stiffness_required(12.6, rpm; n_blades=3)` = 2,073.3 N·m/rad at
  45 rpm, 14,990.5 at 121 rpm. Fail band (58.8, 2,073.3) at 45 rpm, Ω²-scaled
  (424.8, 14,990.5) at 121 rpm.
- `test_sky_anchor.jl:86`: the "free pivot ≈ BPF" identity becomes the sep = 1/3
  check.
- Axial: at 121 rpm it is a rail rebuild (free k ≲ 425, stiff ≥ 14,990), not a
  re-pin.
- Scope catch in the same landing: replace the n_blades = 2 machine default
  (`sweep.jl` both sweeps + options table, `gen_comparison_sweep.jl`,
  `bem_charts_v2.jl`, `compute_radial_loading.jl`, `rotor.jl` docstring,
  `DIMENSIONS.md`) with n_b ≥ 3.
- The DECISIONS entry above holds the measured numbers in case a75bd1d is lost.

### W9. k_mom from the backline, n_lines ∈ {3, 6}

Owner: **aero-worker**. Gate: **aero-validator**. Feeds Rod's side-of-band ruling.

- Tilt/whip stiffness ∝ Σ sin²(θᵢ): 0 (n = 2), 3/2 (n = 3), 3 (n = 6). Hex is exactly
  2× the triangle. Backline k_mom scales with line count, so the side-of-band ruling
  cannot be decided on n_b = 3 alone.
- Deliverable: crossing stiffnesses for hex vs triangle. If the floor reaches the
  machine, the pin belongs there too, not only in the gate.
- Rod approved the bounds edit raised in the room (2026-10-06). The landing commit
  names the file.

### W10. The expanded search space (definition, then screen)

Owner: **science-worker** (definition). The run itself waits on the rulings below.

- Sets: n_b ∈ {3, 5}, n_lines ∈ {3, 5, 6}. Every sweep excludes n_b = 2 (Rod).
- Score relative values across the space, not winners only.
- Blocked by W8, W9 and the rulings below.

### Decisions for Rod (new since §4)

| # | Decision | Why it blocks |
|---|---|---|
| 6 | Crossing-limit definition: centre-touch collapse vs the resistance cliff (Rod asked both readings in the room) | W8's re-pin and W9's crossing stiffnesses are interpretations of it |
| 7 | Is n_blades coupled to n_lines as a genome parameter? | The W10 genome and bounds |
| 8 | The re-base ruling: n_b = 3, transmission pinned at hex (the one-ruling recommendation) | W8's pins, W9's target |
| 9 | The I_t re-derive for the 3-blade BOM | Moves every k_mom pin again |
| 10 | Master merge green-light: origin/master is at `a476ded`. `bank-derate-cos2p65` (D1 + bank derate) and `s2-fold-seed` (30 ahead) are unmerged | Release-facing work and the campaign runner |

### Repo map for this refresh

- `origin/s2-fold-seed`: the live line (this §7 rides on it).
  `origin/bank-derate-cos2p65` = a82cafd. `origin/master` = a476ded (merge pending
  Rod). a75bd1d: sky-anchor re-base tip, live on the CoAx origin as
  `sky-anchor-boundary` (pinned `sky-anchor-nb3-rebase`). One unpushed local commit
  ahead of s2-fold-seed: 7e847a6 (software-worker, bem 4.1 wording), a clean
  fast-forward.
