# SPEC: system anatomy. The machine, its parts and its lift chain.

**Slug** `system-anatomy`

**Status** SPEC v1, round 1 open. Every number below binds to a signed row.
Angle brackets ⟨⟩ mark binding slots. A slot resolves at GENERATE. The
numbers register v1 (`docs/reporting/numbers-register.md`) supplies the
citation discipline.

**Owner** @figures-images-diagrams. **Render ancestor** `machine-evolution-strip`.
The two plates share one decode path. **Element library**
`docs/reporting/figures/elements/ktd-fig-elements.tex`. Defined once here.
The planned genome strip, winner anatomy and strip re-render plates mount
it. **Content check** @science-validator and @aero-validator. **Visual
check** the multimodal image-reader, on the visual checklist only. Pixels
never validate numbers. Rod does the final visual pass. **Reader-facing
layer** @author. @author checks each label against Methods section 2.1 and
Results section 3.3. **Captions** @science-writer, from the seat draft
`captions-draft.md`.

**Contracts** the reporting framework (figure workflow: SPEC / GENERATE /
CHECK, three rounds, deltas, dual captions). The numbers register (the
firewall).

## Why this plate exists

The reader meets the machine before the genome, the search and the result.
This plate sets the vocabulary: ring, line, rotor, segment. It shows the
load path: lifter, lift line, sky anchor, cyan line, lift bearing, lifting bridles,
main rotor, TRPT, ground station.

## Sources. Reuse, do not rebuild.

- The geometry comes from the same decode path as the certified strip:
  `design_from_vector_v10` then `size_beams_closed_form` then
  `build_system_from_v10`. No ODE runs. Receipt: `scratch/fig1_decode_winner.jl`
  and its log, both committed. Data commit dd3cc6a. Winner genome i3-g26-i9.
- The generator `system-anatomy.py` emits `prototype.html`, `system-anatomy.tex`
  and `label-ledger.txt` from one coordinate set. Do not hand-edit the TeX.
  Re-run the generator.
- The element library defines the palette and the weights once: blue-grey
  rings, dark cyan lines, amber blades, teal lift chain. Shape, weight and
  position carry the reading. Hue is a secondary channel.

## Bound values. The only numbers that print.

| Item | Value | Row |
|---|---|---|
| rings | six | NR-011 |
| TRPT lines | three | NR-011 |
| active rotor | one | NR-011 |
| topmost ring radius, ring R6 | 4.580 m | NR-011 |
| ground radius, ring R1 | 0.804 m | NR-011 |
| main-rotor bank angle | 7.088° | NR-017 |
| scale bar | 5 m | the drawn bar |
| blade span | 1.499 m | NR-043 |

No other number prints.

## What stays out

- The elevation angle prints as the glyph β only. No signed row carries the
  30° value.
- The 22.0 slot value never prints as a rotor angle. Standing rule.
- Every blade draws. Two of the three blades coincide in this projection.
  They overlap. Each blade still counts individually.
- The inset definitions are draft words. Track D holds the term picks. The
  label set flips with the picks at the author pass.

## Layout. Deployment side elevation.

- The machine is axisymmetric. A true side view beats a fake 3-D projection.
- The shaft sits at the operating elevation. Wind runs left to right. The
  ground station sits upwind. The kite stack trails downwind.
- The side view projects each ring to one segment. Ring R1 is the ground
  ring. Ring R6 carries the main rotor. The five segments between the rings
  are S1 to S5. Segments never read as spacer rings.
- Labels run ground to top. Thirteen labels. The cone ring (R5) label is
  the round-5 founder addition beyond the twelve-label brief cap. The
  inset defines the three load-bearing words: ring, line, rotor.
- The dashed box is the ground station. The dashed outline sits outside the
  primary render scope. The backline draws dashed. It is an altitude
  limiter, not a load path.

## Checks

- The generator asserts: six rings, fifteen line runs, three blades. The
  radii and the bank angle match NR-011 and NR-017. The blade span
  matches NR-043, the dimension clearances hold, and the cone-ring leader
  clearance holds.
- Compile chain: pdflatex, then pdftoppm at 300 dpi. Zero error lines and
  zero overfull boxes. See `checks.log`.
- The visual audit read the full plate and three crops (chain zone, topmost ring
  zone, base zone). No text touches a line. Every leader lands on its element.

## Regenerate

```bash
cd docs/reporting/figures/system-anatomy
/usr/bin/python3 system-anatomy.py
SOURCE_DATE_EPOCH=0 FORCE_SOURCE_DATE=1 pdflatex -interaction=nonstopmode system-anatomy.tex
pdftoppm -png -r 300 -singlefile system-anatomy.pdf system-anatomy
```

Two full runs stay byte-identical: generator outputs, PDF and PNG.

## Open items (round 1)

- Closed: the author label check (`38a15f1`) holds. Its two re-cuts landed
  in v2 and v3.
- Closed: the hub-name retirement (round-6, 2026-10-14). The R6 label
  reads "R6, the topmost ring". No value moves.
- The lifting-bridles relabel (2026-10-15): the chain label reads
  "lifting bridles (three)" (the v7 re-cut). The caption text re-keys
  at the author pass.
- Track D: the term picks. The plate carries the room forms for now.
- The β value waits for a signed row.
- Strip re-render and the planned genome strip and winner anatomy plates
  mount the element library.
