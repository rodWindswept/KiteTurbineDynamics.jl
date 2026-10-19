# Handover: the science-validator seat, KTD reporting room

**Date:** 2026-10-14. **From:** @science-validator. **To:** the successor session.
**Base:** branch tip `61866f8` on `bank-derate-cos2p65`.
**Updated** 2026-10-15 for the lifting-bridles term gate closure and the corner-grid register read.
**Updated** 2026-10-16 for the bow row NR-059 sign, the 2026-10-15 row set, and the counter-read scope amend.
**Updated** 2026-10-16 for the value-claims ledger counter-read.
**Updated** 2026-10-18 for the NR-060 sign, the counter-read amend, the NR-020 bank note and the T5 close-out rows.
**Updated** 2026-10-18 for the NR-046 re-pin and the NR-061 six-class split sign.
**Updated** 2026-10-18 for the register display round (19 rows print at four significant digits).
**Updated** 2026-10-18 for the NR-062 and NR-063 signs (the fig Batch B metric lists).
**Updated** 2026-10-19 for the section 6.1 phase-2 hold and the G5 candidate.

This page holds the rotation insurance for this seat. It is an index, not a retelling.
The receipts carry the story.

## Live: section 6.1 phase-2 hold (2026-10-19)

**Base draft:** `docs/reporting/drafts/2026-10-08-report-first-draft.md`, md5
`daab51024fbb84460a695de3b7481c75`, 1291 lines / 10,570 words. Nothing has
run against it.

**Measured candidate:** `scratch/sw_probe_full_G5.md`, md5 `6d047d73`, 1298
lines / 10,662 words, STE 22 flags at 0.21 per 100 words (passive 5,
long_sentence 3, nominalization 1, contraction 1, long_paragraph 12,
semicolon 0, em dash 0). The block reads 5 sentences / 63 words. Word leg
`scratch/sw_probe_full_G5_word.md`, md5 `fa851bc0`, 1298 / 10,661.
`scratch/sw_g5_wordleg.py` rebuilds it with a reverse check. F3 `9a7a5d17`,
G3 `4b49cfca` and G4 `a825aaef` are spent. `diff G3 G5` is one line, the
block's third sentence.

**The state chain.** F3 is dead: its two absolutes print false against the
bridle segments at `src/initialization.jl:342-359` (`BRIDLE_EA` 500 kN at
318) and `src/aerodynamics.jl:349`, which says only the blade bridle lines
are absent. G4 is dead too: "nothing here can check" prints false because
`src/rope_forces.jl:342` iterates every sub-segment,
`get_subsegment_tension` runs at `:404-412`, and the bridle break test runs
each step at `:618-620` against `ROPE_BREAK_STRAIN` 0.035 (`:89`). G5 keeps
the capability word out. Its claim is true: no gate covers a bridle segment.
`get_max_rope_tension` loops only the shaft tethers at `:173-190`, gates 4
and 6b read `cumulative_thrust` at `src/objective_v10.jl:634-666`, and no
output column carries bridle tension.

**The candidate's hunks, from `diff base candidate`.** The diff is the
authority; the room's line numbers refer to different states.

- 168: `ring plane` to `plane of rotation`.
- 1115: `A lag short of 90 degrees turns the tilt azimuth.` to `The tilt
  azimuth turns whenever the rotor phase lag is not zero.`
- 1116: `The bank and steer then act...` to `The tilt and steer then act...`
- 1117: insert `If the lag exceeds 90 degrees, the part of the tilt along
  the intended axis reverses sign.`
- 1118: drop the `bank,` list item. `The tilt gives side force and moment:
  steer and load relief.`
- 1149: `bank and steer` to `tilt and steer`.
- 1162-1164: `That check supplies the phase lag the sweep varies.` to
  `Check the ring tilt against the rim bridle.` / `Until they run, the rotor
  phase lag stays a free parameter.`
- 1166-1169: the four-line bridle block (G5):

  > A tether-to-blade bridle holds the blade tip down, from the underside,
  > the concave side of the chord.
  > The model carries no tether-to-blade bridle. It gives every blade one
  > bank angle, all the way round.
  > No such bridle exists to go slack, so nothing here checks that it stays
  > loaded.
  > So the bridle rule binds only on a design the genome cannot yet
  > generate.

