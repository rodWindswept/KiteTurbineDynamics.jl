# Handover: the author seat, KTD reporting room

**Date:** 2026-10-19. **From:** @author. **To:** the successor session.
**Base:** branch `bank-derate-cos2p65`, tip `20669bc`. Fetch first. Every seat pushes to this shared tree.

This page holds the rotation insurance for this seat. It is an index, not a retelling.
The receipts carry the story.

## What this seat does

This seat owns the report draft: the folds from review input and seat rulings,
the tracker entries, the receipts, and the review-copy rebuilds.
The draft is a single-writer file. The fold chain stays single-desk.
The parallel work is the audits and the extracts the other seats run.

## Live: the section 6.1 phase-2 hold (2026-10-19)

One pass waits on two founder calls, and the script on disk is not the text that will run.
The script is `scratch/au_sec61_phase2.py`, pinned at base `daab5102` (1291 lines, 10,570 words, STE 22 at 0.21).
The draft on disk is still the base. The block and the line edits are ruled below, at G4.

**The six blocks the pass will print.**

1. `The bank and steer then act off the intended axis.` (1116) takes `tilt and steer`. The authority question at 1148 takes the same pair.
2. The list item at 1117 drops. The line reads "The tilt gives side force and moment: steer and load relief."
3. 1107 takes no defining clause. The clause leaves the plan.
   Base numbers hold below 1115 only. The pass adds one line at 1115, so later numbers move by one. The quoted text decides.
4. 168 takes `plane of rotation` in place of `ring plane`.
5. The gate block prints after the test list, at 1164.
6. The script re-declares PRE once and POST once. The word patch re-keys once.

**The gate block, final form.** Five sentences, 64 words, lengths 17 / 6 / 11 / 16 / 14, longest 17, no semicolons, no em dashes. No bold lead: six bolded leads exist in the whole draft, all document-part labels, none between 1100 and 1180.

> A tether-to-blade bridle holds the blade tip down, from the underside, the concave side of the chord.
> The model carries no tether-to-blade bridle. It gives every blade one bank angle, all the way round.
> No such bridle exists to go slack, so nothing here can check that it stays loaded.
> So the bridle rule binds only on a design the genome cannot yet generate.

**Two rulings from this desk, and both narrow.**

**The name.** "Azimuth-resolved bank" was the title of the old gate. That gate held the windward tip at or above the root plane through the upwind half. Rod inverted it. The tips are held down, on the underside, the concave side of the chord. The science-validator ruled the restraint azimuth-uniform, because thrust acts round the whole turn. So the old name would print on a block that rejects the old rule. `azimuth-resolved` also carries one other sense in the draft, at 1152, where it names the BEM. The block's subject is bridle load, so the closing sentence names that.

**The scope.** F3's "remains unbridled" and "No bridle exists" both print false. The model carries the lifting bridles as N rope segments at `BRIDLE_EA` 500 kN (`src/initialization.jl:342-359`) and it carries the rim bridle. The draft names both, at 648 and 1143. Only the tether-to-blade set is absent: 986, and `src/aerodynamics.jl:349`. G3 fixes the first absolute. Its second sentence still ends wide, because "no design in this report can check that a bridle stays loaded" covers the bridle sets the model does carry. So the conclusion takes the same scope as its premise: **"so nothing here can check that it stays loaded."** No gate or output in the chain reports bridle tension, so the scoped claim holds. `get_max_rope_tension` counts shaft tethers only.

**The states, measured at this desk with `ste-lint.py`.**

| State | md5 | lines / words | STE | word leg |
|---|---|---|---|---|
| F2, carrying the dead name | `559ce2dc` | 1298 / 10,665 | 22 / 0.21 | `e76c8223`, 1298 / 10,664 |
| F3, two false absolutes | `9a7a5d17` | 1298 / 10,664 | 22 / 0.21 | `a308305d`, 1298 / 10,663 |
| G3, one absolute left | `4b49cfca` | 1298 / 10,667 | 22 / 0.21 | `faf3d9a6`, 1298 / 10,666 |
| **G4, the ruled text** | **`a825aaef`** | **1298 / 10,663** | **22 / 0.21** | **`c5d1ebda`, 1298 / 10,662** |

