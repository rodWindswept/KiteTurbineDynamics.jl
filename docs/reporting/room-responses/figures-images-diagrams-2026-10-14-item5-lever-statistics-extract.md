# Room response: the item-5 lever-statistics extract (2026-10-14, figures seat)

**Status** LANDED. The item-5 extract builds from the v13 bankderate2
telemetry, checks clean end to end, and stands ready for the
counter-read. **Seat** figures-images-diagrams. **Read at** `6c51f5c9`,
the tables commit. The builder reads `51ffc0d`.

## What lands

The extract kit `docs/reporting/figures/lever-statistics-extract/`:
seven tables, the README and the checks log. The builder carries the
script-commit pin (`51ffc0d`) in every provenance line. The data commit
is `dd3cc6a`, the run `a76c5e9`, the era
`post-95c385d_wind-authority`. The telemetry is byte-stable from
`dd3cc6a` to this push.

The tables answer the three parts of feedback item 5.

## 1. Objective versus gene (508 ok rows)

The rank correlation of the recorded objective against each gene, and
the top minus bottom bin shift. The order reads by effect size:

- target_Lr, rho -0.5832, shift -3.892 kg
- blade_scale_top, +0.5042, +2.759 kg
- bank_bottom, -0.4033, -2.896 kg
- r_bottom, -0.2764, -1.801 kg
- blade_scale_bottom, +0.1656, +1.356 kg
- bank_top, +0.1252, +0.669 kg
- rotor_count, +0.1085, +26.592 kg (the top bin reads two rows)
- r_hub, +0.0736, +1.071 kg
- density_profile, +0.0662, -0.212 kg
- n_lines, -0.0287, +22.54 kg (the tail bins read single rows)

A negative rho reads: higher gene value, lower objective, within the
survivor set.

## 2. Gate failures by gene (930 rows)

- Expansion-rotor genomes almost never survive. Decoded rotor_count 1
  reads 506 of 739 ok, 68.5 per cent. Count 2 reads 2 of 157, 1.3 per
  cent. Count 3 reads 0 of 34.
- Every clearance reject carries rotor_count >= 2. The 110
  clearance_reject rows split 91 at count 2 and 19 at count 3.
- The two surviving count-2 designs sit at island 1 (gen 7 and gen 13).
  Their objectives read 58.864 and 60.646, and they are the two
  heaviest ok designs.
- The n_lines survival falls away above 5. Count 3 reads 66.9 per cent
  ok, count 4 reads 68.9, count 5 reads 43.6, count 6 reads 4.8.
- The rank separation reads: against reject, target_Lr 0.7417 and
  n_lines 0.3261. Against clearance_reject, blade_scale_top reads
  0.7495 and rotor_count reads 0.0016.

## 3. Penalty contributions (508 ok rows)

The three NR-046 charges recompute from the recorded columns. Per
channel over the ok set:

- over-power: fired 507 of 508, median 2.81, max 8.84, sum 1462.32,
  share 69.3 per cent of the penalties, dominant in 453 rows
- utilisation: fired 508, median 0.72, max 12.36, sum 506.36, share
  24.0 per cent, dominant in 46
- twist: fired 508, median 0.16, max 8.29, sum 141.13, share 6.7 per
  cent, dominant in 9
- total: min 0.68, median 3.96, max 15.14, sum 2109.81 kg-equivalent

The winner row recomputes inside its CSV rounding bound. Over-power
reads 0.4805 against the NR-039 full value 0.49334 (delta 0.0128,
bound 0.031). Utilisation reads 0.55778 against 0.55765 (delta
0.00013, bound 0.00075). Twist reads exact. The one ok design at
P_end 5.0 carries no over-power charge.

## Boundaries, as recorded

- Recorded columns only. P_range and stationarity are not telemetry
  columns (Phase 0 note). The stationarity charge folds into
  remainder_kg, and mass is not a column.
- The charges compute at recorded precision. The worst-case single-row
  rounding span over the ok set reads: over-power 0.133 kg, utilisation
  0.078 kg.
- The ok set is one search's survivor set. The correlations read search
  structure, not causal levers.

## Checks

- In-script: 18 checks, 0 fail (`checks.log`).
- Seat check `scratch/fig_lever_check.py` plus log: 23 checks, 0 fail.
  The recount, the two count-2 rows, the cross-table sums, the per-row
  recomputes and the winner recompute.
- Double run: byte-identical across the seven tables and the checks
  log.
- Input anchors (sha256): telemetry islands 1 to 3 read `6f359c33..`,
  `54172ce5..` and `34d40e8e..`.

## No surface moves

No drawn value, no pin, no map row, no draft, no tracker, no render
byte. No F-VALUE leg runs. The register waits for the fold's printed
forms.

## Handoffs

- @science-validator: the counter-read stands here. The tables, the
  recipes and the NR-039 winner cross-check are ready. The Phase-1 gate
  of the landscape plan sits at this read.
- @aero-validator: no F-VALUE leg, since no drawn value or pin moves.
  The charge forms recompute from the recorded columns on request.
- @hermes: the queue can record item-5 as closed at this seat. The next
  item at this seat is the ring lead flag.
- @user: nothing needed. The draft, the figures and the review copy
  keep their state.

---

figures-images-diagrams, 2026-10-14.
