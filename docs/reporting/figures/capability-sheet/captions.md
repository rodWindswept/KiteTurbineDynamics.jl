# Captions: the capability sheet

**Slug** `capability-sheet`. **Status** GENERATE. **Date** 2026-10-21.

Site: section 7, as Figure 10, two pages. Page A carries the four
outcome heatmaps. Page B carries three keys-only classes and the
dashboard frame. One figure number, one appendix row, two captions and
two population lines.

## Plain caption, page A

Four views of the same five by five grid of designs, each coloured by a
different outcome, from the designs that passed every check.

## Technical caption, page A

Page A draws four outcome heatmaps over the 508 ok designs. The axes
bin `r_hub` and `bank_top` on value quintiles, one bin per fifth of the
sorted population.

Each cell holds the median of one outcome. `fitness` reads 29.66 to
37.59 kg-equivalent (NR-078). `P_mean` reads 5.28 to 6.23 kW (NR-079).
`FoS` reads 9.30 to 14.53 (NR-080). `clearance` reads 5.04 to 5.93 m
(NR-081). Each panel carries its own colour limits. No cell prints a
count. Every cell holds ten designs or more, and the floor for a read
is five (NR-082).

All four panels read the 508 designs that cleared every gate. The `FoS`
panel and the `clearance` panel hold no cell below 2.5 or 1.5 m by
construction. Those two values are floors the population already met,
not margins the campaign achieved. The lower edge of the `P_mean` panel
is the 5.0 kW floor penalty of the objective, not a rejection gate.
`fitness` is the only panel with no floor signature.

## Plain caption, page B

Three more ways the platform draws the same campaign, with no number
printed, and the dashboard itself.

## Technical caption, page B

Page B draws three classes as specimens. M1 draws all 930 designs
across the ten genes, each gene on its own range, with ink for the
status class. M2 draws the rank correlation of the ten genes over the
508 ok designs. M3 orders the 508 ok designs by objective value. The
three panels print keys only.

C1 shows the dashboard at HEAD in its first interface. C1 is a render,
not a dataset read. The v2 cockpit is opt-in and is not shown.

These panels redraw chart classes from the rows of this campaign at
HEAD. They add no new run and no new column. Every value prints from
the 930 rows, or from the 508 that cleared every gate. Every value is
signed. They are not reproductions of the earlier figures of the
platform, and they do not stand in for them.

## Provenance line, both pages

data: island telemetry (`scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv`) · data commit `dd3cc6a` · run `a76c5e9` · era `post-95c385d_wind-authority` · rows: NR-001, NR-002, NR-005, NR-042, NR-078 to NR-082 · script: `docs/reporting/figures/capability-sheet/capability-sheet.py` and `render_dashboard_frame.jl` at the script commit

## Checks for the consistency pass

- One form per concept. Cells read by outcome name.
- Every printed value cites a register row. Page B prints no value and
  cites the conditioning rows only.
- The populations never trade. Page A holds one population. Page B
  names three, panel by panel. C1 reads no dataset.
- The floor sentence travels with page A. It names all three floors and
  the one panel that has none.
