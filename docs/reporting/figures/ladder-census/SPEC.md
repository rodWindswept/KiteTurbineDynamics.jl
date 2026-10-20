# SPEC: ladder failure census. The power ladder read through the current model.

**Slug** `ladder-census`

**Status** SPEC v1, GENERATE candidate. Figure map row 28, section 4.3. No
render exists.

**Owner** @figures-images-diagrams. **Content check** @aero-validator
(physics, era, axis) and @science-validator (the counts, NR-064 and NR-065).
**Reader layer** @author: the caption seated at map v54.

## The claim

The current gate certifies the 5 kW class and one 7 kW cell. Every rung
above 7 kW reads unproven by this gate, by stall reject or by cliff reject.

The plate reads the tool. It does not read the wind. It shows what the model
accepts on a fixed grid of designs. It does not bound the model. One gene,
moved inside the rung's own bounds, turns a 10 kW stall cell into a pass.

## The statistic

The outcome class of one design at one (rung, length). The class set holds
four values: pass, cliff, stall and clearance. The gate signature sets the
class. Wall time does not set the class.

A pass means gate acceptance at the design point. It does not mean the
design delivers its rated power. The `ok` test reads `P_gen >= 5.0` kW at
every rung (`ode_gate_v13.jl:224`). The `p_floor_kw=KW` argument at line 142
sizes the beams and does not set acceptance.

## The population and the count at each point

- 42 cells: 7 rungs by 6 lengths. One evaluation each. n = 1 per cell.
- Source: `scripts/results/ladder_v13_rerun_2026-10-20.csv`, md5
  `74408ea1`, 42 data rows and four stamp lines.
- Producing harness: the scratch probe, md5 `bb59e12f`. Its `ladder_cell`
  matches `ode_ladder_v13.jl` byte for byte. The in-tree script writes
  `ladder_v13.csv`, so it did not write this file.
- No cell aggregates. The plate draws no mean, no trend line and no fit.

## The drawing

- One panel. Rows are the seven rungs, 5 to 50 kW, in that order. Columns
  are the six shaft lengths: 12, 18, 21.2, 25, 30 and 40 m.
- Fill encodes the class. The legend names all four classes and their
  counts: pass 7, cliff 20, stall 14, clearance 1.
- A count column sits at the right edge: 6 of 6 at the 5 kW rung, 1 of 6 at
  7 kW, 0 of 30 for 10 kW and above. Each count reads NR-064.
- No cell carries a kW numeral. NR-064 holds the power range of the 5 kW
  column and the 8.33 kW of the 7 kW pass. The plate withholds them,
  because the row rule reads no power delivery.
- The stamp block prints the era, the git commit and the three script md5s.
- No old-era cell appears. No arrow joins two cells. The plate prints no
  flip count.

## Register rows

- `NR-064` carries the pass counts: 7 of 42, 6 of 6 at 5 kW, 1 of 6 at
  7 kW, and 0 of 30 at 10 kW and above.
- `NR-065` carries the class split: cliff 20, stall 14, clearance 1.
- The axis ticks, the legend words and the stamp are calibration. They
  carry no row.
- These numerals carry no row, and the plate must not print them: `k_mppt`
  8.23 and 1122.63, sin delta alpha 313, and the 0.44 to 0.81 Betz band.
  They are mechanism numbers in the census record.

## Era and stamp

One era: `era=2026-10-20_ladder-rerun`, `git=581d33f`. Gate `bb517061`,
seeds `6ac23be5`, ladder `250a41d0`.

The 2026-08-15 grid is a citable prior, not a population. The value `r_hub`
differs at every rung: 0.914 to 2.889 m in the old grid, and 4.32 m at 5 kW
and 2.4 m above it in the re-run. Zero of the ten verdict changes is design
attributable. No old cell draws, at any size, in any panel.

## The four checks

1. **Spec first.** This page holds the claim, the statistic, the population,
   the count and the rows.
2. **One era per chart.** One era stamp and one git commit sit on the plate.
   The plate draws one population.
3. **The axis states its job.** The row axis names the rated rung and its
   ordered category. The column axis names the shaft length in metres. A
   foot line reads that the grid samples designs, not conditions.
4. **Values from one source.** Every drawn count re-derives from the CSV at
   md5 `74408ea1` and maps to NR-064 or NR-065. These rows read the same CSV
   at the same anchor. The generator asserts each count against the file
   before it draws.

## What fails the plate

- A printed count that differs from NR-064 or NR-065.
- An old-era cell, an arrow between cells, or a flip count.
- A kW numeral inside a cell or in a caption.
- A legend class with no cell in the data.
- A derived numeral: no percentage, no delta and no rate.
- The 7 kW pass drawn as a band. One cell passes, and its twist ratio reads
  0.96 against a crossing at 1.00.
- A ledger string absent from the vector text layer.

## Lines still open

- The seated caption carries the counterexample sentence: one gene, set
  inside the rung's own bounds, moves the 10 kW stall cell to a pass. That
  sentence does not draw. If the room wants the counterexample on the plate,
  it needs its own spec delta, its own row and a second population.
- The generator name and the output path settle at GENERATE.
