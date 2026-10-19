# Room response: the fourth class lands at the aero seat (2026-10-19, aero-validator)

**Status** The `assumption` class seeds, survives the counter-read, and lands its repairs.

The ledger holds a value with no admissible citation, by design. It says so in its own words.

**Seat** aero-validator. **Read at** `ad40fb1` (draft `daab5102`, 1291 lines, 10570 words).

**Artifacts** `docs/reporting/value-claims-ledger.md` (md5 `f51b2e2d`, sha256 `c521b108`, 135 lines, 1899 words). `scratch/av_vcl_check.py` (md5 `69badd0c`).

**Checker** 46 checks, 0 fail. The final ledger is byte-identical to the @science-writer probe (`f51b2e2d`, `c521b108`). The room placed it. It is not a near copy.

## 1. What landed

- §1 reads "The four classes" and carries the `assumption` row, bound to **a dated ledger row carrying the value**. The rule cell reads "No admissible citation exists, so none prints". @science-validator named that qualifier. The pointer of the cell cites code that carries the number.

- Line 5 no longer asserts "No third state exists." A premise is neither state. It is not a reading. It stands in this ledger as **chosen and not read**.

- Line 18 carries the ink rule. A premise carries no mark. Its label prints as one text block for the whole curve, never on an axis. The plate-face clause had doubled at lines 16 and 18, two drift paths. Its per-reading placement contradicted the @fig one-block ruling. It left the record.

- The STE buy-back reads. Words 1577 to 1549, total 15 to 13, per100w 0.95 to 0.84.

- The counts move. Long_sentence 7 to 5. Long_paragraph 7 held. Em_dash 12 to 13.

- Line 119 extends the enforcement region. The close **and the section 6.2 method text** (draft 1189 to 1190 names the rule of use).

- §2b, the dated row. The element: the section 6.2 crossover-curve capacity factor. The value: 0.30, chosen and not read, held flat from the 10 kW rung to the 500 kW study point. The pointer: no admissible citation.

- The contrast sits at `src/economics.jl` line 227 (solver default 0.30). It also sits at lines 409 to 410. The tree runs 0.30 to 0.35 on the kite slope. A counter-reading, not a source.

- The closing sentence reads "This row carries a value with no admissible citation". No superlative. The carrier is the row, not the pointer cell.

Each citation in the row matches source, not the room.

- `economics.jl:227` reads `cf::Float64 = 0.30` with "Default 0.30 (30%)" at 236.

- Lines 409 to 410 read 0.30 (Kite 10kW) and 0.35 (Kite 50kW).

- Lines 417 to 418 show the pair computed with.

- `26.3` = 10 × 0.30 × 8,766

- `153.4` = 50 × 0.35 × 8,766

- Draft 1178 reads "a crossover curve from the 10 kW rung to a 500 kW utility-scale study point".

## 2. The counter-read repairs, all placed

- "No **admissible** citation exists, so none prints" from @science-validator, line 16.

- "not in the report **today**" placed at line 16 per the @science-writer string. The text at line 5, "it prints nowhere in the report", stays present-tense, scoped to this report. The one-word line-5 form is available if the validator still wants it there.

- "This row carries a value with no admissible citation". The repair drops the superlative and the wrong carrier.

- "a crossover curve **the section** cannot yet draw". The demonstrative-antecedent fault. It is the same shape the join fixed at 1169.

- The defining home of the label is §1 line 16, mirroring the `target` label at line 15. §2b points at it. The skip entry of the checker for `study assumption — chosen, not read, flat across the curve` is now load-bearing. The label appears backticked in the ledger. The "no unknown backticked tokens" check at line 114 is a hard gate, as @fig corrected.

## 3. The checker

`CLASSES` gains `assumption`. `SKIP_TOKENS` gains `assumption` and the label. A position read of the class column replaces the old tautology. The read checks 16 element rows. It skips headers and separators. An unclassed class cell fails.

The count stays on the full cell sweep. `class present: assumption` finds the §2b row. The scan runs the §2 heading to EOF, so the dated subsection is inside it. 45 to 46 checks, 0 fail. The docstring reads four classes.

## 4. The yield column: one find outside this commit

The @science-writer arithmetic holds. One row of mine extends it. `economics.jl:419` `44.0` is exact at **8,000 h** (50 × 0.11 × 8,000 = 44.0 MWh). It matches neither the 8,766 comment nor the 8,760 basis of rows 420 to 423.

- `2628.0` = 1 × 0.30 × 8,760

- `39420.0` = 10 × 0.45 × 8,760

- `7884.0` = 1 × 0.90 × 8,760

Rows 417 to 418 match 8,766 with correct comments. Five of the seven comments carry the wrong hour count. Not this commit, not ours to fix in it.

@science-validator, the column is the citation risk. Cite 417 to 418 by line, never the column by head.

## 5. Handoffs

- @hermes: **four paths, and the order is load-bearing.** Phase2 first (`au_sec61_phase2.py` accepts only `daab5102` to `207bd022`, 1297 / 10662). Then the tracker (`603` to `f95d6299`). Then the ledger commit. It carries `docs/reporting/value-claims-ledger.md`, `scratch/av_vcl_check.py`, this receipt, **and the draft**.

- `au_sec62_cf_word.py` applies on `207bd022` to `5be0a47d` (1297 / 10661, lint 25 and 0.24). Three word-preserving trims wait on a ruling.

- Run the word patch before phase2 and phase2 refuses, as designed. Both amended patch scripts sit outside git. They ride the commit that lands the draft, or the declared chain is unreproducible.

- @fig-img-diagrams: row 28 points at §2b. The string stays single-homed in §1 line 16. Row 28 lands in its own commit after the ledger commit.

- @science-validator: the counter-read has its answer. The only open micro-call is whether "today" also belongs on line 5.

- @author: the two-word repair now applies from the phase tip, `207bd022`. 1182 and 1198 move with the ledger commit. The ledger row is where the ruling lands.
