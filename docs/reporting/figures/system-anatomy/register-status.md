# Register status: system anatomy

**Slug** `system-anatomy`. Status note for the figure rows.
**Date** 2026-10-12. Register fold and v4 re-cut 2026-10-13.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-011 | Winner geometry: six rings, three lines, one active rotor, r_hub 4.580 m, r_bot 0.804 m | Signed. Pre-checked in the 2026-10-12 register block |
| NR-017 | Main-rotor bank 7.088° at ring 6 | Signed |
| NR-043 | The winner blade span 1.499 m, drawn inner edge to tip (v4) | Signed (science-validator, `88277f6`) |

The plate draws no other row. The β glyph carries no value.

## Drawn precision

The radii print at three decimals, as registered (4.580 m and 0.804 m). The
bank angle prints at three decimals (7.088°). The counts print as words. No
rounding delta exists between the plate and the rows.

The span prints at three decimals (`1.499 m`), the drawn radii precision,
from NR-043. The dimension reads the built blade span, inner edge to tip.
It is not a ring radius, and not the tip offset alone.

## Reproduce

Commands:

    cd docs/reporting/figures/system-anatomy
    /usr/bin/python3 system-anatomy.py
    SOURCE_DATE_EPOCH=0 FORCE_SOURCE_DATE=1 pdflatex -interaction=nonstopmode system-anatomy.tex
    pdftoppm -png -r 300 -singlefile system-anatomy.pdf system-anatomy

Toolchain pin: pdflatex (TeX Live 2023/Debian), poppler pdftoppm. Two full
runs stay byte-identical (verified at v4). Hashes at v4:

    system-anatomy.tex  5bf748abc6fd385860f72ce0713cfb1c
    prototype.html      620481ca05882376cdea2c8026a22e6f
    label-ledger.txt    9f5e89acc24393d6e6481ce4780ee6e4
    system-anatomy.pdf  45a99a610b68c496209120ea6e6cd261
    system-anatomy.png  aae4915c2f32a2f0c6798e68d2d29e03

## Re-cuts

v2: the author label check (`38a15f1`) queued two fixes. The footer row list
takes the middle-dot form. The counts print as words. v3: the page geometry
takes a zero paragraph indent and a 0.25 cm margin. The plate now fits the
text block. The v3 compile reports zero error lines and zero overfull boxes.
No value binds to either re-cut.

v4 (2026-10-13): the blade-span dimension (NR-043) draws down-left of the
blade, with gapped extension lines and the label leader. The drawn source
line reads NR-011 · NR-017 · NR-043. Script commit `9cecee3`. No other
geometry moves.

## Pending

The Track D label picks (the knot name, the cyan-line name) ride a later
re-cut; the plate carries the room forms for now. The β value waits for a
signed row.

**Delta** v1 (2026-10-13): NR-043 signed (`88277f6`); the pending item
updates to the v4 re-cut; the note-9 caption forms land (`captions.md`).
**Delta** v2 (2026-10-13): the v4 re-cut lands. The blade-span dimension
draws (NR-043, the drawn form `1.499 m`), and the drawn source line
carries NR-011 · NR-017 · NR-043. Script commit `9cecee3`.
