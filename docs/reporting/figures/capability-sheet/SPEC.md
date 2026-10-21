# SPEC: capability-sheet. Figure 10, the chart classes of the platform.

**Slug** `capability-sheet`

**Status** SPEC v1, R1 build. Angle brackets mark binding slots.

**Owner** @figures-images-diagrams. **Content check** @science-validator
and @aero-validator. **Reader-facing layer** @author.

**Contracts** the reporting framework. The numbers register. The four
checks in `figure-generation-notes.md`. The chart-class census in
`docs/reporting/figures/prior-chart-classes.md`.

## 1. Why this sheet exists

Section 7 makes a capability claim. The platform can draw 19 of the 37
recurrent chart classes from the rows of this campaign without a new
run. The claim must show its own evidence.

This sheet is that evidence. It draws seven classes at HEAD from the
campaign of record. It then seats the dashboard frame beside them.

The sheet is one figure and one page. Eight separate plates would need
eight era lines and eight population lines. One stamp over mixed eras
is false. Here one run feeds the seven drawn panels. So the sheet holds
one stamp.

The sheet draws classes, not results. It is not a reproduction of any
prior plate. It does not stand in for one. The archive of prior figures
is a different section.

## 2. The slot ruling

One sheet, eight exhibits. A4 portrait, 7.6 in by 9.45 in, drawn at
300 dpi. A ninth exhibit takes a second page, or it takes a panel under
the type floor.

| row | exhibit | panel size |
|---|---|---|
| H1 to H4 | four heatmaps | 29 mm square each |
| C1 | dashboard frame | 133 mm wide |
| M1 | parallel coordinates | 75 mm wide |
| M2 | correlation matrix | 36 mm square |
| M3 | ordered objective | 37 mm wide |

Type size. The sheet draws at 7.6 in for a 174 mm slot, a scale of
0.90. Body text lands at 5.2 to 5.9 pt. The densest keys in M2 land
near 4.0 pt. Eight exhibits on one page cost that size. The other route
is two pages and a 6 pt floor throughout.

## 3. Inputs and populations

The three island telemetry files of
`v13_5kw_masslift_len18.8_rotorcount_bankderate2` hold 930 rows: 508
ok, 301 reject, 110 clearance_reject, 11 reject_twist. Data commit
`dd3cc6a`, run `a76c5e9`, era `post-95c385d_wind-authority`.

Each exhibit names its own population. The populations do not trade.

- **H1 to H4 and M2** read the 508 ok designs. Here `FoS` is finite and
  `twist_ratio` is never zero.
- **M1** reads all 930 designs. The status ink is the read.
- **M3** reads the 508 ok designs, ordered by objective value.
- **C1** reads no dataset. It is a render at HEAD.

## 4. The heatmap half (H1 to H4)

The bin rule is the signed one. Value quintiles over the 508 ok designs,
one bin per fifth of the sorted population. The bins break on rank, as
the checker of the signer does it.

Axis edges run `r_hub` 2.399 / 4.116 / 4.2248 / 4.32 / 4.5172 / 5.116 m
and `bank_top` 0.0 / 6.34 / 10.7 / 13.4 / 14.96 / 22.0 degrees.

Colour is the median of the outcome over the ok designs in the cell. It
is never the mean. Each panel carries its own colourbar limits. These
are the smallest and largest cell medians on that panel, rounded
outward to 2 dp. No cell falls outside its bar.

| panel | outcome | bar | row |
|---|---|---|---|
| H1 | `fitness` | 29.66 to 37.59 kg-eq | NR-078 |
| H2 | `P_mean` | 5.28 to 6.23 kW | NR-079 |
| H3 | `FoS` | 9.30 to 14.53 | NR-080 |
| H4 | `clearance` | 5.04 to 5.93 m | NR-081 |

Occupancy runs 10 to 36 designs per cell, median 21. No cell falls
under the five-design floor. So no cell prints a count (NR-082 display
form 2). The occupancy proof lives in the caption as two numbers. Axis
labels carry the six edges, not a bin index (NR-082 form 3).

## 5. The specimen half (M1 to M3), keys only

Three classes the report does not otherwise carry. They draw as
specimens. The form is the exhibit, and no panel prints a value.

- **M1 parallel coordinates.** All 930 designs, ten genes, each gene on
  its own range. Ink is status: ok, reject, clearance reject, twist
  reject. The legend carries the four class counts (NR-001, NR-002). No
  gene value prints.
- **M2 correlation matrix.** Spearman on the 508 ok designs, gene
  against gene. The ramp prints its analytic bounds only: −1, 0 and +1.
  No coefficient prints. No cell annotation appears.
- **M3 ordered objective.** The 508 ok designs, ordered by `fitness`,
  best to worst. No numeral prints beyond the axis scale.

Why keys only. A ten-gene axis at 75 mm cannot carry values above 4.8
pt. Printed values would take a table, and a table is another exhibit.
The specimen genre is what lets these three classes seat without a
register row. They print no value, so no value needs a signature.

What these panels do not claim. They are not evidence of a result. They
show that the platform holds the class, and that the class draws from
these bytes.

## 6. The capture (C1)

`render_dashboard_frame.jl` builds the dashboard at HEAD. It saves the
frame at 2000 x 1188 px: the 1600 x 950 logical units of the dashboard
at `px_per_unit = 1.25`, passed explicitly. The sheet crops this frame
to 966 x 708 at offset 401, 329. The manifest pins the hash of that
crop.

The frame reads the v1 interface. The v2 cockpit is opt-in, and this
capture does not show it. No reading of this frame may pass as a
reading of the v2 panels.

The tracked home. `render_dashboard_frame.jl` is the tracked home of
the renderer. That file sat untracked in `scratch/` before. The
`Script commit` cell of the figure-provenance appendix names this
directory. The capture now discharges the availability sentence that
every figure ships with its generating script.

## 7. The clause that travels in the caption

All four heatmap panels read the 508 designs that cleared every gate.
Three of the four are floor-conditioned. The caption must say so.

- `FoS` runs at 2.5 or above in every ok row. The population minimum is
  3.18. The lowest cell median is 9.30, which is 3.7 times the floor.
  The panel is survivor-conditional.
- `clearance` runs at 1.5 m or above in every ok row. The campaign
  rejected 110 designs at that gate. The lowest cell median is 5.04 m.
  The panel is survivor-conditional.
- `P_mean` holds no row below 5.02 kW. The lower edge of this panel is
  the 5.0 kW floor penalty of the objective, not a rejection gate.
- `fitness` is the only panel with no floor signature.

## 8. Checks

Every drawn value recomputes in the script from the three telemetry
files. The check list holds the row census, the status census, the 25
cells with smallest, median and largest occupancy, both edge lists
against the signed lists, the four colourbar limits against NR-078 to
NR-081, all 100 cell medians inside their bars, the three floor
conditions, the gate order, the pixel sizes of the capture, the winner
value of 27.364, and the rank curve at 508 values.

The gate order check reads that the 110 clearance rejects carry no
twist reading.

F-REPRO: two runs agree byte for byte. The script sets `svg.hashsalt`.
PDF and PNG metadata carry no timestamp.

## 9. What this sheet does not do

It prints no value that the register does not sign. It opens no new
register row. It draws no prior-era plate, and it reconstructs none. It
carries no time-domain or controller class, because the campaign holds
no time series.