**Rulings signed at this desk.**

- The 1118 drop loses no axis. The paragraph names the roll response at
  1115-1116 (`tilt`); the dropped item restates it. Do not later trim
  `the tilt and steer` as redundant with the list. The roll axis lives only
  there.
- The underside bridle works against thrust, and thrust acts round the whole
  turn. The restraint is azimuth-uniform. The upwind half is where it is
  hardest pressed, not where it exists. The block is side-neutral and prints
  under either answer.
- The condition a future model can check is bridle tension positive round
  the turn, the draft's own tension-member rule at 142-143, never a tip
  height.
- G5 is the true form and its words are load-bearing. `Nothing here checks
  that it stays loaded` must not shorten to `checks a bridle load`. The
  solver computes bridle tension (`src/rope_forces.jl:342,404-412`),
  break-tests it (`:618-620`), the test suite asserts a lifting-bridle
  tension (`test/test_bearing_alignment.jl:234-237`), and the sizing path
  returns `min_fos_bridle` (`src/trpt_optimization.jl:778,1086-1101`).
  None checks that a load persists round the turn. Only `stays loaded` is
  true.
- Do not trim the two `so` clauses in the block. Each closes a different
  premise.

**Open, founder only.**

1. Bless the G3 block at 1166-1169.
2. Keep the gene name `bank` or rename the section 6.1 command. G3 already
   carries `tilt` at 1116 and 1149. A gene rename moves the plates and their
   captions, so it is not a prose-only pass.
3. The direction clause at 168 is a possible seventh block. The verb is
   `chooses`, not `magnitude`; `magnitude` has 0 hits. If it lands, re-measure
   and only then declare.

**Do not run `scratch/au_sec61_phase2.py`.** Its `B_NEW` still inserts the
retired rule (`**Azimuth-resolved bank.** The windward blade tip stays at or
above the root plane through the upwind half of the rotation.`), and its
declared POST `207bd022` / 1297 / 10,662 is stale. It would write the dead
gate into the draft. G3 exists as the committed scratch files, not as an
in-place script.

**Checks run at this desk, 2026-10-19.** Base md5, lines and words as above.
Whole draft: 0 lines carry a semicolon, `ring plane` 1 (168), `plane of
rotation` 0, `azimuth-resolved` 1, `bridle` 6, `unbridled` 1, `genome` 19,
`magnitude` 0, `concave` 0, `under-side` 0, `roll` 0. `cosd(bank)^2.65` sits
at `src/ring_forces.jl:235` and `src/bem.jl:142,150`, magnitude only.
`src/objective_v6.jl:8,31` states the downward lean in words.

## What this seat does

This seat checks the numbers that enter the report.
It signs register rows from the raw data.
It audits claims against signed rows, and it runs the counter-reads the room routes here.
One rigorous read per gate, and the sign-off stays at this desk.

The audit checks can fan out to sub-agents when the sections are independent.

## Open items

1. **The section 6.1 phase-2 run (live section above).** The G5 candidate is
   measured at `6d047d73` with word leg `fa851bc0`. Release waits on two
   founder calls: bless the bridle block, and keep-gene or rename-command.
   The phase-2 script is stale and must not run.

2. **PL12 verification facts, on request.** The part 13 fold by @author (references
   and data availability) draws its verification facts from this seat. The section 7
   line "Fifteen of eighteen" moves with that pass.

3. **The Nomenclature fold.** The fold runs with the lead and the SW seat. The
   lifting-bridles rename now reads through the candidates, the notes, the
   stale-phrases list, the plate kit, the desk amends and the copy v0.49.
   The reading holds at one form.

4. **New rows before print.** Any new value in the polish round, the figure builds,
   the corner build or the item-5 extract takes a register row and a sign at this desk.

5. **T5 close-out rows.** T5-1 unsigned failure-ledger numbers and T5-2 Daisy anchor values take register rows and signs at this desk before the release close-out.

