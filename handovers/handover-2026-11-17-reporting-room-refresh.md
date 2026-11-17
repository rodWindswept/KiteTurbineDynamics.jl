# Handover: the KTD Report Team room refresh

**Date:** 2026-11-17. **From:** @hermes (map seat). **To:** the new reporting room.

**Updated** 2026-11-17: peers pushed `b81cf4cb` while I wrote this record.
The tip now reads `b42a0c0b`, this file. The base below read `cfec5620`.

## Why this file exists

The old group chat was the KTD Report Team Bot Group. The desktop app drove
that room itself. The current desktop cannot resume it on the gateway.

Rod starts a new group with the same bots from the old room view. He presses
Start new group.

The new group starts with no history.

This file is the record that the fresh room boots from.

The repo carries everything else.

## Repo map (exact refs)

The live line is master at `cfec5620`. The local tree equals origin. I
fetched it on 2026-11-17. All reporting commits land on master now.

- Recent reporting commits on master. The tip reads `cfec5620`. Gates 2
  and 3 read as a plan (author).

- `1b897067` reads the gate-3 abstract rewrite (science-writer).
  `33bc8289` reads the Hong send ruling (hermes). `e93192a6` reads the
  samara citation ruling (hermes). `5d4b0067` reads the Tallak closed-forms
  appendix and draft v0.91 (author). `9c403f77` reads the Tallak verify and
  draft v0.90 (science-writer).

- The reporting flow dropped the old line `bank-derate-cos2p65`.
  The queue boot text still names it. That text is stale. Do not follow it.

- The shared desktop tree carries uncommitted peer work. F11 sits in
  `src/rope_forces.jl` with its DECISIONS entry staged. The ruling dates
  2026-11-10 and the work stays uncommitted.

- Two acceptance reds remain. They read B6c and P2. They read as ruling
  items.

- A staged revert of the v0.91 author pass stays in place, unnamed.
  Untracked scratch files carry seat evidence. Stage only your own paths.
  Never run `git clean` in this tree.

- The author worktree reads `KiteTurbineDynamics-author-wt` at `5d4b0067`
  on the branch `author-v091`.

## Draft and the send

The draft reads v0.91 with 12,726 words. STE reads 31 at 0.24. The cited
count reads 59, every one signed. The commit reads `5d4b0067`.

The Strathclyde send (Hong and Amjad) reads a formal release. The founder
ruled this on 2026-11-17. Three gates clear in order.

Gate 1 reads the whole-report sign-off. The sign-off has not landed. The
draft stays at v0.91 until it lands.

Gate 2 reads the reader-build strip. The plan commit reads `cfec5620`. The
receipt reads `software-worker-2026-11-17-reader-build-strip.md`.

Gate 3 reads the abstract rewrite. The commit reads `1b897067`. The receipt
reads `science-writer-2026-11-17-gate3-abstract.md`.

The ruling receipt reads
`docs/reporting/room-responses/hermes-2026-11-17-hong-send-ruling.md`.

Sweep 36 keys on the next push over the v0.79-to-tip tail. Sweep 35 recorded
`7e60f37..c6d79b9`.

## Open queue (fold order, as of 2026-11-17)

1. Phases 0 to 2 run now without a founder call. The owners read
   science-validator, aero-validator, aero-worker and software-validator per
   routing E.

2. Call 7 proposal, the n-surface.
Science-validator proposes it and writes the acceptance tests.
Aero-validator counter-reads it against the fine-lambda table.
Software-validator implements it behind both signs. A DECISIONS entry lands
with the proposal.

3. Call 2 proposal, the mass-per-watt term. Science-validator proposes it.
   Aero-validator counter-reads it. It rides Phase 4.

4. Call 1 proposal, the below-5 penalty shape. Science-validator proposes
   the steepening form. Software-validator owns the config edit behind it.

5. Phase 3 build with call 3 behind it.
The bridle drag and SWL gate land on delivered torque.
The measured C_T basis carries the 1.4 fallback.
The taper-clamp hard reject lands.
The discrete x4 and x6 genes land.
The `start_mode` keyword becomes required.

6. The repo fixes sit with software-validator. They read the extractor child
   blocks, the suffix match, the status-column wrap and the release
   build-record strip. The routing dates 2026-10-23.

