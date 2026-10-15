# Room response: draft v0.54, the operating point completes and the torsion clause folds (2026-10-15, author)

**Status** LANDED. **Seat** author. **Read at** `614cc35` (branch `bank-derate-cos2p65`). The fold landed as `d453530`, range `614cc35..d453530`. The rebuild and the origin readback ride this pass.

**Scope** This response runs the two keyed items the room delivered this pass. The operating-point completion reads from the aero receipt's unprinted set (Harris review item 2.1) and the science fold at `2142d43`. That fold amends the NR-031/032 source cells to the AeroDyn v5.0.0 BEM basis and clears the print. The torsion clause and the floor sentence read from NR-052 and NR-053, signed at `2142d43`, and the register's reading rules. The sentence text reads as ruled: the collapse factor of safety at 1.5 or higher, the twist within the crossing limit, and the honest note that the 2.5 gate does not cover torsion as run.

## The fold, as landed

- The version pin refreshes to v0.54.

- The operating table takes three rows: "| Reference wind speed | 11.01 m/s at 9.41 m | NR-008, NR-032 |", "| Ring speed ratio | 5.566 | NR-031 |" and "| Tip-speed ratio | 6.8415 | NR-032 |".

- The operating paragraphs take the swept-area set and the density: "The swept area reads 45.9733 square metres raw and 39.4912 square metres on the wind-normal basis (NR-033). The air density reads 1.225 kilograms per cubic metre (NR-034)."

- The rotor Cp prints on the amended basis: "The rotor Cp reads from the AeroDyn v5.0.0 blade element momentum (BEM) table: 0.2944 at the ring speed ratio, and 0.2258 at the tip-speed ratio (NR-031, NR-032)."

- The Betz check prints: "The Betz ceiling reads 19.1304 kW, and the winner delivers 27.75 per cent of it (NR-034)."

- The gate block takes the per-class sentence and the torsion criteria: "The gate set reads per class. The structural members and the lines hold a factor of safety of 2.5 or higher (NR-015). Torsion keeps its own criteria. The collapse factor of safety reads 1.5 or higher, and the twist stays within the crossing limit (NR-052). The realisability floor reads 72.25 degrees (NR-053). As run, the 2.5 gate does not cover torsion (NR-052)."

- The tracker takes the v0.54 entry.

## Guards held

- The changed-line census reads exact. One replace sits at the pin. Three inserts follow: three lines at the table close, eleven lines at the operating paragraphs and nine lines at the gate block. The draft moves from 1,021 to 1,044 lines.

- The declared token diff reads exact. The draft removes `53` and adds `54`, `45.9733`, `39.4912`, `1.225`, `0.2944`, `0.2258`, `19.1304`, `27.75`, `5.566`, `6.8415`, `72.25`, `1.5`, `2.5` (two), the second `11.01` and `9.41`, and `0.0` (the `v5.0.0` version string). The tracker adds `54` and the section token `3.3`.

- Every held value form and cite count reads level: `22 degrees`, `25.698`, `NR-049` and `NR-050`. The whole `NR-` count reads 232 to 245.

- The new forms read once each, and the `Betz` name reads once where the draft read zero. The gate table rows and the held closes hold byte-identical. The untouched regions hold from the introduction through to the figure-provenance appendix.

- STE holds rc=0 on both files. The draft reads 7,003 to 7,171 words at total 8. The tracker reads 3,233 to 3,314 at total 12. Every category holds.

- The fold script holds 5 anchors and 36 guards, all closed. The candidate hashes read draft `b28a94b6…` and tracker `d56e89ec…`.

- The citation gate exits 0. It reads 48 cited rows, every one signed (54 signed rows total).

## The review-copy rebuild

- The build runs `python3 scripts/build_draft_docx.py` from the tip. The record reads draft `d453530` and the register file at `2142d43`.

- Eight of eight seats resolve. The build re-renders nothing. The kits embed as shipped.

- Built 2026-10-15T20:25:20Z. The live copy `scratch/report-pdf-build/draft-live.docx` reads md5 `72ef99bee03bc301433c3d533a1abc54`.

- The live copy reads byte-identical to its archived build `draft-d453530-20261015-202520.docx`. Eight media entries carry the eight kits.

- The delivered file carries the phrase set. `v0.54` reads once. The three rows, the area pair, the Cp sentence, the Betz pair, the torsion pair, the floor close and the torsion close read once each. The old marks read zero.

- The held set reads clean: the fixed-defect closes, the winner pair and the register-appendix holds.

- The delta from the copy the founder holds (the v0.53 build, md5 `e1eaef43…`) reads one front: the operating-point set and the torsion clause. No printed number changes.

## Receipts

- The fold evidence rides `d453530`. `scratch/au_v054_33_opoint_and_torsion_fold.py` and its log read byte-verified at origin.

- The rebuild check reads `scratch/au_v054_rebuild_check.py`. It prints 65 checks, 0 fail. Its log sits beside it.

## Notes

- The fold carries the amended NR-031/032 basis, per the register's reading rule. The "measured" wording stays with the blade-count ratio surface.

- Three review-adjacent items read outside the signed set at this pass: the shear law and its exponent, the shaft-elevation angle and the steady-wind note for the window swing. No signed row carries them. The room can route them if the item-2.1 table is to close fully.

- The torsion sentence follows the register's reading rules. Extending the 2.5 gate to torsion stays a founder call, recorded at the software seat.

## Handoffs

- @science-validator: the fold carries the amended cells and the new rows' sentence forms. The read keys on these bytes.

- @aero-validator: the v0.54 copy sits for a counter-read when the next copy pass opens. The fold is text-only. The item-2.1 set now prints, minus the three items named above.

- @science-writer: the sweep span takes the v0.54 move (`d453530`) and this receipt set.

- @fig-img-diagrams: nothing asked. No plate byte moves. The row-15 segment diagram's dependency, the section 2.3 derivation block, reads next at this seat.

- @hermes: the queue can record the operating-point print and the torsion clause closed at this seat. AU4 and the software story read next.

- @user: the two pieces of writing the room was waiting for are in the report. The winner's operating point now shows its wind, its ratios, its swept area, its air density and the Betz check. The safety section now says plainly what the 2.5 gate covers and that torsion keeps its own 1.5 criterion. No printed number changed, and the rebuilt copy sits with this message.

author, 2026-10-15.
