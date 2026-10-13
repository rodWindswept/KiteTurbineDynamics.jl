# Room response: F-VALUE counter-read, figure-map rows 4 and 5 (2026-10-13, aero-validator)

**Status** PASS, both gates. **Seat** aero-validator. **Read at** HEAD
`3140462`. The kit paths hold no drift from their landings
(`eval-timeline` `0d18300`, `k-basis` `52be5f5`).

This pass answers the hand-off from @fig-img-diagrams. The seat ran the
F-VALUE gate for the row-4 plate and the kit pin counter-read. The pass
covers the row-5 plate too. Its gate waits on the same seat. The check
reads committed bytes only. The seat ran no simulator.

## Result

- **eval-timeline (row 4), F-VALUE: PASS.**
- **k-basis (row 5), F-VALUE: PASS.**
- Pins: all fifteen manifest pins recompute. Two scripts, five inputs
  and eight outputs hold their hashes.
- F-REPRO counter-read: two fresh runs per kit. All five outputs and the
  manifest stay byte-identical to the committed set. The run stdout
  equals `checks.log` byte for byte.
- F-LABEL: the committed SVG text set equals the ledger set. 52 strings
  and 21 strings.
- The stamp trees resolve. `980de02` is the F3 extract parent. `8d01394`
  is the window-trace run base.

## F-VALUE, eval-timeline

Every drawn value recomputes from the committed extracts. Every value
equals its signed row at the stated precision.

- 10.17 rad/s reads NR-016. The full value reads 10.169820334285198.
- 13.38 rad/s reads NR-029. The window mean recomputes at
  13.380259861740395, exact.
- 5.309 kW and 5.314 kW read NR-008. The 5.0 kW floor reads NR-027 and
  NR-039.
- 2.841 ms reads NR-013 ext. The warm file ends at t = 0.002841 with
  strain 1.00081012. The first crossing sits at step 97, strain
  1.000277041.
- 1.448 at t = 5.798 ms reads NR-013 ext. The ruling grid max
  recomputes at 1.447982844.
- The cold and ruling files hold zero latches. Nothing past 60 ms
  exceeds 0.677081.

One basis note. "Last five" names the evaluator tail-5, the mean of the
last five window samples in the V13 code. The 100 Hz plotted tail reads
5.314264. The row reads 5.314114. Both forms round to the drawn 5.314 at
three decimals.

## F-VALUE, k-basis

- The ten sweep pairs recompute at 2 dp: 3.49 reject, then 5.45, 6.78,
  7.56, 8.00, 8.89, and 8.95 at the last four.
- The reject row reads 3.485236347784519 at full precision.
- k = 2.24 reads NR-015. The bracket `k ≥ 4` reads the plateau edge of
  NR-041. The band reads 8.9475 to 8.9511 at 4 dp. The plate prints no
  band numeral.
- The omega_eq column reads zero on all ten rows. Nothing draws from it.

## Evidence

- `scratch/av_fvalue_plates.py` and `scratch/av_fvalue_plates.log`: 75
  checks, all pass.
- The counter-run trees sit under the seat scratch, not in the repo.

Both plates stand ready for the fold. @fig-img-diagrams holds the map
rows and the kit records. Rod holds the visual pass.

aero-validator, 2026-10-13.
