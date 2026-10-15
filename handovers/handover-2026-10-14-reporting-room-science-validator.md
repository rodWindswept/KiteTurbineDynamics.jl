# Handover: the science-validator seat, KTD reporting room

**Date:** 2026-10-14. **From:** @science-validator. **To:** the successor session.
**Base:** branch tip `d0ed902` on `bank-derate-cos2p65`. **Updated** 2026-10-15 for the round-6 term gate.

This page holds the rotation insurance for this seat. It is an index, not a retelling.
The receipts carry the story.

## What this seat does

This seat checks the numbers that enter the report.
It signs register rows from the raw data.
It audits claims against signed rows, and it runs the counter-reads the room routes here.
One rigorous read per gate, and the sign-off stays at this desk.

The audit checks can fan out to sub-agents when the sections are independent.

## Open items

1. **PL12 verification facts, on request.** The part 13 fold by @author (references
   and data availability) draws its verification facts from this seat. The section 7
   line "Fifteen of eighteen" moves with that pass.

2. **The Nomenclature fold.** The term gate closed on the round-4 rename, so the
   section wait ends. The fold runs with the lead and the SW seat. The hub rename
   joins the terms. The reading holds at one form.

3. **The round-6 naming leg, open at the science-writer seat.** The tracker (2 sites:
   L104 and L165), the candidates (2 sites: L78 and L262) and the stale-phrases list
   (4 sites: L63, L68, L78 and L80) take the new forms there. The round-6 term gate
   re-reads after the leg lands.

4. **New rows before print.** Any new value in the polish round, the figure builds,
   the corner build or the item-5 extract takes a register row and a sign at this desk.

## Closed, last (evidence index)

- The round-6 term gate clears at `d0ed902`: the fold reads the ten signed forms, the
  note amend and the six delivered art files clean; the census classifies 3,723 lines
  across 826 files; the open legs are enumerated. Receipt
  `docs/reporting/room-responses/science-validator-2026-10-15-round6-term-gate.md`.
  Checker `scratch/sv_r6_term_gate_check.py`, 58 checks, 0 fail; log beside it.

- The round-6 signs land at `cb862df`: the hub forms, the count glance, NR-051 and
  the physics-topology amend (ten draft sites, five plates, three kits).
  Receipt `docs/reporting/room-responses/science-validator-2026-10-14-round6-signs.md`.

- The two round-6 checkers read green: `scratch/sv_r6_hub_forms_check.py` (25 checks,
  0 fail) and `scratch/sv_r6_count_nr051_check.jl` (38 checks, 0 fail).

- The item-5 lever-statistics counter-read closes: no discrepancy found. Receipt
  `docs/reporting/room-responses/science-validator-2026-10-14-item5-counterread.md`.
  Checker `scratch/sv_item5_counterread.py`, 173 checks, 0 fail. The seat checker
  re-runs green, 23 checks (`scratch/sv_item5_figcheck_rerun.log`).

- The k-sweep display rows sign: NR-047 (six loads, one row per k, the omega
  column named `omega_final`) and NR-048 (the sizing-side pair). Receipt
  `docs/reporting/room-responses/science-validator-2026-10-14-k-sweep-rows-sign.md`.
  Checker `scratch/sv_nr047_k_sweep_rows_check.py`, 46 checks, 0 fail.

- The term gate on the round-4 rename cleared at `bb1709d`. Receipt
  `docs/reporting/room-responses/science-validator-2026-10-14-term-gate-soft-constraint-penalties.md`.

- NR-046, the objective seam, signed at `4a86e6f`. The aero counter-read closes it at `9d96a4b`.
  Receipts `docs/reporting/room-responses/science-validator-2026-10-14-objective-seam-row.md`
  and `.../aero-validator-2026-10-14-nr046-counterread.md`.

- The claim-by-claim audit certifies draft v0.33 at `90cd692`. Receipt
  `docs/reporting/room-responses/science-validator-2026-10-14-claim-by-claim-audit.md`.

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

**Owner:** @science-validator. **Next action:** the round-6 term gate reads clear; the naming leg and the copy rebuild take its re-read. The item-5 printed forms take rows here when the fold prints them. The PL12 verification facts stand on request.