7. Two plates sit with figures-images-diagrams. The lever-set pair sits at
   row 8. The section 9 gallery sits at row 32. The numbers read NR-074 to
   NR-077.

8. The return-3 folds sit with author. They read items 7, 55, 57, 58, 92,
   93 and 102. The word calls ride the same pass. The founder veto window
   closed when the owning seat runs.

9. The caveat lift sat with science-writer. It anchors to the signed verdict
   set. It closed at `3dc5ba9`.

10. The nomenclature fold and the figure numbering. Hermes and science-writer
    fold to section 7. Figures and author take the captions.

11. PL12 sits with science-validator. It reads the fifteen-of-eighteen line
    and the item-5 printed forms.

12. The visual pass sits with figures-images-diagrams and Rod. It reads the
    F1 plate, the winner plate, rows 4 to 7 and the row-16 convergence
    plate. The section 3.2 fold waits for the same pass.

13. Items sit with the founder. They read the winner-plate seat call, the
    root README refresh, the two campaign leads and the settled-form primer.

14. The Strathclyde send. It reads a formal release with three gates in
    order. The receipt reads `hermes-2026-11-17-hong-send-ruling.md`. It
    holds on gate 1.

15. The scratch keep-list script sat with hermes. It landed 2026-11-01.

The claim audit closed at `90cd692`. The item-5 counter-read closed at
`d0679d3`.

The open leg reads the explainer block. Farm it. Keep one rigorous read per
gate.

## Open calls with Rod

1. The whole-report sign-off (gate 1). It blocks the Strathclyde send. The
   draft holds at v0.91 until it lands.

2. The winner-plate seat call.

3. The root README refresh.

4. The two campaign leads.

5. The settled-form primer.

6. The F11 acceptance reds (B6c, P2) read as ruling items. Read the DECISIONS
   entry dated 2026-11-10 before you touch them.

## Priming reading order

1. `AGENTS.md`

2. This file

3. `handovers/handover-2026-10-14-reporting-room-queue.md` (the queue index)

4. `handovers/handover-2026-10-08-reporting-room-boot.md` (the contract and
   the hard rules)

5. `docs/reporting/numbers-register.md` (the firewall, signed rows only)

6. Your seat page under `handovers/`

7. The `DECISIONS.md` tail

8. `docs/reporting/draft-tracker.md` (the room layer of the draft)

## First actions per seat

- @science-writer: run sweep 36 on the next push. Hold the gate-3 wording
  for the fold. Leave the staged v0.91 revert alone.

- @author: fold the return-3 set (items 7, 55, 57, 58, 92, 93, 102). Run
  the reader-build strip per `cfec5620`.

- @science-validator: write the n-surface proposal and its acceptance
  tests. Run the PL12 line.

- @aero-validator: counter-read the n-surface against the fine-lambda
  table. Run the phases 0-2 counter-reads.

- @software-validator: run the four repo fixes. The routing dates
  2026-10-23.

- @figures-images-diagrams: build the two plates (row 8 pair, row 32
  gallery) on NR-074 to NR-077.

- @software-worker: run phases 0-2 per routing E. The reader-build strip
  receipt landed.

- @aero-worker: run phases 0-2 per routing E.

- @hermes (lead): keep the queue page and the receipts. Run the Hong send
  when the gates clear.

## Working rules (unchanged)

- Stage only your own paths. Run `python3 ste-lint.py --fail-above 2.0`
  before the commit. Never use `--no-verify`.

- Verify the push. The local branch matches origin. The blob reads
  byte-identical at origin.

- Cite only signed rows. Land one receipt per read in
  `docs/reporting/room-responses/`.

- Add evidence logs with `git add -f`. Never run `git clean` in this tree.

- Anything Rod reads: plain English. Fix-forward commits, never amends with
  force pushes.

- Peak-hours throttle: defer heavy work from 01:00 to 04:00 and 06:00 to
  10:00 UTC on weekdays. Keep-alive pings: acknowledge only.

**Owner:** @hermes (map seat). **Next action:** gate 1 (the whole-report
sign-off) with Rod, then the reader-build strip fold, then the abstract
fold, then the Hong send.
