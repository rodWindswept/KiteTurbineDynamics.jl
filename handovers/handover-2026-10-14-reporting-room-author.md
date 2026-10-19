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

One apply releases the run, and it is a patch, not a rebuild.
The base is `daab5102` (1291 lines, 10,570 words, STE 22 at 0.21).
The patch is `scratch/au_g6_final.patch`, four hunks, and it lands `5108e6d1` at 1299 / 10,674.
Nothing else in my lane moves until it applies.

**The block, as ruled at G5.** Five sentences, 63 words, lengths 17 / 6 / 11 / 15 / 14, longest 17, no semicolons, no em dashes. No bold lead: six bolded leads exist in the whole draft, all document-part labels, none between 1100 and 1180.

> A tether-to-blade bridle holds the blade tip down, from the underside, the concave side of the chord.
> The model carries no tether-to-blade bridle. It gives every blade one bank angle, all the way round.
> No such bridle exists to go slack, so nothing here checks that it stays loaded.
> So the tether-to-blade rule binds only on a design the genome cannot yet generate.

**Two rulings at this desk after G5, and each is one word.**

**The boundary.** Section 6.1 uses bare "the bridle" for two members 25 lines apart. At 1143, "A ring rotor would take the tilt reaction through its rim bridle." The block's closing sentence read "the bridle rule", so the nearest antecedent was the rim bridle, and that prints false against 1163, "Check the ring tilt against the rim bridle", which is a runnable item on the current design. The science-validator found it and the figures seat measured two candidates. This seat rules **`the tether-to-blade rule`**. It repeats the compound the block uses twice, at 1166 and 1167, and 986 before them. It cannot be read as the rim bridle, and it names the member the rule is scoped to. `the tip-down rule` was the other candidate and it loses: it names the rule after its geometry, and `tip` carries 15 hits, six of them tip-speed.

**The direction.** The figures seat withdrew the machine-practice form, because 1166 already states it in words, and left a figure-convention sentence at 168. This seat takes that sentence and rules the verb. **"The machine plates show the blade leaning downward, toward the ring below."** `draw` is the wrong verb: the draft uses it five times, four for a gene drawn at random and one for drawn power, and never for a figure. The report's figure verbs are `shows` ("The strip shows built geometry and the search objective only") and `reads` for a value ("The panel reads three lines and six rings"). `The figures` would also over-claim: nine figures ship and three draw the lean, and those three are the `machine-` slugs, hero, strip and corner grid. The plate source agrees: `tandeg(abs(bank))` at 262-263, inner end at `+shaft*din`, outer at `-shaft*dout` at 282-283.

**The states, measured at this desk with `ste-lint.py`.**

| State | md5 | lines / words | STE |
|---|---|---|---|
| G4, the can-check text | `a825aaef` | 1298 / 10,663 | 22 / 0.21 |
| G5, the can-grade dropped | `6d047d73` | 1298 / 10,662 | 22 / 0.21 |
| G6a, boundary only | `847baa7c` | 1298 / 10,662 | 22 / 0.21 |
| **G6, both** | **`5108e6d1`** | **1299 / 10,674** | **22 / 0.21** |

All four read long_sentence 3, passive_voice 5, nominalization 1, contraction 1, long_paragraph 12, semicolon 0, em dash 0.
G5 is one word from G4, `can check` to `checks`. G6a is one word from G5. G6b is one sentence.
The two late edits sit inside hunks that already exist, at 168 and at 1169, so the patch stays four hunks rather than six.
F2, F3, G3 and G4 are spent. D2 and F1 went before them.

**The patches.** `scratch/au_g6_final.patch` applies clean to `daab5102` and lands `5108e6d1`. `scratch/au_g6_boundary.patch` is the same patch without the 168 sentence, landing `847baa7c`, if the founder holds that line. Acceptance is the md5, nothing else. The science-writer seat's `scratch/sw_g5_write.patch` is the write alone and lands `6d047d73`. The candidate files are `scratch/au_g6_final.md`, `au_g6_boundary.md`, `au_g6_168.md`, with the two rejected forms kept as `au_g6_168_fig.md` and `au_g6_sv_tipdown.md`.

**Do not run the phase-2 script.** `scratch/au_sec61_phase2.py` still inserts the retired bold rule, `**Azimuth-resolved bank.** The windward blade tip...`, and it declares POST `207bd022` at 1297 / 10,662. Both are dead. Replace it from the ruled text before the next run.

**Do not trim, after the pass.** Five strings, each one hit in G6.

- 1116, `The tilt and steer then act off the intended axis.` Once the 1117 item goes, this is the only statement of the roll axis.
- `If the lag exceeds 90 degrees, the part of the tilt along the intended axis reverses sign.` This is the finding, not a convention.
- `Until they run, the rotor phase lag stays a free parameter.` It is what stops the gate reading as runnable.
- The two `so`s in the block. Each closes a different premise. Take the second away and the rule reads as enforceable.
- `that it stays loaded.` The model break-tests a bridle every step (`src/rope_forces.jl:618-620`), so a later trim to "checks a bridle load" prints false.

**What a successor must not re-derive.** Every item is measured, not argued.

- 168 takes `plane of rotation` in place of `ring plane`. `coning` and `ring plane` both read 0 in G6.
- `bank` stands on 31 lines of G6: 18 gene, 9 physics (the derate and the projection factor), 4 path strings that cannot move (`bankderate2-results`, `bank-derate-cos2p65`). The base carries 33, and the write empties the three command-sense uses. Keep-gene moves 0 lines; a rename moves 18 and leaves 13 standing.
- `bridl` has six hits and four members: stiffening at 32, lifting at 648, tether-to-blade at 986, rim at 1143. The block names the member, not the family.
- `genome` has 19 hits. `magnitude`, `roll`, `concave`, `under-side`, `lean` and `next ring` read 0 each.
- 986 carries the absence in the draft's words: "better than the unbridled model assumes... The model does not include it."
- 142 carries the predicate: "A line is a tension member, like a tether or a bridle. It carries a load only in tension."
- No plate moves under this plan. Every printed `bank` in the figure set is gene-sense, and the 168 sentence is prose about the plates, not a plate change.

**Still blocked, on Rod only.** The apply, and keep-gene or rename-command. The block is blessed and the aero seat has declared it, so the release is the founder's word and nothing in this seat's lane.

## Open items

1. **The section 6.1 phase-2 hold (above).** My lane is closed on it. The text is ruled at G6, the patch lands `5108e6d1` in four hunks, and no other author work moves until it applies.

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

**Owner:** @author. **Next action:** the section 6.1 phase-2 hold. The text is ruled at G6 (`daab5102` to `5108e6d1`), the patch is executable and the block is blessed and declared. On Rod's word, apply `scratch/au_g6_final.patch`, check the md5, rebuild the review copy from source, and answer keep-gene or rename-command. The value-track close and the partner-gated tails hold.