All four read long_sentence 3, passive_voice 5, long_paragraph 12, semicolon 0, em dash 0.
G4 is one line from G3: `No such bridle exists to go slack, so nothing here can check that it stays loaded.`
The files are `scratch/au_g4_candidate.md` and `scratch/au_g4_word.md`, both at origin.
The G3 files are `scratch/av_g3_candidate.md` and `scratch/av_g3_word.md`. They stay as provenance.
The declared result inside the script, `207bd022` at 1297 / 10,662, is stale. Do not re-open it.
F2, F3 and G3 are spent. G4 is the target. D2 and F1 went before them.

**The earlier repairs, and what became of them.** `remains unbridled` was chosen to keep the passive count at 5. G4 retires that line, because "carries no tether-to-blade bridle" is active, so the passive count still reads 5 and `is unbridled` would still cost one flag.
"Nothing in the model can go slack" was false, because slack is modelled and gated at `src/objective_v10.jl:8`, `src/initialization.jl:1197` and `src/dashboard_v2.jl:536`. G4 scopes that claim to the absent bridle.

**Do not run the phase-2 script.** `scratch/au_sec61_phase2.py` still inserts the retired bold rule, `**Azimuth-resolved bank.** The windward blade tip...`, and it declares POST `207bd022` at 1297 / 10,662. Both are dead. G4 exists as a committed candidate pair, not as an in-place script. Write the phase-2 script from the G4 pair before the next run.

**Do not trim, after the pass.** Two lines carry a load a later trim would drop.

- 1116, `the tilt and steer`. Once the 1117 item goes, this line is the only statement of the roll axis.
- The two `so`s in the gate block. Each closes a different premise. Take the second away and the rule reads as enforceable.

**What a successor must not re-derive.** Every item is measured, not argued.

- `ring plane` has one hit, at 168, in the sentence that defines bank. `plane of rotation` has 0. The substitution leaves no orphan term.
- 986 already carries the absence in the draft's words: "better than the unbridled model assumes... The model does not include it." `unbridled` has one hit.
- 142 carries the predicate: "A line is a tension member, like a tether or a bridle. It carries a load only in tension." Bridle tension is the checkable quantity, never tip height.
- `bridl` has six hits and four members: stiffening bridles at 32, lifting bridles at 648, tether-to-blade bridling at 986, rim bridle at 1142. The block names the member, not the family.
- `genome` has 19 hits. `magnitude`, `roll`, `concave` and `under-side` have 0 each.
- No plate moves under this plan. Every printed `bank` in the figure set is gene-sense, and the figures seat holds the census.

**Still blocked, on Rod only.** The gate text and the keep-gene or rename-command choice. Nothing runs until both land. Then the science-writer seat re-measures G4, and the aero seat declares the chain.

## Open items

1. **The section 6.1 phase-2 hold (above).** My lane is closed on it. The wording is ruled and measured, the script waits on the two founder calls, and no other author work moves until it runs.

2. **The partner-gated tails.** The section 4.1 path table and the 4.3 tables wait on AU4.
   The scope statement keeps its one home in the AU1 limits paragraph.
   The twist-prose basis fold waits on the floor row.
   The "Fifteen of eighteen" line moves with the PL12 pass on @hermes facts.

3. **The era pack, the remainder.** The pack blocks fold at `c9f0560`, and the era map at `34e3f81` (AU7).
   The development-history chapter push reads next.

4. **The Nomenclature fold.** The term gate cleared (`cadf83d`). The fold runs with the lead and the science-writer seat.

5. **The review copy.** Rebuild `draft-live.docx` after every draft-moving pass.
   Verify the build record, the seat count and the version pin.
   Name the delta from the copy the founder holds.

6. **The value-track close.** The close supply hands to the science-writer prose pass (`scratch/au_v058_close_supply.md`). The fold waits on that pass. The ladder plate folds into the close after its read closes (counter-reads: aero, science). The caption pass lands (`docs/reporting/figures/scaling-ladder/captions.md`).

## Closed, last (evidence index)

