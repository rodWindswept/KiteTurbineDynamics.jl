# Captions: machine evolution strip

**Slug** `machine-evolution-strip`. **Status** GENERATE (re-render 2026-10-11). **Date** 2026-10-11.

Site: the report at §3.5, the evolution story. Reading order: seed to the
campaign winner, left to right, top row then bottom row. The wording comes from
the figures seat, STE-gate checked. Values cite NR-005, NR-006, NR-011
and NR-036. The geometry source is the signed extract
`strip-extract-2026-10-09-best-so-far`.

## Plain caption

This figure shows seven kite-turbine designs from one search run. The
row starts at the common seed and ends at the campaign winner. Each machine is
drawn from its built geometry, and all seven share one scale. The
number under each machine is its search objective, in kilograms. A
lower number is better.

## Technical caption (undergrad register, STE-clean form)

Seven panels show the best machine of island 3 at generations 0, 6, 10,
18, 22, 25 and 26. The labels follow the extract.

Each panel draws the built state of that genome. The drawing shows the
ring segments in their section colours, the TRPT lines between rings,
the blade segments, and the swept annulus of the main rotor as one
truncated cone.

The value under each machine is the search objective in kilograms
(NR-036). The drawings use the shaft frame. Distance along the shaft is
vertical, and the operating elevation is not drawn.

One fixed scale holds across the set: 0.0602 m per pixel, canvas 896 by
1028 pixels, scale bar 5 m in the footer. The set reads in two rows:
four panels above, three below. The machines differ in drawn size only
where their built size differs.

The final panel carries the campaign winner. It matches the register machine: three lines, six rings,
hub radius 4.580 m, ground radius 0.804 m, blade scales 0.82 and 0.20.
The strip claims geometry and the search objective. It prints no power
value and no airborne mass value.

## Generation note

Resolved at GENERATE by the figures seat. The engine is CairoMakie, the
machine-renderer D7 steer. The TikZ release backend stays open to the
room. Captions and stamp stay single-source in this kit. The SVG emits
glyph paths, not a text layer. The room holds this as an R2 item.

Re-render note (2026-10-11): the Harris 3.5 deltas land. The objective
labels cite NR-036. The report should embed the PDF vector so the
labels and footer stay crisp at print size.
