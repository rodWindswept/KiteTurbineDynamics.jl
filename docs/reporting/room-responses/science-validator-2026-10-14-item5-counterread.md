# Room response: the item-5 lever-statistics extract counter-read (2026-10-14, science-validator)

**Status** The counter-read closes. The seven tables, the recipes and the NR-039 cross-check all reproduce from the raw telemetry. No discrepancy found. The tables stand as landed.

**Seat** science-validator. **Read at** HEAD `8d3b61d`, the tip at read time. No register move. Printed forms from the fold take register rows first, as routed. STE rc=0.

## The instrument

`scratch/sv_item5_counterread.py` re-reads the three raw telemetry files of the bankderate2 campaign. It does not call the builder. It recomputes every table quantity from the stated recipes and compares at stored precision.

The run reads 173 checks, 0 fail. The groups read 20 rank and shift checks, 13 bin checks and 41 gate-failure checks. Then 11 discrimination checks, 17 failure-rate checks and 12 penalty checks. Then 10 NR-039 checks, 13 headline-form checks and 36 input, pin and recipe checks. Log: `scratch/sv_item5_counterread.log`.

The seat checker re-runs green from this seat at 23 checks, 0 fail (`scratch/sv_item5_figcheck_rerun.log`). The builder re-runs byte-identical across the seven tables and the checks log.

## 1. The tables recompute

- Objective versus gene. All ten rank correlations and all ten bin shifts recompute. The rank column reads the same order.
- The bins. All 46 rows recompute at zero delta. The bin sets read as recorded.

- The headline quad rounds to `-0.5832`, `0.5042`, `-0.4033` and `-0.2764`. The three leads read target_Lr, blade_scale_top and bank_bottom.
- Gate failures. All 40 status-by-gene distributions recompute. The medians, quartiles, minima and maxima all read as stored.

- Discrimination. All ten rows recompute. The AUC forms read `0.7417` and `0.3261` against reject, and `0.7495` and `0.0016` against clearance.
- Failure rates. All 13 rows recompute, shares included. The rotor-count census re-reads 506 of 739, then 2 of 157, then 0 of 34.

- Penalty rows. All 508 rows recompute within `1e-9`, worst delta 0. All six derived columns match the stored digits exactly, 508 of 508 by repr equality.
- Penalty summary and the survivor rows. The four channel rows recompute, and the winner row and the two count-2 survivors re-read from the raw columns.

## 2. The NR-039 cross-check

The register carries the three full-precision strings. The winner charges recompute from its recorded columns at recorded precision.

Over-power reads `0.4805` against the record `0.49334`, delta `0.012837`, bound `0.031`. Utilisation delta `0.000133473`, bound `0.000745203`. Twist reads exact.

## 3. The decoder note, for the record

The stored draws carry fractional values: x4 27 of 930, x6 780 of 930. The ok set sits on the x4 grid, so the n_lines rank reads the same raw or decoded.

For rotor count the decoder is material. The raw draws read `0.031729` against the decoder form `0.108465`. The extract applies the decoder form, as its recipe states.

## Boundaries, as recorded

- Recorded columns only. P_range and stationarity are not telemetry columns, and mass is not a column. The remainder reads mass plus stationarity.
- The ok set is the survivor set of one search. The correlations read search structure, not causal levers.

- The worst-case rounding spans read `0.133` and `0.078` kg. The winner deltas sit inside their spans.

## Pins and sources

- The data commit `dd3cc6a` and the run `a76c5e9` resolve. The script commit `51ffc0d8` resolves. Every provenance line carries all three.
- The telemetry is byte-stable from `dd3cc6a` to this tip. The dataset delta reads additions-only: nine report exhibits, no telemetry touch.

- The telemetry input hashes re-read as `6f359c33..`, `54172ce5..` and `34d40e8e..` in the seat-checker log.
- The runner decoder sites, the campaign config and the objective seam carry the stated forms. The seam weights match the NR-046 forms.

## Handoffs

- @fig-img-diagrams: no discrepancy found, and the tables and the recipes stand. The Phase-1 gate passes at this seat for this read.
- @author: each printed form from the extract takes a register row at this desk first, as routed.
- @aero-validator: no F-VALUE leg, since no drawn value and no pin moves.

- @hermes: the item-5 counter-read closes at this seat. The ring lead flag stays next in the figures seat queue.
- @user: nothing needed. The draft, the figures and the review copy keep their state.

---

science-validator, 2026-10-14.
