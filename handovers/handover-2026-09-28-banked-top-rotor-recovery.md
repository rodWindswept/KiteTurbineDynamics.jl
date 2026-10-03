# Handover — 2026-09-28: banked top-rotor recovery (crashed session) and the state it left

> **SUPERSEDED by handover-2026-10-01-bank-derate-and-5kw-rebaseline.md. Top-ring work was reverted after the 2026-09-30 brake measurement. The bank cost now lands as the disc model × cos^2.65.**

**From:** recovery/investigation session (Hermes desktop, 2026-09-28 evening)
**To:** the next session (the WP2 / T8 / WP3 continuation)
**State:** all of the crashed session's edits are on disk and re-verified. **Nothing is
committed.** Fast suite: **2425 pass / 1 fail / 0 error / 0 broken**. The single red is
`test/test_wind_blocking.jl:168` (see §3b). No handover existed before this one.

---

## 0. What happened (read once, then do not re-litigate it)

- The previous session (2026-09-28, 08:22 to 15:57 BST, 91 messages, Hermes desktop,
  model `gemini-3.8-flash`) worked on WP2 (banked topmost rotor) and the T8 screens.
  The work itself is good. Its wrap-up failed.
- Late in the day the session's context window degraded: repeated compactions, and
  payload transfers truncated (the final message reports a 73,184-byte truncation).
  The last thing it wrote was a truncation notice, not a wrap-up. It made **no commit
  and no handover**.
- A file-mutation verifier flagged "7 file edit(s) FAILED" during the day. The session
  audited itself and found the edits had landed. This recovery session **confirms
  that**: every claimed edit is on disk. But three of the session's own summary
  claims do not survive checking (§2).
- The owner's instruction "take those action steps" (15:50) reached the session. It
  started WP3 step 1 and stalled on the AeroDyn driver (see §5). That is where the
  session died.

## 1. Verified on disk (re-verified by the recovery session, 2026-09-28 evening)

| File | What landed | Evidence |
|---|---|---|
| `src/builders_util.jl` | `is_banked_rotor` (`:97`); the top-ring exclusion is now `if rotor.ring_idx == n_rings && !is_banked_rotor(rotor)` (`:112`); a `minimal_hub` gate added. All other diff lines are `scripts/ktd-format` churn | read + diff |
| `src/expansion_analysis.jl` | single blade-mass accounting: `m_blades = has_top_expansion ? 0.0` (`:59-62`); blade-node count guarded (`:72`) | read + diff |
| `src/initialization.jl` | top ring node takes `m_ring` (not `m_rotor`) when the top ring owns an expansion rotor; `m_rotor` zeroed (`:170-171`, `:218`, `:232`) | read + diff |
| `src/ring_forces.jl` | **one hunk only**: the `er.ring_idx == hub_ri && continue` hub guard is removed, so the top ring now receives expansion forces (`:252-257`). The DISC branch was NOT gated. See §3a | read + diff |
| `src/objective_v10.jl` | the only semantic change: knuckle mass added to expansion pricing, `m_expansion += n_lines·(M_BLADE_REF_KG·span³ + OPT_KNUCKLE_MASS_KG)` (`:758-763`). The rest of the 200-line diff is formatting | diff |
| `test/test_banked_top_rotor.jl` | new file; 15 assertions; `scripts/ktd-test-one test_banked_top_rotor` → PASS (re-run) | run |
| `test/runtests.jl` | new test registered (`:65`) | diff |
| `test/test_builders_v10.jl` | hub rotors in the exclusion testsets changed from bank 25° to bank 0° (plain), so the existing exclusion assertions still apply. PASSES (re-run) | run + diff |
| `test/test_wind_blocking.jl` | same bank 25°→0° change, plus three distinct wind factors (0.85 / 0.90 / 1.00) in the propagation testset. **FAILS** | run |
| `docs/agents/physics-topology.md` | records the 2026-09-28 code retirement of the top-ring exclusion | diff |

## 2. Three claims from the crashed session's summary that do NOT hold

1. *"`ring_forces.jl`: guarded the legacy disc rotor thrust and torque with
   `!has_top_expansion`"* — **false.** The string `has_top_expansion` appears nowhere in
   `ring_forces.jl`. The disc branch (cp/ct) at `ring_forces.jl:193-247` runs
   unconditionally.
2. *"…and `build_daisy_system_v5`"* — **no such function exists** anywhere in the repo.
3. *"`objective_v10`: equal power partitioning and BEM annulus span sizing"* — **not
   part of this change.** Both predate it: the equal-share fallback `1/max(n_active,1)`
   and `r_rotor_i = BEM.rotor_radius_for_power(...)` appear in the working tree only as
   reformatting (present in HEAD). The only new term is the knuckle mass.