## Closed, last (evidence index)

- The NR-062 and NR-063 signs land at `bfb2896`. The fig Batch B metric cards get their values. The strip milestones print P_mean and P_end at 5.85/5.86 down to 5.31/5.31. The corner picks print P_mean and P_end at 6.01/6.07, 5.33/5.36, 5.59/5.59 and 5.9/5.9. The objectives cross-check NR-036 and NR-051 digit for digit. The telemetry parity reads bit for bit. Receipt `docs/reporting/room-responses/science-validator-2026-10-18-fig-metric-lists-sign.md`. Checker `scratch/sv_fig_metric_lists_check.py`, 44 checks, 0 fail.

- The register display round lands at `33dfe32`. The 19 science rows with long decimals print at four significant digits. The fitness rows print the unit kg-equivalent. The NR-053 dastar form moves to δα*. Full precision and the NR-043 sha256 move to `docs/reporting/register-manifest.md`. Evidence `scratch/sv_register_display_2026-10-18.log`. The aero half landed at `d498ab9`. The register appendix Status-column collapse sits with the builder seat. All 61 rows read signed at this desk's count.

- NR-061 signs at `df2d27d`. The six-class split re-derives at the producing commit a76c5e9. The counts read betz_cp_floor 93, settle_fail 37, spacing 36, rope_break 30, betz_ceiling 3, hub_tip 2. One row moves against the HEAD re-run. Island 3, gen 8, idx 4 reads hub_tip at HEAD and rope_break at the producing commit. The draft sections 3.1 and 5 must move from 29 and 3 to 30 and 2. Receipt `docs/reporting/room-responses/science-validator-2026-10-18-nr061-six-class-split.md`. Merge `scratch/sv_reject_sixclass_a76c5e9/sv_reject_sixclass_merge.py`, 317 checks, 0 fail. Counter-read open at the aero seat.

- The NR-046 amend lands at `0d9a375`. The evaluator pins re-pin past `2bf76a3`. The shift reads plus five. The corrected set reads `src/objective_evaluator.jl:90-91, 1153, 1166, 1197-1199, 1205-1208` at blob `5c626ff5`. Checker `scratch/sv_nr046_repin_check.py`, 23 checks, 0 fail.

- NR-060 signs at `c3ef25b`. The row carries the R5 signed axial force at the winner capture, -157.622 to -142.792 N, three beams in tension. The sign is an own re-run, parity bit-exact on nine cold re-eval fields. Receipt `docs/reporting/room-responses/science-validator-2026-10-18-nr060-r5-axial-sign.md`. Checker `scratch/sv_r5_axial_sign_check.py`. The push carried 17 held commits to origin.

- The NR-060 counter-read closes at `b90e64c` with two text defects. The amend and the strengthened checker land at `3a6ddde`. The checker now reads 76 checks, 0 fail, with the parity loop asserting each field line. The NR-020 bank note lands in the same packet and closes T4-15. Receipt `docs/reporting/room-responses/science-validator-2026-10-18-nr060-amend-nr020-bank-note.md`.

- The value-claims ledger counter-read closes at `ba1a66f`, read at `f38d19a`. The measured census reads one HOLD row and zero printable. The rung set matches `const RUNGS` digit for digit, and every pointer resolves. One class-line proposal rides for the aero seat. Receipt `docs/reporting/room-responses/science-validator-2026-10-16-value-ledger-counterread.md`. Checker `scratch/sv_vcl_counterread_check.py`, 34 checks, 0 fail.

- The bow row (NR-059) signs at `7aaf2ea`. The aero winner-bow read at `c6d2885` reproduces at `650fa49`. The re-run matches the committed log line for line, apart from the git header and the four wall-time lines. The logs compare across 127 lines.

- Receipt `docs/reporting/room-responses/science-validator-2026-10-16-bow-register-sign.md`. Checker `scratch/sv_bow_sign_check.py` reads 41 checks, 0 fail. Counter-read closed at the aero seat (`271182b`) with one scope amend landed here (`5b2cfd9`). The sideways bound reads over the extension series and from t=38 s onward. Amend receipt `docs/reporting/room-responses/science-validator-2026-10-16-nr059-scope-amend.md`.

