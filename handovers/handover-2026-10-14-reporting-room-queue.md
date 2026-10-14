# Handover: the reporting room queue

**Date:** 2026-10-14. **From:** @hermes (map seat). **To:** the successor session.
**Base:** branch `bank-derate-cos2p65`. First landing on `48aafab`. **Updated** 2026-10-14 for the v0.40 span, the item-8 and item-5 closes, the counter-reads and the consultation-record flip call.

This page is the consolidated queue index for the reporting room. It holds the rotation insurance set and the open work in fold order. It is an index, not a retelling. The receipts hold the story.

## The insurance set

Six pages hold the rotation insurance. Each seat page carries the open items, the evidence index, the boot steps and the working rules.

- `handovers/handover-2026-10-14-reporting-room-aero-validator.md`: commit `84dbfd6`.

- `handovers/handover-2026-10-14-reporting-room-science-validator.md`: commit `d0679d3`.

- `handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md`: commit `7fc0717`.

- `handovers/handover-2026-10-14-reporting-room-author.md`: commit `716bd3a`.

- `handovers/handover-2026-10-14-reporting-room-science-writer.md`: commit `d33bf14`.

- This page: the room queue.

## State (updated for the v0.40 span)

- The branch tip reads `f030fe6`.

- Draft v0.40 at `0e7d396`. Sections 3.4 to 3.6 carry the decision shape. Section 2.3 carries the k = 2.24 story, with the sweep table, the two retirements, one paragraph per side and the sizing pair. The objective block and the rename read at section 2.4. The appendix carries the delivered pins (`ef36c6c`). Section 4.1 reads the detector forms.

- The era call stays open, as routed. No ruling moves.

- The register holds append-only at `d2bf63d`. The item-8 append lands two blocks at `a7d09eb` (54 lines added, none removed; no signed row changed). NR-046 signed at `4a86e6f`. NR-047 and NR-048 signed at `07e2eb9`.

- The room-consultation record joins the exempt class (`a7d09eb`). The flip call reads kept.

- The candidates record reads v15 at `57c77cf`, status PREP v15, noted and not gated.

- The review copy `scratch/report-pdf-build/draft-live.docx` carries the v0.40 build. md5 `835de8d8dc92e209d23cba39e7c11549`.

- The item-5 lever-statistics kit reads at `docs/reporting/figures/lever-statistics-extract/`: seven tables, the README and the checks log (`96adbf8`).

- STE: the draft reads 6,281 words, total held at 6. The tracker reads 2,542 words, total held at 10.

- Landings above the seat pages since the first write: this page (`13df740`), the claim audit (`90cd692`) and the Harris-3.5 deltas (`671ab96`, `e4ff3c1`). The later span takes the appendix re-pin (`ef36c6c`), the objective block (`57c77cf`) and the consistency sweep (`7dd91a9`). It adds the term gate (`cadf83d`) and the review-copy last mile (`d9d4fc4`). The span takes the rows 6 and 7 records (`9ae8097`), the safety pass (`ed3d202`) and sweeps 22 to 24. It closes with the k-sweep display-row sign (`07e2eb9`), the item-5 extract (`96adbf8`), the k-story fold (`12a5753`) and sweep 25 (`bbc214e`). The span then takes the item-8 aero leg (`8d3b61d`), the item-5 counter-read (`d0679d3`), the figures seat page (`7fc0717`), the v0.40 decision shape (`ad56692`), sweep 26 (`a359061`), the v0.40 counter-read (`3ac48af`) and the v0.40 glance (`f030fe6`).

## Open queue, in fold order

1. **@fig-img-diagrams: the machine hero, ahead of the send.** The founder asks for a settled-machine image early in the report. Row 10 (`machine-winner-hero`) covers it. Next gate: the capture script (plan, side, downwind) from the built state, then F-REPRO. The fold and the copy rebuild follow. The rebuilt copy keys its read at the aero-validator desk before it goes out.

2. **@author: AU9 and the partner-gated tails.** PL13 closed at `ad56692`. The AU9 gate cells and the tails follow at this seat.

3. **@author and @fig-img-diagrams: the kMppt ask (founder).** The records read 3.55 and 5.39 as retired k_mppt values. The open pieces: a plainer pass on the structural-side sentence, and the kMppt-space graphic from the earlier exploration. The earlier MPPT x twist sweeps hold that study; the era-fit flag gates any cite. The row-5 plate draws this campaign's sweep and waits on Rod's visual pass.

4. **@hermes (lead) and @science-writer: the Nomenclature fold.** The term gate cleared at `cadf83d`. The fold closes the last pending section. The three projection terms sit in the candidates for Track D.

5. **@science-writer: sweep 27, then the explainer block and the references gate.** Sweep 27 keys on the next draft push. The block lifts from the printed section 2.4 block and NR-046. The references gate holds three pending source calls (Ranneberg, Jamieson, Hancock).

6. **@science-validator: PL12 on request and the item-5 forms.** The item-5 counter-read closed at `d0679d3`, no discrepancy found. The printed forms of the fold take rows at this seat first. The PL12 verification facts stand on request.

7. **@fig-img-diagrams: the visual pass on rows 4 to 7, then the folds.** The ring lead flag closed-held at the capture form 15.033 (NR-021). The k-basis plate and the Harris-3.5 pair wait on the same pass.

8. **@hermes: the map.** Delta maps, route notes and receipts stay at this seat. Keep this page current as items close.

9. **Founder asks, logged.** The basics-of-TRPT refresher for the report (scope call at @author). The repo docs currency check, README, manifest and decisions (@hermes, this seat). Not gated.

## The parallel set

The claim audit closed at `90cd692`. The item-5 counter-read closed at `d0679d3`. The open leg reads: the explainer block. Farm it. The fold chain and the sign-offs stay single-desk. Keep one rigorous read per gate.

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

- Write anything Rod reads in plain English. Keep the shorthand for internal notes.

**Owner:** @hermes (map seat). **Next action:** the machine hero ahead of the send. Then AU9 and the partner-gated tails, the kMppt ask and the Nomenclature fold.
