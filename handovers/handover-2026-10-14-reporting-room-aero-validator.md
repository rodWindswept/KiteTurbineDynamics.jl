# Handover: the aero-validator seat, KTD reporting room

**Date:** 2026-10-14. **From:** @aero-validator. **To:** the successor session.
**Base:** branch tip `5a7a6b4` on `bank-derate-cos2p65`.

This page holds the rotation insurance for this seat. It is an index, not a retelling.
The receipts carry the story.

## What this seat does

This seat counter-reads the numbers and the claims that enter the report.
It recomputes values from the source data, checks every cite against a signed register row,
and lands one receipt per read. It signs the F-VALUE gate for a figure family or a claim block.
The desk keeps one rule: one rigorous read per gate. The sign-off stays at this desk.

The legwork can fan out to sub-agents when the sections are independent.

## Open items

1. **Polish counter-read legs.** @author folds the four polish sections, two per push.
   Run one leg per section. The winner margins and the evolution story come first,
   then the implications and the conclusion.

2. **Figure watches.** The Harris-3.5 render deltas take a counter-read if drawn values
   or pins move. The item-5 lever-statistics extract takes the same treatment.

3. **New families.** A new figure family or claim block in the polish round opens a fresh
   F-VALUE read.

Each leg runs three tests.

- Every printed value maps to a signed row at the printed form.
- The recompute matches the raw data where raw data exists.
- Every cite resolves.

Land the receipt in `docs/reporting/room-responses/` and the evidence in `scratch/` with the `av_` prefix.

## Closed, last (evidence index)

No gate stays open at this seat until the polish round.

- F-VALUE counter-read, levers family: `331f60d`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-pca-fvalue-counterread.md`. Evidence `scratch/av_pca_fvalue_counterread.py` plus `.log`.

- F-VALUE re-census, levers family: `7329191`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-pca-fvalue-recensus.md`. Evidence `scratch/av_pca_fvalue_recensus.py` plus `.log`.

- The fix closes at `d6d4db9`. The fold `5a7a6b4` carries the section 3.4 block and the first appendix.

## Boot

- Repo `KiteTurbineDynamics.jl`, branch `bank-derate-cos2p65`. Fetch first. Every seat pushes to this shared tree.

- Read `handovers/handover-2026-10-08-reporting-room-boot.md` and the rulings page beside it.
  Then the register at `docs/reporting/numbers-register.md`.

- Load the skills `ste-writing` and `physics-model-validation` before the first read.

- Nothing of this seat lives only in a chat. This page plus the two receipts resume the seat in one readback.

## Working rules

- Cite only signed rows. Recompute, never re-read a prior report.

- Stage only your own paths. Peers may hold staged files in this shared tree.

- Add evidence logs with `git add -f`. The `*.log` pattern sits in `.gitignore`.

- Run `python3 ste-lint.py --fail-above 2.0` on the file before the commit.

- Verify the push. The local branch matches origin, and the blob reads byte-identical at origin.

- Never run `git clean` in this tree. The untracked files carry seat evidence.

- Route findings through the room and the receipts. Do not post to the Signal Note to Self channel (TEAM_CHARTER section 4). The mechanics sit in `docs/reporting/room-responses/aero-validator-2026-10-12-signal-silence-mechanics.md`.

**Owner:** @aero-validator. **Next action:** hold for the first polish fold push, then run leg 1.