- The 2026-10-15 row set joins the index. The torsion rows and the convergence series land at `2142d43` (NR-052 to NR-054), receipt `docs/reporting/room-responses/science-validator-2026-10-15-torsion-rows-floor-and-series.md`.

- The reject split and the environment reads land at `a51e9d9` (NR-055 to NR-058), receipt `docs/reporting/room-responses/science-validator-2026-10-15-301-split-and-item21-rows.md`. The convergence read with the NR-006 answer and the v0.55 fold read land at `1b09190`, receipt `docs/reporting/room-responses/science-validator-2026-10-15-convergence-register-read.md`.

- The post-fix warm fold lands at `fab730a` (NR-013 ext2), receipt `docs/reporting/room-responses/science-validator-2026-10-15-postfix-warm-register-fold.md`. The PL12 ruling facts land at `84ac158`, receipt `docs/reporting/room-responses/science-validator-2026-10-15-pl12-ruling-facts.md`.

- The corner-grid register read closes at `a196183` (the fold `1061878`, base `fc3a602`). The receipt set lands at `9f6a724`.

- The drawn set reads NR-051 to the signed digits. The four objectives, the tags and the corner names each read once, in the signed order. The numeral census reads clean, and the source chain binds (telemetry, extract, register, mint log). The seat marker cites NR-044 and NR-051 only. The fold delta reads exact (12 added lines, 2 removed).

- Receipt `docs/reporting/room-responses/science-validator-2026-10-15-corner-grid-register-read.md`. Checker `scratch/sv_cg_register_read_check.py`, 107 checks, 0 fail. The log sits beside it. The figures seat checker re-runs green at this seat (54 checks).

- The lifting-bridles term gate re-reads clean at `459eee2` (content `f80cbcf`, the domain amend `5ebbc3c`). The drawn set, the copy v0.49, the term set and the two closure flips read. The two reader-name amends land at the desk docs. The census classifies 428 bridle files and 166 hero files, zero unclassified.

- Receipt `docs/reporting/room-responses/science-validator-2026-10-15-lifting-bridles-term-gate.md`. Checker `scratch/sv_br_term_gate_check.py`, 105 checks, 0 fail. The log sits beside it. The aero counter-reads on the relabel and the re-keys stand at the aero desk.

- The round-6 term gate re-reads clean at `e6122a2` (`8be6be9`). The naming legs close. The five form notes hold. The delivered copy reads v0.47 with the retired word at 5, every one a register-appendix hold.

- Receipt `docs/reporting/room-responses/science-validator-2026-10-15-round6-term-gate-reread.md`. Checker `scratch/sv_r6_term_gate_v2_check.py`, 76 checks, 0 fail. The log sits beside it.

- The round-6 term gate clears at `d0ed902`. The ten signed forms, the note amend and the six delivered art files read clean. The census classifies 3,723 lines across 826 files.

- Receipt `docs/reporting/room-responses/science-validator-2026-10-15-round6-term-gate.md`. Checker `scratch/sv_r6_term_gate_check.py`, 58 checks, 0 fail. The log sits beside it.

- The round-6 signs land at `cb862df`: the hub forms, the count glance, NR-051 and
  the physics-topology amend (ten draft sites, five plates, three kits).
  Receipt `docs/reporting/room-responses/science-validator-2026-10-14-round6-signs.md`.

- The two round-6 checkers read green: `scratch/sv_r6_hub_forms_check.py` (25 checks,
  0 fail) and `scratch/sv_r6_count_nr051_check.jl` (38 checks, 0 fail).

- The item-5 lever-statistics counter-read closes: no discrepancy found. Receipt
  `docs/reporting/room-responses/science-validator-2026-10-14-item5-counterread.md`.
  Checker `scratch/sv_item5_counterread.py`, 173 checks, 0 fail. The seat checker
  re-runs green, 23 checks (`scratch/sv_item5_figcheck_rerun.log`).

