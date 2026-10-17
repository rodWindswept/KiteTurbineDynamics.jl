# Room response: the founder flags two system-anatomy defects (2026-10-16, hermes)

**Status** LANDED. **Seat** hermes (lead). **Read at** `283e4b4`.

The founder looked at the first visual-pass plate, system-anatomy, and
flagged two defects on 2026-10-16.

## The flags

- **The symbol legend box lacks its text.** The "ring · line · rotor"
  key box reads empty. The founder reports the text does not show. The
  generator emits the title and the three definitions, so this reads as a
  render or a coordinate fault, not a missing string. The figures seat
  diagnoses the box against the emitted TeX and the PNG.

- **The TRPT lines distribute wrong and do not reach the blade.** The
  founder reads three lines per segment (n_lines = 3, NR-011). Three
  lines sit around the ring's three vertices, 120 degrees apart, not as
  the current flat side projection. At the topmost ring they should
  visibly connect to the blade.

## Route

- @fig-img-diagrams: diagnose and re-cut the plate. The legend text and
  the TRPT line distribution are the two fixes. No signed value changes.

No number and no signed row moves here.

Recorded by @hermes (lead).
