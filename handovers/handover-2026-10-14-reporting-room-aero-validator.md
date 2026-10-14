# Handover: the aero-validator seat, KTD reporting room

**Date:** 2026-10-14. **From:** @aero-validator. **To:** the successor session.
**Base:** branch tip `d9d4fc4` on `bank-derate-cos2p65`.

This page holds the rotation insurance for this seat. It is an index, not a retelling.
The receipts carry the story.

## What this seat does

This seat counter-reads the numbers and the claims that enter the report.
It recomputes values from the source data, checks every cite against a signed register row,
and lands one receipt per read. It signs the F-VALUE gate for a figure family or a claim block.
The desk keeps one rule: one rigorous read per gate. The sign-off stays at this desk.

The legwork can fan out to sub-agents when the sections are independent.

## Open items

1. **Figure watches.** The item-5 lever-statistics extract takes an F-VALUE read if drawn values or pins move. The ring lead flag (15.033 against 15.0) stays with the room.

2. **New families.** A new figure family or claim block in the next round opens a fresh F-VALUE read.

3. **The next values mover.** The author seat holds PL13 and the Nomenclature fold. A values mover in either section opens a counter-read leg at this seat.

Each leg runs three tests.

- Every printed value maps to a signed row at the printed form.

- The recompute matches the raw data where raw data exists.

- Every cite resolves.

Land the receipt in `docs/reporting/room-responses/` and the evidence in `scratch/` with the `av_` prefix.

## Closed, last (evidence index)

- Review copy last mile, v0.37: `d9d4fc4`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-review-copy-last-mile.md`. Evidence `scratch/av_v037_copy_lastmile.py` plus `.log`.

- NR-046 counter-read (the objective seam): `9d96a4b`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-nr046-counterread.md`. Evidence `scratch/av_nr046_counterread.py` plus `.log`.

- Appendix re-census (the rows 6 and 7 closure): `c30b2ca`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-appendix-repin-recensus.md`. Evidence `scratch/av_appendix_recensus.py` plus `.log`.

- Polish counter-reads (sections 3.4 to 3.6 and 5): `7b8c101`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-polish-counter-reads.md`. Evidence `scratch/av_polish_counterread.py` plus `.log`.

- Harris-3.5 F-VALUE counter-read (map rows 6 and 7): `a3f4ae3`, fix `ef36c6c`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-harris35-fvalue-counterread.md`. Evidence `scratch/av_fig35_fvalue.py` plus `.log`.

- F-VALUE re-census, levers family: `7329191`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-pca-fvalue-recensus.md`. Evidence `scratch/av_pca_fvalue_recensus.py` plus `.log`.

- F-VALUE counter-read, levers family: `331f60d`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-pca-fvalue-counterread.md`. Evidence `scratch/av_pca_fvalue_counterread.py` plus `.log`.

## Boot

- Repo `KiteTurbineDynamics.jl`, branch `bank-derate-cos2p65`. Fetch first. Every seat pushes to this shared tree.

- Read `handovers/handover-2026-10-08-reporting-room-boot.md` and the rulings page beside it.
  Then the register at `docs/reporting/numbers-register.md`.

- Load the skills `ste-writing` and `physics-model-validation` before the first read.

- Nothing of this seat lives only in a chat. This page plus the receipts resume the seat in one readback.

## Working rules

- Cite only signed rows. Recompute, never re-read a prior report.

- Stage only your own paths. Peers may hold staged files in this shared tree.

- Add evidence logs with `git add -f`. The `*.log` pattern sits in `.gitignore`.

- Run `python3 ste-lint.py --fail-above 2.0` on the file before the commit.

- Verify the push. The local branch matches origin, and the blob reads byte-identical at origin.

- Never run `git clean` in this tree. The untracked files carry seat evidence.

- Route findings through the room and the receipts. Do not post to the Signal Note to Self channel (TEAM_CHARTER section 4). The mechanics sit in `docs/reporting/room-responses/aero-validator-2026-10-12-signal-silence-mechanics.md`.

**Owner:** @aero-validator. **Next action:** hold for the next values mover. The item-5 extract is the standing watch.
