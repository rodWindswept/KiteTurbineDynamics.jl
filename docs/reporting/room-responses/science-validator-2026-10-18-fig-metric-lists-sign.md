# The fig Batch B metric lists sign: NR-062 and NR-063 (2026-10-18, science-validator)

**Base:** branch tip `97d15c9` on `bank-derate-cos2p65`.
**Read at:** the working tree before this landing.

## What signs

Two register rows sign the metric-card values for the figure seat
Batch B.

NR-062 carries the strip milestone power. NR-063 carries the
corner pick power.

The objectives already sign. NR-036 carries the seven strip
milestones. NR-051 carries the four corner objectives.

## The lists

The strip milestones print P_mean, P_end in kW.

| Milestone | P_mean, P_end (kW) |
|---|---|
| gen 0 | 5.85, 5.86 |
| gen 6 | 5.42, 5.4 |
| gen 10 | 5.89, 5.89 |
| gen 18 | 5.78, 5.78 |

| Milestone | P_mean, P_end (kW) |
|---|---|
| gen 22 | 5.76, 5.76 |
| gen 25 | 5.51, 5.52 |
| gen 26 | 5.31, 5.31 |

The corner picks print the objective from NR-051 and P_mean,
P_end in kW.

| Pick | Objective | P_mean, P_end (kW) |
|---|---|---|
| i1-g13-i1 | 60.646 | 6.01, 6.07 |
| i1-g7-i7 | 58.864 | 5.33, 5.36 |

| Pick | Objective | P_mean, P_end (kW) |
|---|---|---|
| i2-g21-i4 | 33.704 | 5.59, 5.59 |
| i3-g26-i8 | 33.812 | 5.9, 5.9 |

## The checks

The checker reads 44 checks, 0 fail.

It re-reads both extracts from the certified CSV files.

It matches the strip fitness digits against NR-036 and the corner
objectives against NR-051, digit for digit.

It re-reads every row against the island telemetry at data
commit `dd3cc6a`. The reads agree bit for bit on fitness, P_mean
and P_end.

## Boundaries

The values are window statistics of the recorded runs. They are
not a new capture.

The telemetry carries no standalone airborne-mass column. The
per-pick mass metric reads the NR-051 objective in kg-equivalent.
A true mass decomposition per pick would take a new derivation.

## Handoffs

The figure seat gets both lists with this receipt. The metric
cards may draw these values.

The mints carry their own SPECs. A drawn value that adds a new
quantity beyond these lists still takes a new row.

Evidence: `scratch/sv_fig_metric_lists_check.py`,
`scratch/sv_fig_metric_lists_2026-10-18.log`.
