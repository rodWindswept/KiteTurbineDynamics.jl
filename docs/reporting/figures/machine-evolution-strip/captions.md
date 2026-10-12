# Captions: machine evolution strip

**Slug** `machine-evolution-strip`. **Status** GENERATE (re-render 2026-10-11). **Date** 2026-10-11.
**Caption split** 2026-10-12.

Site: the report at §3.5, the evolution story. Reading order: seed to the
campaign winner, left to right, top row then bottom row. The wording comes from
the figures seat, STE-gate checked, with the 2026-10-12 caption split. Values cite
NR-005, NR-006, NR-011 and NR-036. The geometry source is the signed extract
`strip-extract-2026-10-09-best-so-far`.

The split (2026-10-12): the plain and technical captions carry the
scientific text only. The provenance line carries the audit tokens: data
commit, extract, rows, script commit. It resolves to the
figure-provenance appendix (draft v0.15). The report prints the
scientific captions. The strip stamp and the appendix carry the
provenance.

## Plain caption

This figure shows seven kite-turbine designs from one search run. The
row starts at the common seed and ends at the campaign winner. Each machine is
drawn from its built geometry, and all seven share one scale. The
number under each machine is its search objective, in kilograms. A
lower number is better.

## Technical caption (undergrad register, STE-clean form)

Seven panels show the best machine of island 3 at generations 0, 6, 10,
18, 22, 25 and 26. The labels match the recorded generations.

Each panel draws the built state of that genome. The drawing shows the
ring segments in their section colours, the TRPT lines between rings,
the blade segments, and the swept annulus of the main rotor as one
truncated cone.

The value under each machine is the search objective in kilograms.
The drawings use the shaft frame. Distance along the shaft is
vertical, and the operating elevation is not drawn.

One fixed scale holds across the set. A 5 m scale bar sits in the footer.
The set reads in two rows: four panels above, three below. The machines
differ in drawn size only where their built size differs.

The final panel carries the campaign winner. It matches the register machine: three lines, six rings,
hub radius 4.580 m, ground radius 0.804 m, blade scales 0.82 and 0.20.
The strip claims geometry and the search objective. It prints no power
value and no airborne mass value.

## Provenance line

Data commit `dd3cc6a` · extract `strip-extract-2026-10-09-best-so-far` ·
rows NR-005, NR-006, NR-011, NR-036 · script commit `74cfef9` · full
record: the figure-provenance appendix.

## Generation note

Resolved at GENERATE by the figures seat. The engine is CairoMakie, the
machine-renderer D7 steer. The TikZ release backend stays open to the
room. Captions and stamp stay single-source in this kit. The SVG emits
glyph paths, not a text layer. The room holds this as an R2 item.

Re-render note (2026-10-11): the Harris 3.5 deltas land. The objective
labels cite NR-036. The report should embed the PDF vector so the
labels and footer stay crisp at print size.

Split note (2026-10-12): the NR-036 citation and the extract reference
leave the caption prose. The canvas and pixel values leave the caption.
Register-status and the manifest carry them. The text changed only. No
render moved.
