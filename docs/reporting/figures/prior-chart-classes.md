# Prior chart classes: what the earlier campaigns drew, and what this campaign can draw

**Slug** `prior-chart-classes`

**Status** LIVE. **Date** 2026-10-21. **Owner** @figures-images-diagrams.

**Contract** the founder ask of 2026-10-20: the prior analysis sets hold
classes of chart, and the report should carry those classes on the
current campaign. The four-check gate (form translates, bytes never do).
The figure map (the roster and its slots). The numbers register (the
firewall).

## 1. Purpose

The founder asked why the prior chart classes have not entered this
report. This document answers with a measured census, and it names the
roster row that already holds the seats.

It draws nothing. It prints no value that a register row does not carry.
It opens no new roster row.

## 2. The inventory, measured

**320 image files (PNG, SVG and PDF) sit in 16 directories at branch
tip.** They reduce to **163 distinct stems**, and **37 stems recur in
three or more sets**. Those 37 are the classes: one campaign repeated
them, so the room can read them as a type of analysis and not as one
plate.

| pipeline | files | form |
|---|---|---|
| `figures/` | 24 | campaign PNGs, the direct ancestors |
| `figures/report/` | 14 | report-set PNGs: power curve, FoS envelope, blade scaling, loss discriminator |
| `charts/output/` | 6 | the declarative set: `chart-spec.toml` to `generate_charts.jl`, deterministic |
| `docs/outreach/` | 21 | five kit sets, each with a SPEC, a generator, prose and a review, plus the outreach set |
| `scripts/figures/` | 38 | the script-side set |
| `TRPT_Results/` | 18 | the TRPT study set |
| campaign analysis sets | 199 | the five pitch-depower campaigns, `mppt_twist_sweep`, `control_maps`, `trpt_opt_v2/cartography`, `ramp_traces` |

The campaign analysis sets carry the numbered slots, and every campaign
repeats them: 01 heatmaps, 02 heatmaps tension, 03 heatmap brake time,
04 parallel coordinates, 05 ranked configs, 06 and 07 3D surfaces, 08
and 09 timeseries best and worst, 10 composite waterfall, 11
sensitivity bar, 12 disqualifications, 13 control efficacy.

A second family carries the `science_` prefix: torsional and control
classes, which read a time series.

## 3. What this campaign holds

The campaign of record is `v13_5kw_masslift_len18.8_rotorcount_bankderate2`,
data commit `dd3cc6a`, run `a76c5e9`. Three island telemetry files hold
**930 rows**: 508 ok, 301 reject, 110 clearance_reject, 11 reject_twist.
Each row carries 32 columns: fitness, status, `P_mean`, `P_end`,
`T_lift`, FoS, `twist_ratio`, `clearance`, `n_lines`, `rings`,
`n_active`, `tether`, six geometry columns, and the ten gene columns `x1` to `x10`.

One row is one design at one window-end read. **The campaign holds no
time series.**

That single fact sorts the 37 classes.

## 4. The bins

**Already drawn, 1 class.** `design_space_3d` is the PCA field. Rows 20
and 21 carry it at R2, and their F-VALUE re-census closed at `7329191`.

**Drawable now, no new run, 16 classes.** The 930 rows, or a table
already built from them, is the whole input.

| class | source |
|---|---|
| `heatmaps_smoothness`, `heatmaps_tension`, `heatmap_brake_time` | the 930 rows, two genes binned pairwise |
| `heat_nrings_vs_nlines` | the same bins on the ring and line counts |
| `parallel_coordinates`, `parallel_multivariate` | the 930 rows, ten genes, status ink |
| `ranked_configs` | the `fitness` column, ordered |
| `3d_surface_duration_elev`, `3d_surface_payout_dmode` | two genes against one outcome |
| `composite_waterfall` | `extract-penalty-contributions.csv`, 508 rows |
| `sensitivity_bar` | `extract-objective-vs-gene.csv`, 10 rows |
| `disqualifications` | `extract-failure-rates-by-value.csv`, 13 rows |
| `correlation_matrix` | the 930 rows, gene against gene |
| `survival_envelope` | `fitness` against the gate boundary |
| `safety_intersection` | `clearance` against `twist_ratio` |
| `spider_chart` | the genes of one design on a normalised scale |