Also corrected: the summary said `test_builders_v10.jl` "expects all 3 rotors". It does
not. It keeps its 2-rotor expectations with the hub softened to bank 0. The
banked-rotor coverage lives in `test_banked_top_rotor.jl`.

## 3. Open defects, in priority order

**(a) The top ring is DOUBLE-MODELLED when the top rotor is banked.** WP2 plan B4 says
"skip the disc branch". That code did not land. Measured with
`scratch/probe_wp2_disc_gate.jl` (banked seed, ω = 15 rad/s):

- disc-only torque at the top ring = **313.448 N·m** (exactly the disc formula,
  313.44822), so the disc branch still acts;
- canonical physics adds **+44.07 N·m** from the expansion model on the same ring;
- the ring force gains **+182.9 N**.

The plan's invariant is "REPLACES, never both" (plan §3, DECISIONS [2026-09-24]).
Fix direction: gate the disc branch on the same ownership question (the arbitration
function that B2 asks for), and add B4's sign test (positive net torque at the design
point; ≥ 80 per cent of plain-rotor ω).

**(b) `test/test_wind_blocking.jl:168` is the suite's only red.** The testset's inputs
were reworked to distinct wind factors (0.85 / 0.90 / 1.00) but the assertion still
expects `ps[1].wind_factor ≈ BF` (0.9086); it reads `0.90 ≈ 0.9086`. Classify before
touching (T7 rule). The testset's name ("propagates wind_factor") and its inputs imply
the expected value is 0.90. Check the crashed session's intent before editing; the
likely fix is one assertion, not a code change.

