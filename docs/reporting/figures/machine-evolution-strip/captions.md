# Captions: machine evolution strip

**Slug** `machine-evolution-strip`. **Status** GENERATE (re-render 2026-10-11). **Date** 2026-10-11.
**Caption split** 2026-10-12.

Site: the report at §3.5, the evolution story. Reading order: seed to the
campaign winner, left to right, top row then bottom row. The wording comes from
the figures seat, STE-gate checked, with the 2026-10-12 caption split
and the 2026-10-14 takeaway rewrite. Values cite
NR-005, NR-006, NR-011 and NR-036. The geometry source is the signed extract
`strip-extract-2026-10-09-best-so-far`.

The split (2026-10-12): the plain and technical captions carry the
scientific text only. The provenance line carries the audit tokens: data
commit, extract, rows, script commit. It resolves to the
figure-provenance appendix (draft v0.15). The report prints the
scientific captions. The strip stamp and the appendix carry the
provenance.

## Plain caption

The search improves the machine at every recorded step, from the
common seed to the campaign winner.

## Technical caption (undergrad register, STE-clean form)

Island 3's best-so-far objective falls from 36.109 to 27.364
kg-equivalent. The built geometry converges to the register winner
(NR-006, NR-005).

Seven panels show the best machine of island 3 at generations 0, 6, 10,
18, 22, 25 and 26. The labels match the recorded generations.

Each panel draws the built state of that genome. The drawing shows the
ring segments in their section colours, the TRPT lines between rings,
the blade segments, and the swept annulus of the main rotor as one
truncated cone.

Each machine prints three signed values. The first is the search
objective in kg-eq. The second is the decoded mass in kg. The third is
the window-end power in kW (NR-036, NR-066, NR-062).
NR-062 signs the window mean and the window end as a pair. The power on
each card is the window-end value the score uses (NR-062).
The drawings use the shaft frame. Distance along the shaft is
vertical, and the operating elevation is not drawn.

One fixed scale holds across the set. A 5 m scale bar sits in the footer.
The set reads in two rows: four panels above, three below. The machines
differ in drawn size only where their built size differs.

The final panel carries the campaign winner. It matches the register machine: three lines, six rings,
topmost ring radius 4.580 m, ground radius 0.804 m, blade scales 0.82 and 0.20.
The strip claims geometry, the search objective, the decoded mass and
the window-end power. The objective is mass plus penalties. The
penalties score the window-end power, the beam utilisation and the
twist margin.

The winner is not the lightest machine. Gen 10 reads 25.466 kg against
the winner's 25.698 kg. The winner pays 0.233 kg of mass to shed
4.515 kg of penalty. From gen 10 the mass moves inside 1.04 kg while
the objective falls 4.297 kg. The later gains come from penalty, not
from mass.

Three decimals on the mass are a decomposition against a
three-decimal objective. They are not a measurement.

## Provenance line

Data commit `dd3cc6a` · extract `strip-extract-2026-10-09-best-so-far` ·
rows NR-005, NR-006, NR-011, NR-036 · script commit `d0e410d` · full
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

Form note (2026-10-14): both caption tiers read kg-equivalent for the
objective (round-3 feedback routing). The drawn label keeps its (kg)
form. The strip render holds.

Caption lead (2026-10-14): the takeaway opens both tiers. The lead
prints the objective range from the signed rows (NR-006, NR-005).
Text only, no render moves.

Takeaway (2026-10-14): the plain tier reads one takeaway sentence
(the round-5 caption dedupe). The tier no longer repeats the
technical claim. Text only, no render moves.

Retirement note (2026-10-14): the hub-name retirement (round-6
comment 1). The final-panel line reads "topmost ring radius
4.580 m". Text only, no render moves.

Pin note (2026-10-20): the provenance line read script commit
74cfef9. The T4 render pass (d0e410d, landed f696930) changed the
drawn per-machine label from kg to kg-equivalent and re-cut the
plate bytes. The manifest script_commit reads d0e410d, the printed
footer stamp reads d0e410d, and the script sha256 at HEAD equals the
manifest value, so d0e410d is the state that built the bytes on
disk. The pin now reads d0e410d. The 2026-10-14 form note above
describes the pre-T4 label and no longer describes the plate. Text
and pin only, no render moves. (figures seat)

Mass and power note (2026-10-20): the strip re-cut draws two values
that the plate did not print before. Mass cites NR-066 and reads the
decode-only pass in `extract-mass.csv`. Power cites NR-062 and reads
the window-end value, the same value the score charges. The mass
carries the lifter, so it is the mass the campaign scored. The
2026-10-11 caption sent the reader to the objective alone, and the
sentence that said the strip prints no power value and no mass value
is withdrawn here. (figures seat)

Power column note (2026-10-20): the power line draws the window-end
value. NR-062 signs the window mean and the window end as a pair, and
the card prints the second. Gen 6 shows the difference: the mean reads
5.42 kW and the card reads 5.4 kW, as recorded. The clause names the
column, so a reader who checks the register table finds the right
member. Text only, no render moves. (figures seat)

Mass decode correction (2026-10-20): the first mass cut decoded at
`p.v_wind_ref` (11.0097 m/s) because the design call omitted the
`v_rated` keyword. The score path passes 11.0, and the 0.09 per cent
moved the sized ring mass about 0.03 kg. The corrected winner reads
25.698 kg, and the evaluator's own recorded mass for that genome is
25.69846825623688 kg. Gen 10 reads 25.466 kg, so the winner pays
0.233 kg of mass, not 0.245 kg. The objective, the power values and
every other drawn numeral stand. NR-066 needs an amend to the seven
values. (figures seat)
