# Handover: the figures-images-diagrams seat, KTD reporting room

**Date:** 2026-10-14. **From:** @fig-img-diagrams. **To:** the successor session.
**Base:** branch tip `21b821b` on `bank-derate-cos2p65`.

This page holds the rotation insurance for this seat. It is an index, not a retelling.
The receipts carry the story.

## What this seat does

This seat owns the report figures. It builds the plates from the kit scripts, pins the
outputs, re-walks the label checks and seats the caption text. It keeps the drawn
values on signed register rows, at the drawn precision. It owns the figure map
(`docs/reporting/figures/figure-map.md`) and the kit folders under
`docs/reporting/figures/`. Any render or pin move takes a fresh F-VALUE counter-read
by the aero seat. Any text or cite change takes the F-LABEL re-walk.

## Open items

1. **The Harris-3.5 render deltas.** The ring utilisation plate and the twist limit
   plate take the review deltas. Ring: the utilisation axis treatment (a log axis or
   an inset for the 0.03 to 0.07 slivers) and the moment label (√(M_y² + M_z²) in
   place of √(M²)). Twist: the legend changelog lines out, the S1 to S4 δcrit label
   overlap, and the title and margin against the binding limit. Then F-VALUE at the
   sign-off commit. The review item sits in
   `docs/reporting/feedback/2026-10-10-harris-review.md` section 3.5. The map rows 6
   and 7 carry the gate line.

2. **The item-5 lever-statistics extract.** Objective versus gene, gate failures by
   gene, and penalty contributions across ok designs. The ask sits in feedback item 5
   (`docs/reporting/feedback/Feedback-message-1791925681590.md`). It is file-disjoint
   from the draft chain, so it can fan out. It lands behind the Harris deltas.

3. **The seating headers.** The author promoted both levers caption drafts to the
   builder name (`captions.md`) at `5a7a6b4`. The seated header refine lands with this
   seat's next pass; check the kit caption files for the seated form. The
   eval-timeline and k-basis kits take the same treatment at their folds.

4. **The ring lead flag.** The ring caption lead prints the capture form 15.033
   (NR-021), not the report headline 15.0 (NR-009). One line flips it if the room
   calls for the headline form there.

## Closed, last (evidence index)

- The levers cites and pins fix: `d6d4db9` (script `e23f226`). Receipt
  `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-levers-cites-and-pins-fix.md`.
  Evidence `scratch/fig_pca_fix_check.py` plus `.log`.

- The caption leads and the F-VALUE closure records: `60ee728`. Receipt
  `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-caption-leads-and-closure.md`.
  Evidence `scratch/fig_cl_edit.py`, `scratch/fig_cl_check.py` plus `.log`.

- F-VALUE for the levers family closes at the aero re-census `7329191`, on the fix
  commit `d6d4db9`, zero defects. The levers fold lands at `5a7a6b4` (section 3.4
  block, the rows 20/21 pointers, both plates embedded in the review copy).

- The kit pins: both levers kits carry the v3 hash blocks, and the blocks recompute
  from the committed bytes. The drawn row lists read five rows on the landscape and
  four on the atlas. The six figure seats resolve in the review copy.

## Boot

- Repo `KiteTurbineDynamics.jl`, branch `bank-derate-cos2p65`. Fetch first. Every
  seat pushes to this shared tree.

- Read `handovers/handover-2026-10-08-reporting-room-boot.md` and the rulings page
  beside it. Then the figure map and the register at `docs/reporting/numbers-register.md`.

- Load the skills `deterministic-figure-plates`, `ktd-chart-design` and `ste-writing`
  before the first pass.

- Nothing of this seat lives only in a chat. This page plus the receipts resume the
  seat in one readback.

## Working rules

- The kits are deterministic. A re-run stays byte-identical, the self-checks run
  in-script, and the pins recompute from the committed bytes.

- Drawn values print signed rows at the drawn precision. No number prints without
  its row.

- Any render or pin move takes a fresh F-VALUE counter-read from the aero seat.
  Any text or cite change takes the F-LABEL re-walk and the STE gate.

- Stage only your own paths. Peers may hold staged files in this shared tree.

- Add evidence logs with `git add -f`. The `*.log` pattern sits in `.gitignore`.

- Run `python3 ste-lint.py --fail-above 2.0` on a new file before the commit.

- Verify the push. The local branch matches origin, and each blob reads
  byte-identical at origin.

- Never run `git clean` in this tree. The untracked files carry seat evidence.

- Route findings through the room and the receipts. Do not post to the Signal Note
  to Self channel (TEAM_CHARTER section 4). The mechanics sit in
  `docs/reporting/room-responses/aero-validator-2026-10-12-signal-silence-mechanics.md`.

**Owner:** @fig-img-diagrams (figures-images-diagrams). **Next action:** open the
Harris-3.5 render deltas on map rows 6 and 7.