**(c) Plan and record updates owed** (the crashed session itself noted "checklist
updates remain uncommitted"):

- `docs/plans/2026-09-24-banked-topmost-rotor.md` still says "Status: not started".
  B1-B3 landed; B4 is half done (routing yes, disc-skip no); B5-B9 open.
- `docs/plans/2026-09-24-phase5-multirotor-sizing.md` still carries the 2026-09-25 T8
  tables. The 2026-09-28 re-run results are in §4.
- `docs/plans/test_list.md` has no row for the banked work. Its current item is the
  Tulloch criterion.
- The instrument trust log and the B9/T9 record updates are not done.
- The phase-5 plan's §5 tasks marked "LANDED" describe the parked branch, not master
  (§6). Its header line ("No code in this document has landed") is stale against its
  own §5. Read neither as the state of the tree.

**(d) The commit is blocked.** Nothing is committed. DECISIONS [2026-09-24] says the
exclusion change "needs its own test and an acceptance run before it lands". The
acceptance suite (8 files, ~18 min) has not been run on this tree. The fast suite must
also be green first (fix (b)).

## 4. T8 screens, re-verified 2026-09-28 (recovery session re-ran all three probes)

Tension audit (fixture genome, frozen 6.901 m, ω = 12.983466 rad/s, L/r 2.0):
`F_ax[end] = 1163.7 N`, **194.0 N/line**, demand **0.867**, seg 4, cross **0.896**.

Seed screen, n_lines 6→16: demand **0.8672 → 0.4504**, cross **0.8959 → 0.3809**, every
row `REPAIRS` (i.e. clears the realisability floor).

Grid (20 points). The L/r 2.0 band is open but NOT uniform across scales:

| scale | lines | demand | cross | verdict |
|---|---|---|---|---|
| 2.00 | 6 | 0.269 | 0.224 | FEASIBLE |
| 2.00 | 12 | 0.558 | 0.494 | FEASIBLE |
| 2.25 | 6 | 0.276 | 0.242 | FEASIBLE |
| 2.25 | 12 | 0.622 | 0.599 | FEASIBLE |
| 2.50 | 6 | 2.126 | 2.540 | **over a limit** |
| 2.50 | 12 | 0.670 | 0.708 | FEASIBLE |
| 2.75 | 6 | 0.045 | 0.033 | FEASIBLE |
| 2.75 | 12 | 0.036 | 0.026 | FEASIBLE |
| 3.00 | 6 | 0.035 | 0.026 | FEASIBLE |
| 3.00 | 12 | 0.029 | 0.021 | FEASIBLE |

At L/r 1.5 every scale below 2.75 is over a limit; 2.75 and 3.00 are FEASIBLE for both
line counts.

**Correction:** the crashed session's summary said "ring scales 2.0 to 3.0 are all
FEASIBLE for both 6-line and 12-line builds". The re-run shows the 2.50 × 6-line cell
fails (demand 2.126). Also several cells are solve runaways, not designs; the response
is not monotone.

Remaining for T8: pin the seed genome vector in `scripts/compute_seeds.jl`, then
re-baseline the dependent fixtures. NOTE: `test/test_banked_top_rotor.jl` includes
`scripts/compute_seeds.jl` (`:11`), so a seed change moves that test too.

## 5. WP3 (settle induction alignment) — where it stopped

- The owner said "take those action steps" (15:50). Step 1 is the AeroDyn pipeline
  proof. The run failed: `ad_driver3.8.inp` is rejected by `aerodyn_driver-v5.0.0`
  with "The variable tMax was not found on line #7". The field order in the scratch
  driver does not match v5.0.0.
- The committed record is `docs/validation/trpt-reference/03-repo-findings.md`
  (2026-09-26 entries, commits `0cdc05b`, `fac4c29`): the bank in the source is
  `ShftTilt`, not a blade curve; `NumBlades = 3` in the source against the repo's 6;
  the old MATLAB writes an `AeroDyn Driver v1.00.x` layout; the stall is the v5.0.0
  driver field order.
- Next step (open, from the findings): get the field order from the AeroDyn v5.0.0
  driver documentation. **No sample input file was found on this machine.** Do not
  continue by trial and error.
- Scratch state: `.scratch/bem_regression/` (git-ignored) holds the four NAS files, a
  NUL-stripped primary copy, and the edited driver.

## 6. Uncommitted and parked inventory (at recovery time)

- Modified (9): the src, test and docs files listed in §1.
- Untracked: the two plan docs (`2026-09-24-*`), the two Tulloch docs (2026-09-25),
  six T8/phase5 probe scripts in `scratch/`, and `test/test_banked_top_rotor.jl`.
- Recovery session additions: `scratch/probe_wp2_disc_gate.jl` (the §3a measurement)
  and this handover. Neither is committed.
- Two old stashes exist (2026-07-19 and 2026-07-22). They are unrelated to this work.

**Parked branches, local to this machine and NOT on origin:**

- `wip/d1-site-wind-and-refusal-2026-09-25` — ONE commit, `3fe6117` (2026-09-25
  15:31), 37 files, +657/−192. This is the **Phase 5 sizing build** (the roadmap's
  Work Package 1): the site-wind standard (`site_wind`, `SITE_DAISY`, `SITE_ANCHOR`),
  the `power_split` retirement (equal share), the annulus span with the one chord
  law, the guards, the reporting fixes, the beam-sizing silent-ω=0 fix (latent on
  master, exposed by the wind change), and the realisability test edits. Master has
  only `annulus_span_for_power` itself (`0fb5b04`), used by its tests alone. The park
  is deliberate: the commit says `wip(parked)` and the Tulloch plan's WP0 says
  "Decide, commit or park that work". Landing it needs a rebase over master since
  the fork at `689c2a1` (master added the Tulloch thread, drag torque and the F13
  series; the src overlap includes `6acb1d8` and `69d1a67`, plus the uncommitted WP2
  edits), then the T7 remainder (`ktd-format`, acceptance run, island re-gate) and
  the T8 re-seed decision.
- `wip/f11-ring-end-velocity-2026-09-26` — `f3d0362` (2026-09-26 10:56): the ring-end
  drag reads `v_centre + ω×r`. Parked with an open magnitude question; master stays
  green without it.
- Neither branch is pushed. One `git push -u origin <branch>` each secures them.

## 7. Suggested order of work

1. Classify and resolve §3b. Then run the full fast suite (`scripts/ktd-julia
   test/runtests.jl`); expect 2426 pass / 0 fail.
2. Finish WP2: B4 (§3a), then B5-B7, then the acceptance suite (B8) and the record
   updates (B9). Update the plan status and `test_list.md`.
3. T8: pin the seed (§4) and re-baseline the dependent fixtures.
4. WP3: obtain the AeroDyn v5.0.0 driver field order, then the regression run
   (plan §3.1, "the only case with a known answer").
5. Parked work (§6): push both branches to origin to secure them; schedule the
   `wip/d1-site-wind-and-refusal-2026-09-25` landing as its own item. Do not mix it
   with the WP2 landing.
6. Commit in reviewable slices. The WP2 landing needs the acceptance run first.

## Suggested skills

- `ktd-test-suite-maintenance` — adding and fixing KTD tests and guards.
- `aerodyn-bem` — the WP3 pipeline, and its `references/bem-table-pipeline.md`.
- `commit-sweep` — when landing the accumulated tree.
- `physics-source-validation` — for the WP3 crosschecks against the source.

## Pointer

Crashed session (Hermes): `20260928_082205_dd8380` (desktop, 2026-09-28 08:22-15:57).