All sixteen read the telemetry or a column that it carries. Three read
one of the item-5 tables directly: the waterfall, the sensitivity bar and
the disqualification census. That extract (`lever-statistics-extract`,
landed `6c51f5c`, 7 tables, 18 checks) holds the sensitivity, the bins,
the failure rates, the failure discrimination and the three charges.
**It has carried those tables since 2026-10-14 with no plate and no
roster row:** the figure map returns zero hits for `lever-statistics`.

**One new extract each, 4 classes.** The class needs a table that does
not exist yet, and the table builds from recorded columns:
`timeseries_best5` and `timeseries_worst5` (the traces of one design, from
`window-trace-extract`), `axial_family_boxplot`, and
`3d_nrings_nlines_rhub_mass` (the decode columns, which need a family
label first).

**Needs a run this campaign does not hold, 16 classes.** Every
time-domain and controller class: `control_efficacy`,
`control_surface_3d`, `event_cascade`, `latching_window`,
`manifold_gradient`, `phase_portrait`, `regime_bifurcation`,
`sobol_first_order`, `tension_hysteresis`, `tension_violin`,
`torque_speed_phase`, `torsional_energy`, `torsional_slip_hysteresis`,
`torsional_spectrogram`, `torsional_twist_profile`, `tulloch_fft`. A
window-end read cannot draw them. They need a dynamics run or a
controller sweep, and this campaign holds neither.

## 5. The seat that already exists

Row 8 of the figure map reads "Lever set (four slots). Census and
envelope", section 3.4, status `waiting`, gate "Landscape Phases 1 to 2".

**The gate is open.** Rows 20 (`pca-landscape`) and 21 (`pca-atlas`) are
R2, their F-VALUE re-census closed at `7329191`, and both read this same
telemetry. Row 8 has waited on work that has landed.

So the classes need no new slot. Four of them take the four slots that
row 8 already holds. Row 25 holds the parallel-coordinates class against
this telemetry, and row 17 (the sensitivity tornado) stays its own row:
it perturbs the ODE path, which is a different method on a different
input.

**The proposed four**, each with a source table that exists before its
SPEC:

1. **Sensitivity rank bar.** `extract-objective-vs-gene.csv`, 10 rows:
   the rank correlation of each gene against the objective, and the
   median shift from the bottom bin to the top bin. This is a population
   read over 930 designs. It does not close row 17.
2. **Disqualification census.** `extract-failure-rates-by-value.csv`, 13
   rows, with `extract-gate-failures-by-gene.csv`, 40 rows, as the paired
   panel: what fails, and which gene values carry it.
3. **Charge waterfall.** `extract-penalty-contributions.csv`, 508 rows,
   with the four-channel summary. The summary reads over-power at 69.31
   percent of the total charge, utilisation at 24.00 and twist at 6.69,
   and over-power is the largest channel in 453 of the 508 ok rows. No
   plate carries that fact.
4. **Response surface.** Two genes at a time against one outcome, over
   the 930 rows: the heatmap and 3D-surface class, which holds no row
   today. This is the envelope read that row 8 names.

## 6. The gate each plate still needs

- **The numbers seat.** A value list and a register row for every number
  that prints. These plates draw values, so none renders before its rows
  sign.
- **The aero seat.** The axis signs for FoS, `twist_ratio` and
  `clearance`, and the gate lines.
- **The author seat.** One ruling: row 8 is one four-panel plate, or four
  plates. The slot count is one row either way, but the caption and the
  page budget differ.
- **The figures seat.** The SPEC, the script, the label ledger, the
  manifest, and two runs that agree byte for byte.

## 7. What this document does not do

No value here prints in the report until its register row signs. No
number above moves a cited count, a draft byte, a plate hash or a
manifest pin. The bin census describes the data, not a result.
