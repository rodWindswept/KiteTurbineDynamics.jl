# Handover: the figures-images-diagrams seat, KTD reporting room

**Date:** 2026-10-14. **From:** @fig-img-diagrams. **To:** the successor session.
**Base:** branch `bank-derate-cos2p65`. Fetch first and read the tip. This page refreshed at the item-5 counter-read close (2026-10-14, tip `d0679d3`).

This page holds the rotation insurance for this seat. It is an index, not a retelling.
The receipts carry the story.

## What this seat does

This seat owns the report figures. It builds the plates from the kit scripts, pins
the outputs, re-walks the label checks and seats the caption text. It keeps the
drawn values on signed register rows, at the drawn precision.

This seat owns the figure map (`docs/reporting/figures/figure-map.md`) and the kit
folders under `docs/reporting/figures/`. Any render or pin move takes a fresh
F-VALUE counter-read by the aero seat. Any text or cite change takes the F-LABEL
re-walk.

## Open items

1. **The visual pass by Rod.** Rows 4 to 7 (the eval-timeline, k-basis,
   ring-utilisation and twist-limit plates) stand at F-VALUE pass or closure.
   The visual pass is the standing final step. The folds follow.

## Closed, last (evidence index)

- The ring lead flag closes as held (2026-10-14): the lead keeps the capture
  form 15.033 (NR-021).
  It matches the drawn plate readout and the body disambiguation line.
  The display boundary and the fold guard hold this form.
  The lead re-opens in one line if the room calls for the headline form 15.0
  (NR-009).

- The item-5 counter-read closes at the science-validator seat:
  no discrepancy found (173 checks, 0 fail, `d0679d3`). Every table quantity
  reproduces from the raw telemetry, and the NR-039 cross-check holds.
  The Phase-1 gate of the landscape plan passes at that read.
  Receipt `docs/reporting/room-responses/science-validator-2026-10-14-item5-counterread.md`.

- The v0.39 review copy reads clean at the aero item-8 leg (`a7d09eb`):
  the twenty-four figure pins recompute to HEAD and origin, and the six
  exhibits embed the delivered bytes. The copy md5 reads
  `f1ceae4d2278361756ba6c9b631f310d`.

- The item-5 lever-statistics extract lands: the kit at
  `docs/reporting/figures/lever-statistics-extract/` (builder `51ffc0d`,
  tables `6c51f5c9`).
  Receipt `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-item5-lever-statistics-extract.md`.
  Evidence `scratch/fig_lever_check.py`, `scratch/fig_lever_check.log` and
  `scratch/fig_lever_build.log`.

- The Harris-3.5 thread closes on rows 6 and 7: the re-census (`c30b2ca`)
  clears the fix at `ef36c6c` (85 checks, 0 fail) and the closure records at
  map v31. Receipt `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-rows67-closure.md`.
  Evidence `scratch/fig_r67_edit.py`, `scratch/fig_r67_check.py` plus `.log`.

- The appendix re-pin and the levers rows 20/21 join the figure-provenance
  appendix: the re-pin pass (2026-10-14). Receipt
  `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-appendix-repin.md`.
  Evidence `scratch/fig_repin_edit.py`, `scratch/fig_repin_check.py` plus `.log`.

- The Harris-3.5 render deltas: `e4ff3c1` (script `671ab96`). Receipt
  `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-harris35-render-deltas.md`.
  Evidence `scratch/fig_35_check.py` plus `.log` (65 checks, 0 fail).

- The levers caption seating headers take the seated form: `0ea9da4`. Receipt
  `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-seating-headers.md`.
  Evidence `scratch/fig_sh_edit.py`, `scratch/fig_sh_check.py` plus `.log`. The
  eval-timeline and k-basis kits take the same treatment at their folds.

- The levers cites and pins fix: `d6d4db9` (script `e23f226`). Receipt
  `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-levers-cites-and-pins-fix.md`.
  Evidence `scratch/fig_pca_fix_check.py` plus `.log`.

- The caption leads and the F-VALUE closure records: `60ee728`. Receipt
  `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-caption-leads-and-closure.md`.
  Evidence `scratch/fig_cl_edit.py`, `scratch/fig_cl_check.py` plus `.log`.

- F-VALUE for the levers family closes at the aero re-census `7329191`, on the
  fix commit `d6d4db9`, zero defects. The levers fold lands at `5a7a6b4`
  (section 3.4 block, the rows 20/21 pointers, both plates embedded in the
  review copy).

- The kit pins: both levers kits carry the v3 hash blocks, and the blocks
  recompute from the committed bytes. The drawn row lists read five rows on
  the landscape and four on the atlas. The six figure seats resolve in the
  review copy.

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

**Owner:** @fig-img-diagrams (figures-images-diagrams). **Next action:** hold for
the visual pass by Rod on rows 4 to 7, then the folds.
