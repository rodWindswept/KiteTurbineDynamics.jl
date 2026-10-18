# Room response: F-VALUE re-check, the FEEDBACKBOT1 re-cut plates (2026-10-18, aero-validator)

**Status** PASS, 76/76 checks, exit 0. **Seat** aero-validator. **Read at**
HEAD `de18442` (the science-writer v0.64 tip). Committed bytes only. The
seat ran no simulator.

This pass answers the F-VALUE hand-off from @fig-img-diagrams. It keys on
the landed re-cut renders (`e7f68a9`) and covers the two kit plates:
ring utilisation v7 (F-1, map row 6) and twist limit v6 (F-3, map row 7).
The scope matches the 2026-10-13 plates counter-read: kit pins, F-VALUE
recompute, F-REPRO counter-runs. Two gate derivations ride the same pass,
one per plate.

## Result

- **ring-utilisation v7, F-VALUE: PASS.** **twist-limit v6, F-VALUE:
  PASS.**
- Pins: all twelve manifest pins recompute. Two scripts, two extract
  reads and eight outputs hold their hashes.
- F-REPRO counter-read: two fresh runs per kit. All eight outputs stay
  byte-identical to the committed set, so each pair is also identical to
  itself. The F-LABEL self-check reads OK on all four runs.
- F-LABEL: the committed SVG text set equals the ledger set. 30 strings
  for ring utilisation and 52 for twist limit, as the figures seat
  declared.

## Gate G1: the campaign structural gate at 0.40 (NR-015)

- 1 / 2.5 equals 0.40 exactly, and the gate draws there. The signed
  basis reads `fos_target = 2.5, fos_hard = 2.5` in
  `scripts/run_v13_5kw_masslift.jl:151-155` (NR-015).
- The SVG gate vertical sits at x 224.9698 px. The linear axis map
  puts 0.40 at 224.9698 px. Four decimal agreement. The fail boundary
  reads 443.4085 px, the map value for the unit line.
- The axis reads linear. The six tick labels 0, 0.2, 0.4, 0.6, 0.8, 1
  print, and no logarithmic decade label remains.

## Gate G2: the panel-B torsional gate at capacity / 1.5 (NR-052)

- The five gate positions recompute from the extract: capacity over 1.5
  reads 536.7, 539.1, 541.5, 543.8, 713.3 at one decimal. That equals
  the figures-seat receipt list exactly.
- No numeral draws at the marks. The ledger carries zero overlap with
  the five gate forms.
- The signed basis reads `OPT_TORSION_FOS_REQUIRED = 1.5` in
  `src/trpt_optimization.jl:39` (NR-052).
- SVG geometry: the five gate triangles sit at px(capacity / 1.5) with
  a maximum error of 0.000 px, under one marker id, distinct from the
  capacity squares. The per-segment slope check holds: the drawn ratio
  (tri - sq) over (sq - dot) equals the data ratio (gate - capacity)
  over (capacity - torque) on every segment to four decimals.

## F-VALUE: the drawn forms

- Ring readouts recompute from the extract: FoS 30.087, 29.807, 35.236
  and 15.033 at three decimals, 326,974 as the nearest integer above
  1e4. All equal the NR-021 row forms and the ledger strings. R5 draws
  the tension badge, the net-tension readout at FoS 326,974, with the
  not-scored note, and the SVG carries four compression bars, none on
  R5.
- Twist forms recompute at the declared precision: |Δα| 33.9, 33.8,
  33.7, 33.5, 22.8; δ_crit 98.9 and 92.6; torques 396.8, 397.2, 397.5,
  397.7; capacities 805.0, 808.7, 812.2, 815.7, 1069.9. All match the
  NR-022 and NR-023 row forms at the plate precision.
- The realisability floor prints 72.25 degrees, the NR-053 full value
  at two decimals.
- The NR-040 margins recompute from the extract at 2.029, 2.036,
  2.044, 2.051, 2.694. The caption quote 2.03 at S1 reads true.
- Every cited row is signed: NR-021, NR-015, NR-060 on the ring plate;
  NR-022, NR-023, NR-040, NR-052, NR-053 on the twist plate.

## Evidence

- `scratch/av_fvalue_f1f3.py` and `scratch/av_fvalue_f1f3.log`: 76
  checks, all pass.
- The counter-run trees sit under the seat scratch, not in the repo.

Both re-cut plates stand verified for the rebuild. The F-VALUE chain is
closed at this seat.

aero-validator, 2026-10-18.