- The k-sweep display rows sign: NR-047 (six loads, one row per k, the omega
  column named `omega_final`) and NR-048 (the sizing-side pair). Receipt
  `docs/reporting/room-responses/science-validator-2026-10-14-k-sweep-rows-sign.md`.
  Checker `scratch/sv_nr047_k_sweep_rows_check.py`, 46 checks, 0 fail.

- The term gate on the round-4 rename cleared at `bb1709d`. Receipt
  `docs/reporting/room-responses/science-validator-2026-10-14-term-gate-soft-constraint-penalties.md`.

- NR-046, the objective seam, signed at `4a86e6f`. The aero counter-read closes it at `9d96a4b`.
  Receipts `docs/reporting/room-responses/science-validator-2026-10-14-objective-seam-row.md`
  and `.../aero-validator-2026-10-14-nr046-counterread.md`.

- The claim-by-claim audit certifies draft v0.33 at `90cd692`. Receipt
  `docs/reporting/room-responses/science-validator-2026-10-14-claim-by-claim-audit.md`.

- The citation checker, blessed in this push. It ran clean on the delivered revision:
  34 cited rows, all signed, exit 0. Draft and register both sit at `5a7a6b4` state.

- A negative control flags an unsigned cite. The tool sits at
  `scratch/sv_check_draft_citations.py`, and the run log at `scratch/sv_check_draft_citations_v032_bless.log`.

- The SV2 audit certifies the claim-evidence matrix: `2074a5d`. Receipt
  `docs/reporting/room-responses/science-validator-2026-10-14-sv2-audit-claim-evidence-matrix.md`.

- NR-045, the island generation counts: `6255268`. Receipt
  `docs/reporting/room-responses/science-validator-2026-10-14-nr045-generation-counts.md`.

- NR-044, the PCA projection summary, and the delta-crit close-out: `2ad023c`. Receipt
  `docs/reporting/room-responses/science-validator-2026-10-13-nr044-signed-and-dcrit-closeout.md`.

- The display rulings land at `d7f8871`. FoS prints 15.0 at the report sites. The
  section 3.3 report forms hold. Receipt
  `docs/reporting/room-responses/science-validator-2026-10-13-display-rulings-and-f1-v4-read.md`.

Earlier close-outs (SV5 to SV7, NR-042 and NR-043, the F1 census reads) sit in
`docs/reporting/room-responses/` under the `science-validator-` prefix.

## Boot

- Repo `KiteTurbineDynamics.jl`, branch `bank-derate-cos2p65`. Fetch first. Every
  seat pushes to this shared tree.

- Read `handovers/handover-2026-10-08-reporting-room-boot.md` and the rulings page
  beside it. Then the register at `docs/reporting/numbers-register.md`.

- Load the skills `ktd-verification` and `ktd-doc-landing` before the first read.

- Nothing of this seat lives only in a chat. This page plus the receipts resume the
  seat in one readback.

## Working rules

- Cite only signed rows. Recompute from raw data, never re-read a prior report.

- Stage only your own paths. Peers may hold staged files in this shared tree.

- Add evidence logs with `git add -f`. The `*.log` pattern sits in `.gitignore`.

- Run `python3 ste-lint.py --fail-above 2.0` on a new file before the commit.

- Verify the push. The local branch matches origin, and each blob reads byte-identical
  at origin.

- Never run `git clean` in this tree. The untracked files carry seat evidence.

- Route findings through the room and the receipts. Do not post to the Signal Note to
  Self channel (TEAM_CHARTER section 4). The mechanics sit in
  `docs/reporting/room-responses/aero-validator-2026-10-12-signal-silence-mechanics.md`.

**Owner:** @science-validator. **Next action:** the section 6.1 phase-2 hold is the first item. G5 is measured at `6d047d73` with word leg `fa851bc0`; release waits on Rod's two calls (bless the bridle block, keep-gene or rename-command). Do not run the stale phase-2 script. Behind it: the draft fold for sections 3.1 and 5 waits on the author and hermes. The register Status-column collapse waits on the builder seat. The fig Batch B metric cards are unblocked. The T5-1 and T5-2 rows sign at this desk before the release close-out. The PL12 verification facts stand on request.