- The house-vocabulary swap pass (2026-10-18).
  Draft line 1024 and the value-claims-ledger row 29 take the pipeline.
  Fold `a9dc348`, two-state script `scratch/au_seatchecks_fold.py`.
  Citation checker exit 0 (56 cited, every one signed). STE totals hold on all three surfaces.
  Receipt `docs/reporting/room-responses/author-2026-10-18-house-vocab-swap.md`.

- The v0.63 B-20 and B-21 prose pass (2026-10-18).
  The decoder and gate math lands at section 2, and the steady-and-drifting pair lands at section 3.3.
  Fold `3290876`, two-state script `scratch/au_b20b21_fold.py`.
  Citation checker exit 0 (56 cited, every one signed). STE totals hold (draft 34, tracker 24, routing 7).
  Receipt `docs/reporting/room-responses/author-2026-10-18-b20b21-fold.md`.

- v0.63, the B-20 and B-21 fold: commit `3290876`.
  Section 2 prints the r_rotor sizing form, the decode, the score definitions and the full gate list.
  Section 3.3 prints the two-timescale pair and the two-station bound with the 200-second scope.

- The v0.57 winner-bow-read pass (2026-10-16): the NR-059 read folds at section 3.3.
  Fold `c825a01`, 3 anchors and 33 guards closed.
  Review copy rebuilds (record `c825a01`, live md5 `3b92d088…`, byte-identical to `draft-c825a01-20261016-132638.docx`).
  Check `scratch/au_v057_rebuild_check.py`, 43 checks, 0 fail.
  Receipt `docs/reporting/room-responses/author-2026-10-16-v057-bow-read.md`.

- v0.57, the bow-read fold: commit `c825a01`.
  Section 3.3 prints the winner bow read (NR-059), after the settle-state paragraph.
  The settle/run disagreement reads as an instrument finding.

- The v0.56 era-pack pass (2026-10-15): the era phrase, the ledger dates and the back-pointer fold.
  Fold `c9f0560`, 5 anchors and 39 guards closed.
  Review copy rebuilds (record `c9f0560`, live md5 `5ecee42e…`, byte-identical to `draft-c9f0560-20261015-215702.docx`).
  Check `scratch/au_v056_rebuild_check.py`, 52 checks, 0 fail.
  Receipt `docs/reporting/room-responses/author-2026-10-15-v056-era-pack.md`.

- v0.56, the era-pack fold: commit `c9f0560`.
  Section 3.1 prints the wind-authority era phrase.
  Section 4.2 reads in date order, and the back-pointer lands at the load block.

- The v0.55 split and environment pass (2026-10-15): the reject split prints and the item-2.1 environment set closes.
  Fold `2e930a8`, 6 anchors and 40 guards closed.
  Review copy rebuilds (record `2e930a8`, live md5 `4c438414…`, byte-identical to `draft-2e930a8-20261015-212715.docx`).
  Check `scratch/au_v055_rebuild_check.py`, 69 checks, 0 fail.
  Receipt `docs/reporting/room-responses/author-2026-10-15-v055-split-and-env.md`.

- v0.55, the split and environment fold: commit `2e930a8`.
  Sections 3.1 and 5 print the three-way reject split (NR-055).
  Section 3.3 prints the shear law and the shaft elevation rows (NR-056, NR-057).
  The swing sentence prints its steady-wind basis note (NR-058).

- The v0.54 operating-point and torsion pass (2026-10-15): the winner operating point completes and the torsion clause folds.
  Fold `d453530`, 5 anchors and 36 guards closed.
  Review copy rebuilds (record `d453530`, live md5 `72ef99be…`, byte-identical to `draft-d453530-20261015-202520.docx`).
  Check `scratch/au_v054_rebuild_check.py`, 65 checks, 0 fail.
  Receipt `docs/reporting/room-responses/author-2026-10-15-v054-opoint-torsion.md`.

- v0.54, the operating-point and torsion fold: commit `d453530`.
  Section 3.3 prints the wind, the ratios, the swept-area set, the air density, the rotor Cp and the Betz check (NR-031 to NR-034).
  The gate block prints per class, with the torsion criteria and the realisability floor (NR-052, NR-053).

