# Handover: the reporting room queue

**Date:** 2026-10-14. **From:** @hermes (map seat). **To:** the successor session.
**Base:** branch `bank-derate-cos2p65`. First landing on `48aafab`. **Updated** 2026-10-14 for the round-4 routing pass, the k-story order and the safety shorthand.

This page is the consolidated queue index for the reporting room. It holds the rotation insurance set and the open work in fold order. It is an index, not a retelling. The receipts hold the story.

## The insurance set

Six pages hold the rotation insurance. Each seat page carries the open items, the evidence index, the boot steps and the working rules.

- `handovers/handover-2026-10-14-reporting-room-aero-validator.md`: commit `bc2c529`.

- `handovers/handover-2026-10-14-reporting-room-science-validator.md`: commit `21b821b`.

- `handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md`: commit `efc44f3`.

- `handovers/handover-2026-10-14-reporting-room-author.md`: commit `f6e7f4e`.

- `handovers/handover-2026-10-14-reporting-room-science-writer.md`: commit `3c5651b`.

- This page: the room queue.

## State (updated for the round-4 routing pass)

- Draft v0.34 at `a3c2def`. Sections 3.6 and 5 carry their text. The polish batch closed. The head status line reads current.

- The register holds at `6255268`. The candidates record moved to v14 at `4e559de`, noted and not gated.

- The review copy `scratch/report-pdf-build/draft-live.docx` carries the v0.34 build. md5 `8324be7a204fbce3f3c6c38babcd62dc`.

- STE: the draft reads 5,721 words, total held at 5. The tracker reads 2,239 words, total held at 10.

- Landings above the seat pages since the first write: this page (`13df740`), the claim-by-claim audit (`90cd692`), and the Harris-3.5 deltas (`671ab96`, `e4ff3c1`). Draft v0.34 sits at `a3c2def`, and this pass lands on top.

## Open queue, in fold order

1. **@science-validator: the objective-score read.** The head. The read covers the objective seam (`src/objective_v12.jl`) and the chain sites in the NR-039 notes. One new row carries the three penalty forms, with thresholds, weights and units. It also states how the search treats rejected designs. The PL12 facts stay on call.

2. **@science-writer: sweep 22, then the block and the rename.** The sweep keys on `a3c2def`. The explainer block drafts from the new row. The rename reads "gate penalties" to "soft constraint penalties", in the glossary row and the draft together. The references gate holds three pending source calls.

3. **@author: the fold, then the sweep.** The objective block and the rename fold at section 2.4. The text seats inside the current number. The numbering hold stands. The consistency sweep runs over the folded state.

4. **@aero-validator: the counter-read stack.** Pair one, the `dcf8213` sections. Pair two, the implications and the conclusion. The Harris-3.5 F-VALUE read on rows 6 and 7. The new row takes its counter-read when it signs.

5. **@fig-img-diagrams: the item-5 extract.** Then the standing flags. The ring lead prints the capture form 15.033. The headline form 15.0 is one line away if the room calls it. The generation notes take a tracked name in this pass. No caption item sits open: the strip captions closed at `d6d4db9`, and the drawn-label split stands recorded.

6. **@hermes: the map.** Delta maps, route notes and receipts stay at this seat. The round-4 routing and this refresh land here. Keep this page current as items close.

7. **@science-validator, then @author: the k = 2.24 story.** The check (`3b8e099`) and the counter-read (`4203bec`) hold the plan. The science-validator signs the sweep rows first, with the omega column named (`omega_final`, not `omega_eq`). The author then folds section 2.3. The fold adds the two retirements, the small k table, one paragraph per side, the sizing-side pair and the over-power tie-in. The era call stays open.

8. **@author and @aero-validator: the safety-shorthand pass.** The founder flagged the section 4.1 pair: it reads as permission for snapped ropes. The receipts (`2c97d57`, `ea51b25`) hold the detector forms. The author rewords the pair at the next fold. The aero seat amends the NR-025 row and sweeps the sibling phrasings (the room-consultation line). No number and no ruling moves. The evaluator fix keeps its own gate (Harris 3.8).

## The parallel set

The claim audit closed at `90cd692`. The open legs read: the objective read, the item-5 extract, and sweep 22. Farm them. The fold chain and the sign-offs stay single-desk. Keep one rigorous read per gate.

## Boot

- Fetch first. Every seat pushes to the shared tree on `bank-derate-cos2p65`.

- Read `handovers/handover-2026-10-08-reporting-room-boot.md` and the rulings page beside it.

- Read this page and your seat page. Then the register at `docs/reporting/numbers-register.md`.

## Working rules

- Stage only your own paths. Peers may hold staged or untracked files in this shared tree.

- Run `python3 ste-lint.py --fail-above 2.0` on the file before the commit. Fix the prose. Never use `--no-verify`.

- Verify the push. The local branch matches origin and the blob reads byte-identical at origin.

- Cite only signed rows. Grep the draft before you call a close. A claim is not a fold.

- Add evidence logs with `git add -f`. The `*.log` pattern sits in `.gitignore`.

- Never run `git clean` in this tree. The untracked files carry seat evidence.

- Land one receipt per read in `docs/reporting/room-responses/`.

**Owner:** @hermes (map seat). **Next action:** the k-sweep rows at the science-validator seat. The section 2.3 fold and the safety-shorthand pass follow at the author seat.
