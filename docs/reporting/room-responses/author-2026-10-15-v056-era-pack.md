# Room response: draft v0.56, the era pack folds (2026-10-15, author)

**Status** LANDED. **Seat** author. **Read at** `6c2b0f8` (branch `bank-derate-cos2p65`). The fold landed as `c9f0560`, range `6c2b0f8..c9f0560`. The rebuild and the origin readback ride this pass.

**Scope** This response folds the three blocks the science-writer seat supplied in the era pack (`1c65d27`). The supply sits at `scratch/sw_era_pack_supply.md`. The era call reads as ruled. The fold takes blocks A, B and C from the supply and the receipt, asserted byte-identical across the two. It runs onto the supply-pinned draft md5 (`ebee36da…`).

## The fold, as landed

- The version pin refreshes to v0.56.

- Block A, section 3.1. The line "This campaign is the first screen after the physics-validation era." leaves. "This campaign is the first search campaign of the wind-authority era." lands. The companion line "Larger and wider campaigns sit ahead." holds byte-identical.

- Block B, section 4.2. The six ledger rows take date order. The header and the rule hold.

  The sequence reads 2026-08-13, 08-14, 08-22, 08-22, 08-24, 08-26. All 30 body cells hold byte for byte, compared as sets. The two 08-22 rows keep their same-day tie. The class-grouped prose after the table holds.

- Block C, the load block. Three sentences land after the anchor line. The anchor reads "That load forces about 9 kW from the seed (NR-047)."

  The block names the earlier round, its destructive resonance and its non-comparability. It carries no digit and no cite.

- The tracker takes the v0.56 entry.

## Guards held

- The changed-line census reads exact. One replace sits at the pin. One insert sits at the load block, four lines deep. One replace sits at the era line.

  The ledger table reads as insert one, keep one, insert three, keep one and delete four. The net effect is the six-row reorder. The draft moves from 1,059 to 1,063 lines.

- The declared token diff reads exact. The draft removes `55` and adds `56`. The tracker adds `56`, `3.1`, `4.2` and the `2.2.2` pair (`2.2` and `2`).

- The block md5s read A `c355e133…`, B `47b78ad3…` and C `f7347b67…`.

- Every held value form and cite count reads level: `36.109`, `25.698`, `NR-047`, `NR-013 ext2` and the least-margin sentence. The whole `NR-` count holds at 250.

- The new forms read once each. The untouched regions hold from the introduction through to the figure-provenance appendix.

- STE holds rc=0 on both files. The draft reads 7,298 to 7,341 words at total 8. The tracker reads 3,378 to 3,434 at total 12. Every category holds.

- The fold script holds 5 anchors and 39 guards, all closed. The candidate hashes read draft `8d8be3b9…` and tracker `731525f8…`.

- The citation gate exits 0. It reads 52 cited rows, every one signed (58 signed rows total).

## The review-copy rebuild

- The build runs `python3 scripts/build_draft_docx.py` from the tip. The record reads draft `c9f0560` and the register file at `1b09190`.

- Eight of eight seats resolve. The build re-renders nothing. The kits embed as shipped.

- Built 2026-10-15T21:57:02Z. The live copy `scratch/report-pdf-build/draft-live.docx` reads md5 `5ecee42e6dcf1f16c6eaec3e2a2bd87a`.

- The live copy reads byte-identical to its archived build `draft-c9f0560-20261015-215702.docx`. Eight media entries carry the eight kits.

- The delivered file carries the phrase set. The pin reads once. The era sentence, the six ledger rows in date order and the three back-pointer lines read once. The old marks read zero.

- The delta from the founder copy reads one front. The era phrase, the ledger date order and the back-pointer enter. The founder holds the v0.55 build (md5 `4c438414…`).

## Receipts

- The fold evidence rides `c9f0560`. `scratch/au_v056_era_pack_fold.py` and its log read byte-verified at origin.

- The rebuild check reads `scratch/au_v056_rebuild_check.py`. It prints 52 checks, 0 fail. Its log sits beside it.

## Notes

- The heading call: no `### 2.3` heading mints at this pass. The back-pointer lands at the section 2.2.2 anchor. The renumber rides the structure pass, per the standing ruling.

- The supplied first-claim form folds as sent. The no-first variant stays in the supply if the room flips the call.

- One new term enters the draft: the destructive resonance. It hands to the glossary owner in this receipt.

- The section 3.2 fold still waits on the visual pass alone.

## Handoffs

- @science-writer: blocks A, B and C fold as supplied, byte-checked across the supply and the receipt. The sweep span takes the v0.56 move (`c9f0560`). The resonance term joins the glossary work if you want the row.

- @science-validator: no row changes and no new cites. The folded text carries no digit. Nothing opens.

- @hermes: the queue can record the era pack folded at the author seat. Sweep 33 keys on `c9f0560`.

- @fig-img-diagrams: no plate byte moves.

- @user: the extra sentence you ruled is in, exactly as the science desk wrote it. Two small record fixes land beside it. The report now names the era the stamps carry. The failure table reads in date order with every cell unchanged. No number changed, and the rebuilt copy sits below.

author, 2026-10-15.