- The v0.53 fixed-defect pass (2026-10-15): the rope-break fixed defect reads across the draft.
  Fold `89ed222`, 10 anchors and 52 guards closed.
  Review copy rebuilds (record `89ed222`, live md5 `e1eaef43…`, byte-identical to `draft-89ed222-20261015-181801.docx`).
  Check `scratch/au_v053_rebuild_check.py`, 62 checks, 0 fail.
  Receipt `docs/reporting/room-responses/author-2026-10-15-v053-fixed-defect.md`.

- v0.53, the fixed-defect fold: commit `89ed222`.
  Section 4.1 reads the corrected defect, and the fix-state references across the draft take the fixed state.

- The v0.52 basics-of-TRPT refresher (2026-10-15): the operation block recovers the working chain.
  Fold `b6cd166`, 3 anchors and 25 guards closed.
  Review copy rebuilds (record `b6cd166`, live md5 `3c386dc2…`, byte-identical to `draft-b6cd166-20261015-163115.docx`).
  Check `scratch/au_v052_rebuild_check.py`, 50 checks, 0 fail.
  Receipt `docs/reporting/room-responses/author-2026-10-15-v052-trpt-basics.md`.

- v0.52, the refresher fold: commit `b6cd166`.
  The block lands at section 2.1, ahead of the system-anatomy figure.

- The v0.50 kMppt plain pass (2026-10-15): the structural side of the load story takes plainer sentences.
  Fold `171f3ea`, 5 anchors and 26 guards closed, tokens add 50 and remove 49.
  Review copy rebuilds (record `171f3ea`, live md5 `ae15d991…`, byte-identical to `draft-171f3ea-20261015-154001.docx`).
  Check `scratch/au_v050_rebuild_check.py`, 47 checks, 0 fail.
  Receipt `docs/reporting/room-responses/author-2026-10-15-v050-kmppt-plain.md`.

- v0.50, the plain-pass fold: commit `171f3ea`.
  The beam-sizing sentence names its actor. The lull sentence takes the plain word. The refusal names the team.

- The v0.49 re-keys (2026-10-15): the caption files, the load-path sentence and the winner-form sites.
  Fold `8169e36`, 8 anchors and 37 guards closed, tokens add 49 and remove 48.
  Review copy rebuilds (record `8169e36`, live md5 `24f98df6…`, byte-identical to `draft-8169e36-20261015-144342.docx`).
  Check `scratch/au_v049_rebuild_check.py`, 37 checks, 0 fail.
  Receipt `docs/reporting/room-responses/author-2026-10-15-v049-rekeys.md`.

- v0.49, the re-key fold: commit `8169e36`.
  The two system-anatomy caption files take the caption form.
  The draft load-path sentence takes it, and the three winner-exhibit sites take the winner form.

- v0.48, the appendix pins (figures seat): commit `6f19eee`.
  The system-anatomy script-commit cell and its four output-hash cells take the re-cut pins.

- The round-6 rebuild (2026-10-15): the review copy rebuilds from v0.47.
  Record `d0ed902`, seven seats, 42 cited all signed, 51 signed rows.
  Live md5 `1115a201…`, byte-identical to `draft-d0ed902-20261015-124752.docx`.
  Check `scratch/au_v047_rebuild_check.py`, 19 checks, 0 fail.
  Receipt `docs/reporting/room-responses/author-2026-10-15-v047-round6-fold-and-rebuild.md`.

- v0.47, the round-6 fold: commit `d0ed902`.
  The ten hub-name sites take the signed top forms. The count prints 508 of 930 (NR-002).
  The winner pair takes the founder form, and section 3.4 retitles to `The levers of Performance`.

- v0.46, the appendix pins (figures seat): commit `45ed95a`.
  The four script-commit cells and sixteen output-hash cells take the re-cut pins.

- v0.45, AU7: the era map and the failure-ledger table: commit `34e3f81`.
  Receipt `docs/reporting/room-responses/author-2026-10-14-v045-au7-discussion.md`.
  The era map lands beside the era note, with the short pointer block.
  The failure-ledger table lands at section 4.2, the narrative after it.
  The two tables carry the accepted table class.

