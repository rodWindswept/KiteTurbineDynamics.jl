# Room response: draft v0.55, the reject split and the item-2.1 environment set (2026-10-15, author)

**Status** LANDED. **Seat** author. **Read at** `6a58e9c` (branch `bank-derate-cos2p65`). The fold landed as `2e930a8`, range `6a58e9c..2e930a8`. The rebuild and the origin readback ride this pass.

**Scope** This response runs the two keyed items the room signed this pass. The status-mix split reads from NR-055, signed at `a51e9d9` under the print ruling. It folds at sections 3.1 and 5.

The item-2.1 environment set reads from NR-056 to NR-058. The aero seat read them (`c08f3bd`), and the science-validator seat signed them at `a51e9d9`. The section 3.3 table takes the shear-law and shaft-elevation rows. The swing sentence takes its steady-wind basis note.

## The fold, as landed

- The version pin refreshes to v0.55.

- The split lands at section 3.1: "The reject class splits three ways (NR-055). 96 ran below the 5 kW power floor. Four ran at or above 5 kW with a factor of safety below 2.5. The cause is not logged for the remaining 201."

- The split repeats at section 5, after the feasible count. The opening line reads "The 301 rejects split three ways (NR-055)."

- The operating table takes two rows.

  Row one reads "| Shear law | Hellmann power law, exponent 1/7, from the measured
  Daisy pair 10.0 m/s at 4.8 m | NR-056 |".

  Row two reads "| Shaft elevation | 30 deg, hub at 9.4000 m | NR-057 |".

- The swing block takes the basis note: "The reported trace runs steady wind, so the swing reads as a steady-wind response, not a stability property (NR-058)."

- The tracker takes the v0.55 entry.

## Guards held

- The changed-line census reads exact. One replace sits at the pin. Four inserts follow.

- Section 3.1 takes six lines. Section 5 takes six lines. The table takes two rows. The swing block takes one line. The draft moves from 1,044 to 1,059 lines.

- The declared token diff reads exact. The draft removes `54` and adds `55`, `96` (two), `201` (two), `301`, `5` (four), `2.5` (two), and the value tokens `1`, `7` (the exponent pair), `10.0`, `4.8`, `30` and `9.4000`.

- The tracker adds `55`, `3.1`, `5` and `1`. The last token comes from `item-2.1`, where the hyphen flank kills the `2.1` run and leaves the `1` alone.

- Every held value form and cite count reads level: `22 degrees`, `25.698`, `NR-049`, `NR-050` and the least-margin sentence. The whole `NR-` count reads 245 to 250.

- The new forms read once each. The subgroup lines read once per site. The untouched regions hold from the introduction through to the figure-provenance appendix.

- STE holds rc=0 on both files. The draft reads 7,171 to 7,298 words at total 8. The tracker reads 3,314 to 3,378 at total 12. Every category holds.

- The fold script holds 6 anchors and 40 guards, all closed. The candidate hashes read draft `acd0a43f…` and tracker `67c242cb…`.

- The citation gate exits 0. It reads 52 cited rows, every one signed (58 signed rows total).

## The review-copy rebuild

- The build runs `python3 scripts/build_draft_docx.py` from the tip. The record reads draft `2e930a8` and the register file at `a51e9d9`.

- Eight of eight seats resolve. The build re-renders nothing. The kits embed as shipped.

- Built 2026-10-15T21:27:15Z. The live copy `scratch/report-pdf-build/draft-live.docx` reads md5 `4c4384146bbba1d56938814e60741d18`.

- The live copy reads byte-identical to its archived build `draft-2e930a8-20261015-212715.docx`. Eight media entries carry the eight kits.

- The delivered file carries the phrase set. `v0.55` reads once. The split lines, the two rows and the basis note read their counts. The old marks read zero.

- The delta from the founder copy reads one front. The reject split, the two environment rows and the swing basis note enter. The founder holds the v0.54 build (md5 `72ef99be…`). No existing printed number changes. The new set prints for the first time.

## Receipts

- The fold evidence rides `2e930a8`. `scratch/au_v055_split_and_env_fold.py` and its log read byte-verified at origin.

- The rebuild check reads `scratch/au_v055_rebuild_check.py`. It prints 69 checks, 0 fail. Its log sits beside it.

## Notes

- The scope reading: the split folds at sections 3.1 and 5, per the routing. The routing reads "the section 3.1/5 status-mix split". The summary for decision, the section 3.6 clearance line and the claims appendix keep their mix forms. A wider sweep can follow one room call.

- Three new report terms ride the glossary handoff. They are the shear law (Hellmann power law, exponent 1/7), the shaft elevation and the steady-wind basis.

- The figure label ledger (`2361771`) matches the print registration. The six class labels read "feasible" and the five "rejected:" forms. The chart and the draft now tell one story.

- The section 3.2 fold stays keyed on the built row-16 plate. It waits on the counter-reads and the visual pass.

## Handoffs

- @science-validator: the fold carries the NR-055 to NR-058 rows. The read keys on these bytes.

- @aero-validator: the v0.55 copy sits for a counter-read when the next copy pass opens. The fold is text-only. The item-2.1 set now prints complete.

- @science-writer: the sweep span takes the v0.55 move (`2e930a8`) and this receipt set. The three terms above join the glossary work.

- @fig-img-diagrams: no plate byte moves. The label ledger and the printed split agree.

- @hermes: the queue can record the split printed and the item-2.1 environment set closed at this seat. The section 3.2 fold and AU4 read next.

- @user: the failed-design breakdown you ruled to print now sits in the report in plain words. The fold closes the last three gaps in the wind picture. These are the shear law, the shaft angle and the steady-wind note. The note states the smooth window reading comes from steady wind, not machine stability. No old number changes, and the rebuilt copy sits below.

author, 2026-10-15.
