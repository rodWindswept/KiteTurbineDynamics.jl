# lever-statistics-extract: the item-5 lever-statistics extract

**Status** LANDED. **Date** 2026-10-14. **Owner** @figures-images-diagrams (figures seat).

The extract answers feedback item 5
(`docs/reporting/feedback/Feedback-message-1791925681590.md`): objective
versus gene, gate failures by gene, and penalty contributions across ok
designs. The tables hold recorded telemetry values and stated recipes. A
number that prints in the report takes a signed register row first.

## Sources

The three island telemetry files of the campaign
`v13_5kw_masslift_len18.8_rotorcount_bankderate2` (`scripts/results/`).
Data commit `dd3cc6a`, run `a76c5e9`, era `post-95c385d_wind-authority`.
930 rows: 508 ok, 301 reject, 110 clearance_reject, 11 reject_twist
(NR-001, NR-002). The telemetry is byte-stable from `dd3cc6a` to this
kit.

## Files

| file | content | rows |
|---|---|---|
| `extract-objective-vs-gene.csv` | the objective rank correlation per gene, and the top minus bottom bin shift | 10 |
| `extract-objective-by-gene-bins.csv` | the conditioned objective per gene bin, on the ok set | 46 |
| `extract-gate-failures-by-gene.csv` | the gene distribution per status class | 40 |
| `extract-failure-discrimination.csv` | the rank separation of the ok set against each failure class | 10 |
| `extract-failure-rates-by-value.csv` | status counts per discrete value | 13 |
| `extract-penalty-contributions.csv` | the three charges per ok design, and the remainder | 508 |
| `extract-penalty-summary.csv` | the per-channel charge statistics | 4 |
| `checks.log` | the in-script checks, 18 ok / 0 fail | - |

## Recipes

- **Objective versus gene.** The objective reads the recorded `fitness`
  column in kg-equivalent, on the 508 ok rows. `spearman_rho` reads the
  rank correlation between the gene value and the objective.
  `delta_med_kg` reads the median of the top bin minus the median of the
  bottom bin.
- **Bins.** Continuous genes split at five quantiles of the ok set.
  Heavy ties collapse a bin set: blade_scale_top reads three bins, and
  blade_scale_bottom reads four. Integer genes group at the decoder
  value.
- **Gate failures.** Each status class reads its gene distribution over
  all 930 rows. The `auc_*` column reads the rank separation between the
  ok set and a failure class. The value 0.500 reads no separation.
- **Failure rates.** Status counts per discrete value. `n_lines` and
  `rotor_count` take the decoder form `round(clamp(x))`. `n_active`
  reads the recorded decode column.
- **Penalty contributions.** The charges recompute from the recorded
  columns through the NR-046 forms: over-power
  `5.0 * max(P_end - 5.0, 0)^2`, utilisation `20.0 * (2.5 / FoS)^2`,
  and twist `1.0 * (r / (1 - r))^2` with `r = min(twist_ratio, 1)`. The
  power term reads the tail-5 end power (`P_end`). `remainder_kg` reads
  `fitness` minus the three charges. `penalty_share_pct` reads the
  penalties over the recorded `fitness`.

## Boundaries

- **Recorded columns only.** The telemetry supplies every input, and the
  three charges compute at recorded precision.
- **P_range and stationarity are not telemetry columns** (Phase 0 audit
  note, `docs/validation/2026-10-08-phase0-bankderate2-audit.md`). The
  stationarity charge is not reconstructable here. It folds into
  `remainder_kg`.
- **Mass is not a telemetry column.** `remainder_kg` reads mass plus
  stationarity.
- **Recorded precision.** `P_end` and `FoS` print at two decimals, and
  `fitness` at three. The worst-case single-row charge rounding span
  over the ok set: over-power 0.133 kg, utilisation 0.078 kg.
- **The ok set is the survivor set of one search.** The correlations
  read search structure, not causal levers.

## Checks

`checks.log` carries the in-script checks (18 ok / 0 fail): the status
mix, the ok-row gate and range fields, the decoder cross-checks, the
winner charge recompute inside its CSV rounding bound, and the register
strings.

The seat check sits at `scratch/fig_lever_check.py` plus its log. Two
builder runs stay byte-identical across the seven tables and the checks
log.

## Regeneration

```bash
/usr/bin/python3 docs/reporting/figures/lever-statistics-extract/build-extract.py \
    --script-commit <hex>
```

---

figures-images-diagrams, 2026-10-14.