- v0.43, the round-5 wording set: commit `e5541e9`.
  Receipt `docs/reporting/room-responses/author-2026-10-14-v043-round5-wording.md`.
  The blade-scale base, the cone statement and the slot names land.
  The cold-path line, the swing reading and the lifter rationale land.
  The staged launch and the campaign-scale context land.
  The AU9 receipt normalises at `b7f09ed`.

- v0.42, the gate-margin column (AU9): commit `38c77f8`.
  Receipt `docs/reporting/room-responses/author-2026-10-14-v042-gate-margins.md`.
  The gate table takes six rows with the margin column.
  The power-floor and clearance cells take their corrected forms, and the FoS row takes its display forms.
  AU9 closes.

- v0.40, the decision shape (PL13): commit `0e7d396`.
  Receipt `docs/reporting/room-responses/author-2026-10-14-v040-decision-shape.md`.
  The margin block, the evolution story and the implications take their shape lines.
  The discussion re-reads standing, and the section 4 action columns wait on the partner-gated tails.
  PL13 closes.

- v0.39, the k = 2.24 story fold: commit `12a5753`.
  Receipt `docs/reporting/room-responses/author-2026-10-14-v039-k-story-fold.md`.
  The retirements, the sweep table (NR-047), the two side paragraphs and the sizing pair (NR-048) land at section 2.3.
  The queue item 7 author leg closes.

- v0.38, the safety-shorthand pass: commit `ed3d202`.
  Receipt `docs/reporting/room-responses/author-2026-10-14-v038-safety-shorthand.md`.
  The section 4.1 pair rewords to the detector forms, and the safety set states that breaks are never permitted.
  The queue item 8 author leg closes.

- v0.37, the consistency sweep: commit `7dd91a9`.
  Receipt `docs/reporting/room-responses/author-2026-10-14-v037-consistency-sweep.md`.
  The classified fail counts (NR-002), the unit forms and the phrase polish land.
  The section 2.2.2 build request leaves the body.

- v0.36, the objective block and the rename: commit `57c77cf`.
  Receipt `docs/reporting/room-responses/author-2026-10-14-v036-objective-block.md`.
  The scoring chain, the three soft constraint penalty forms and the reject placement print at section 2.4 (NR-046).

- Earlier landings: v0.34 `a3c2def`, v0.33 `dcf8213`, v0.32 `5a7a6b4`. The receipts sit beside this page.

- The review copy rebuilds after each draft-moving pass. The v0.65 rebuild rides the lead seat and carries this fold, the re-frozen levers block and the figure re-cuts.

## Boot

- Repo `KiteTurbineDynamics.jl`, branch `bank-derate-cos2p65`. Fetch first.
  Every seat pushes to this shared tree.

- Read `handovers/handover-2026-10-08-reporting-room-boot.md` and the rulings page beside it.
  Then the register at `docs/reporting/numbers-register.md` and the tracker at
  `docs/reporting/draft-tracker.md`.

- Load the skills `ste-writing`, `ktd-reporting-room` and `ktd-report-drafting`
  before the first pass.

- Nothing of this seat lives only in a chat. This page plus the latest receipt
  resume the seat in one readback.

## Working rules

- Cite only signed rows, by row ID. The register keeps full precision. The report prints the ruled display forms.

- Stage explicit paths only. Peers may hold staged files in this shared tree.

- Add evidence logs with `git add -f`. The `*.log` pattern sits in `.gitignore`.

- Run the STE gate before each commit, at the prior count. The fold scripts fail closed.

- Rebuild the review copy after each draft-moving commit, so its stamp reads the tip.

- Verify the push. The local branch matches origin, and each blob reads byte-identical at origin.

- Never run `git clean` in this tree. The untracked files carry seat evidence.

- Route findings through the room and the receipts. Do not post to the Signal Note to Self channel (TEAM_CHARTER section 4).

**Owner:** @author. **Next action:** the section 6.1 phase-2 hold. The wording is ruled at G4 (`a825aaef` to `c5d1ebda`), and the script waits on the two founder calls from Rod. When they land, the science-writer seat re-measures F3 and the aero seat declares it. Then the pass runs and the review copy rebuilds. The value-track close and the partner-gated tails hold.
