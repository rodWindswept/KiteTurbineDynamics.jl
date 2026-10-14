# Room response: the F-VALUE counter-read for the levers family (2026-10-14, aero-validator)

**Status** F-VALUE counter-read, figure-map rows 20 and 21, slugs `pca-landscape` and `pca-atlas`. Read at tip `c434fa44`. Outcome: 36 checks pass, 15 defects, 1 query, 0 failures.

**Seat** aero-validator.

**Evidence** `scratch/av_pca_fvalue_counterread.py` and the log beside it.

## 1. The values verify

The read re-walked the census and recomputed the projection from the raw draw columns.

- Census. The landscape carries 46 strings and the atlas 37. Both sets equal the SVG text layers in both directions.

- Scale. The 16 landscape scale nodes match the tick sources in the generator. The 30 atlas nodes match the recomputed lo, mid and hi colour labels at three significant figures.

- Readouts. Every drawn readout equals its signed row at the drawn precision. The pairs: 22.4 and 17.3 to NR-044, 36.109 to NR-006, 27.364 to NR-005, 930 to NR-001.

- Recompute. A numpy pass gives shares 22.434667 and 17.263044, pair total 39.697710, and every loading at four decimals. The seed fit reads 36.109. The winner fit reads 27.364 at generation 26.

- Counts. The matrix holds 930 rows over three islands, with the status mix 508, 301, 110 and 11. Both journey coordinates land on the kit pins.

- Pins. Every worktree byte equals HEAD. The outputs and the telemetry match the manifests.

## 2. Defect one: the kits invert the NR-005 and NR-006 cites

Text only. Six files. No render moves.

The register reads NR-005 as the winner value, 27.364 at generation 26. It reads NR-006 as the common seed, 36.109. Both kits invert the pair on three surfaces each. The draft, the sweeps and the strip carry the register mapping.

The exact edits:

- `pca-landscape/SPEC.md` line 92: the source cell reads `NR-006`.

- `pca-landscape/SPEC.md` line 93: the source cell reads `NR-005`.

- `pca-landscape/register-status.md` line 11: `| NR-005 | The winner value, 27.364 | Signed |`.

- `pca-landscape/register-status.md` line 12: `| NR-006 | The common seed value, 36.109 | Signed |`.

- `pca-landscape/captions-draft.md` line 20: `starts at 36.109 (NR-006). The winner ends at 27.364 (NR-005).`

- `pca-atlas/SPEC.md` line 77: the source cell reads `NR-006`.

- `pca-atlas/SPEC.md` line 78: the source cell reads `NR-005`.

- `pca-atlas/register-status.md` line 11: `| NR-005 | The winner value, 27.364 | Signed |`.

- `pca-atlas/register-status.md` line 12: `| NR-006 | The common seed value, 36.109 | Signed |`.

- `pca-atlas/captions-draft.md` line 19: `(36.109, NR-006)` and `(27.364, NR-005)`.

A sweep found no further cite sites beyond the six files above.

## 3. Defect two: the landscape stamp and the NR-044 cites

These strings draw onto the plate. The fix needs a render.

- The `pca-landscape` projection stamp reads `variance shares pending their row`. NR-044 signed at `2ad023c`, and the kit note says Row closed. The stamp must take a signed form.

- Both source stamps list `rows NR-001, NR-005, NR-006`. The landscape draws the two NR-044 quotes. The atlas lists the row in its Rows-cited block. Recommendation: both stamps take the four-row set.

- The render takes the `ROWS` constant in both generators and `stamp2` in the landscape generator. It re-walks F-LABEL and F-REPRO and takes new pins.

## 4. One query

The landscape subtitle prints `31 generations each`. No row carries the generation count. The count derives from the 310 rows per island at ten draws per generation. Disposition wanted: a row, or the count drops.

## 5. State and handoffs

- F-VALUE on the drawn values stands at `c434fa44`. The two defects gate the folds.

- @fig-img-diagrams: the fix list sits above and in the log, one line per site.

- @author: the section 3.4 pointers may ride. Hold the caption text until defect one lands.

- @science-writer: the reading may land. The cites take the register mapping.

- @science-validator: FYI only. This read found the swap outside the NR-044 fold scope.

- @user: the chart numbers all verify. The fixes are citation text, not measurements.

## Boundaries

This read did not re-run F-REPRO. The kit log carries the two-run byte identity. This read verified the output pins instead.

This read did not parse the PDF and the PNG. The SVG text layer and the ledger carry the census.

The projection reads the raw draw columns as logged. The rounding of x4 and x6 does not apply. The figure maps the draw space.
