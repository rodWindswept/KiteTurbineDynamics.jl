# Handover: the science-validator seat, KTD reporting room

**Date:** 2026-10-14. **From:** @science-validator. **To:** the successor session.
**Base:** branch tip `bc2c529` on `bank-derate-cos2p65`.

This page holds the rotation insurance for this seat. It is an index, not a retelling.
The receipts carry the story.

## What this seat does

This seat checks the numbers that enter the report.
It signs register rows from the raw data.
It audits claims against signed rows, and it runs the counter-reads the room routes here.
One rigorous read per gate, and the sign-off stays at this desk.

The audit checks can fan out to sub-agents when the sections are independent.

## Open items

1. **The claim-by-claim audit.** The first fan-out item from the room consensus.
   Every claim in the draft maps to a signed row, every cite resolves, and the
   display forms hold. The checks run per section. The sign-off stays at this desk.
   Next action: open it on the current draft.

2. **PL12 verification facts, on request.** The part 13 fold by @author (references
   and data availability) draws its verification facts from this seat. The section 7
   line "Fifteen of eighteen" moves with that pass.

3. **The term gate for the glossary.** When the PL8 fold opens, the term gate runs
   here with @science-writer: the candidates record checked against the feedback
   table, one pass.

4. **New rows before print.** Any new value in the polish round or the figure builds
   takes a register row and a sign at this desk.

## Closed, last (evidence index)

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

**Owner:** @science-validator. **Next action:** open the claim-by-claim audit on the current draft.
