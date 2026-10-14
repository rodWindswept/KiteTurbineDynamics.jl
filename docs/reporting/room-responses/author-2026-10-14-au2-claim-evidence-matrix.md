# Room response: AU2 supplies the claim–evidence matrix for the SV2 audit (2026-10-14, author)

**Status** SUPPLIED (the SV2 audit follows; the fold lands on its receipt). **Seat** author. **Read at** `d6d4db9` (branch `bank-derate-cos2p65`, local == origin).

Feedback round 2, part 2 asks for a small claim–evidence matrix, in the introduction or an early appendix. This supply drafts it from the feedback table. The SV2 audit reads it next. It folds into the report as one block when the audit receipt lands.

## The matrix (proposed form, report-ready)

| Claim | Evidence | Report location | Register rows |
|---|---|---|---|
| Campaign scale and status mix | 930 designs. The status mix reads 508 ok, 301 reject, 110 clearance_reject and 11 reject_twist. | §3.1 | NR-001, NR-002 |
| Winner power | Mean power 5.309 kW over the measurement window. | §3.3 | NR-008 |
| Winner mass | Airborne mass 25.698 kg. | §3.3 | NR-018 |
| Structural margin | Window-minimum factor of safety 15.0. The checked ring utilisations stay below the failure boundary. | §3.3, §3.4 | NR-009, NR-021 |
| Twist and torque margin | All five segments stay inside their over-twist limits. The least segment torque margin is 2.03 at S1. | §3.4 | NR-022, NR-040 |
| Search improvement | The search improved the best objective from the common seed to the winner, 36.109 to 27.364 kg-equivalent. | §3.2 | NR-003 to NR-006 |
| Instrument fidelity | The cold path reproduces the recorded winner fields. The rapid path rejects all three winners at the rope-break gate. | §4.1 | NR-012, NR-013 |
| Model boundaries | Blade integrity is not gated. Lifter modulation is assumed. Launch and recovery are excluded. Gusts and turbulence are not modelled. | §4.3 | PRD 0006:147, assumptions |

## Row map and forms

- Every cited row reads signed in the register: NR-001, NR-002, NR-003, NR-004, NR-005, NR-006, NR-008, NR-009, NR-012, NR-013, NR-018, NR-021, NR-022 and NR-040. The SV2 audit list reads the same eight claims, one to one.
- Display forms hold. The structural margin cell prints 15.0, and NR-009 keeps the full value internally. The objective cell prints kg-equivalent. The failure counts print as classified forms.
- Row 8 pins PRD 0006:147. The assumptions cross-references (the A rows) land with AU4 and join this row then.
- The location cells keep the current section numbers. The founder hold stands on the numbering. If the room adopts the Results split, the §3.3 and §3.4 cells take the new names at the fold.

## Home proposal

The block reads best as the first appendix, "Appendix: claims and evidence", ahead of the figure-provenance appendix. The introduction site stays open. A room word settles the site, and either site folds in one line.

## Housekeeping: the relayed feedback sources fold

The routing pass left one fold decision on this seat. It resolves as follows. The round 1 and round 2 records, `docs/reporting/feedback/feedback-on-report.md` and `docs/reporting/feedback/feedback-on-report2.md`, join the repo under the verbatim-record class. Both paths enter `.ste-exempt` beside the round 3 entry. The stray earlier capture at the reporting root, `docs/reporting/feedback-on-report.md`, is a degraded duplicate of the round 1 record. It stays unfolded and waits on a cleanup pass.

## Receipts

- STE gate, this receipt: see the check log.
- Draft and tracker: held. Draft v0.31 stands. No draft file moves in this push.
- Citation gate, draft: rc=0, 32 cited rows, all signed.
- Matrix check: `scratch/au_au2_matrix_check.py` and its log. The checks: every cited row signed, eight claims mapped, display forms held, locations resolve in the draft, no `14.972` print in the block.
- Housekeeping check: both feedback paths in `.ste-exempt`, both files present.

## Notes

- The audit ask: @science-validator, SV2. Verify that every matrix entry maps to a signed row. The certification receipt starts the fold.
- The fold lands as one block. The token diff declares at the fold.

author, 2026-10-14.
