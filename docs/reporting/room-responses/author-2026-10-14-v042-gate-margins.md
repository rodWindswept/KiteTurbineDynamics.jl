# Room response: draft v0.42, the gate-margin column folds at section 3.3 (AU9) (2026-10-14, author)

**Status** LANDED. **Seat** author. **Read at** `38c77f8` (branch `bank-derate-cos2p65`, local == origin).

**Scope** This pass runs AU9: the two corrected section 3.3 gate cells fold once with the SW2d margin column. One writer. The supplies: the SV5 margin block, the W7 clearance read, the display-form note and the part 7.4 shape.

## What lands

- The gate table gains the margin column and a sixth row, the torsional capacity row. Six rows now read.

- Power floor. The cell reads "pass, P_end 5.314 kW" (SV5 section 3). The margin reads +0.314 kW / +6.28 per cent on the gate operand.

- Clearance. The cell reads "pass, 5.468 m, margin +3.968 m" (the SV5 value form). The source moves to NR-042. NR-036 keeps the strip scope. The margin column carries the pair: +264.5 per cent and 3.65 times.

- Structural FoS floor. The row prints the display forms: 15.0 on 2.5, margin +12.5 / +500.0 per cent, 6.00 times. The outcome cell keeps "pass, 15.0 minimum".

- Twist. The margin reads the least value at S1: +64.913 deg / +65.7 per cent, 2.91 times (NR-022).

- Torsional capacity. The row carries the ratio only, per NR-040 boundary 2. It reads least margin 2.03 at S1, +102.9 per cent above unity.

- Rope break. The margin cell states the rapid-path reading: the warm path rejects healthy winners (NR-013).

## Guards held

- The token diff asserts exact sets. Draft add: `42`, `0.314`, `6.28`, `12.5`, `500.0`, `6.00`, `5.468`, `3.968`, `264.5`, `3.65`, `64.913`, `65.7`, `2.91`, `2.03` twice, `102.9`, `15.0` and `2.5`. Draft remove: `41` and `5.309`. Tracker add: `42` and `3.3`.

- Sections 4 and 5 hold byte-identical against the base. The frozen levers block re-checks carried once (raw md5 `7bbd964d...`).

- The display guards hold. The forms 14.97, 14.972, 3.816 and the rounded 27.363 read zero in the draft. The internal margin forms (+12.472, +498.9 and 5.99) read zero.

- The seven seated markers hold. The number-gate brackets, the classified line, the rename, the objective block and the safety forms hold.

## STE holds

- Draft: 6309 to 6388 words. Total 6 to 6. No category gains.

- Tracker: 2609 to 2660 words. Total 10 to 10. No category gains.

## Receipts

- Checks: `scratch/au_v042_gate_margins.py` and its log. 24 guards run closed. The gates pass on the first dry run.

- Candidate hashes: draft sha256 `f4bdd2f9...`, tracker sha256 `be5c2d37...`. All four carried blobs byte-verify at origin.

- Citation gate: rc=0. 38 cited rows, all signed (48 signed rows total). NR-042 enters the cite set. No cite drops.

- Review copy: `scratch/report-pdf-build/draft-live.docx` rebuilds on this push. Record draft `38c77f8`, seven seats resolved, 38 cited all signed, checker exit 0. Built 2026-10-14T18:42:07Z. md5 `1bec1726...`, byte-identical to the archived build `draft-38c77f8-20261014-184207.docx`. The delta from the copy the founder holds (v0.41): the section 3.3 gate table. Six rows now read, with the margin column.

## Notes

- One writer, one table sweep. The fold carries the margin column and the cells in the single pass, per the AU9 routing.

- The power pair reads the gate operand. The plan pair, +0.309 kW and +6.2 per cent, read the mean. The corrected forms stand (SV5).

- The operating-point table keeps its shape. SW2c does not ride this pass.

- The torque row prints the ratio only. No floor prints, per NR-040 boundary 2. No register row moves.

## Handoffs

- @aero-validator: the counter-read keys on this push. A values mover, the margin set and the FoS row forms at the note.

- @science-writer: sweep 28 keys on this push. The declared sets sit above. One glossary check: the term "Torsional capacity" enters the gate table.

- @science-validator: the display forms fold as signed. The internal forms stay internal. One glance for the record.

- @hermes: queue item AU9 closes at this seat. The partner-gated tails stay next, held on AU4 and AU7.

- @user: the gate table now shows which gates sit tight. Power is the closest gate at +6.28 per cent.

author, 2026-10-14.
