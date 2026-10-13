# Register status: system anatomy

**Slug** `system-anatomy`. Status note for the figure rows.
**Date** 2026-10-12. Register fold 2026-10-13.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-011 | Winner geometry: six rings, three lines, one active rotor, r_hub 4.580 m, r_bot 0.804 m | Signed. Pre-checked in the 2026-10-12 register block |
| NR-017 | Main-rotor bank 7.088° at ring 6 | Signed |

The plate draws no other row. The β glyph carries no value.

NR-043 (the winner blade span) joins at the next build: the v4 re-cut
draws the span dimension and adds NR-043 to the drawn source line.

## Drawn precision

The radii print at three decimals, as registered (4.580 m and 0.804 m). The
bank angle prints at three decimals (7.088°). The counts print as words. No
rounding delta exists between the plate and the rows.

## Reproduce

Commands:

    cd docs/reporting/figures/system-anatomy
    /usr/bin/python3 system-anatomy.py
    SOURCE_DATE_EPOCH=0 FORCE_SOURCE_DATE=1 pdflatex -interaction=nonstopmode system-anatomy.tex
    pdftoppm -png -r 300 -singlefile system-anatomy.pdf system-anatomy

Toolchain pin: pdflatex (TeX Live 2023/Debian), poppler pdftoppm. Two full
runs stay byte-identical (verified at v3). Hashes at v3:

    system-anatomy.tex  32e74655418bb440fab039993f7acacb
    prototype.html      12d50b0c706c43c0be22e4e03e96cbd9
    label-ledger.txt    01b6f9b5543f2e9efd7d8f84b693fe39
    system-anatomy.pdf  0be2467fe569e2af91518d60f7d4c79d
    system-anatomy.png  04b6b7321b2f9fc78a003f2e5ea52aed

## Re-cuts (same day)

v2: the author label check (`38a15f1`) queued two fixes. The footer row list
takes the middle-dot form. The counts print as words. v3: the page geometry
takes a zero paragraph indent and a 0.25 cm margin. The plate now fits the
text block. The v3 compile reports zero error lines and zero overfull boxes.
No value binds to either re-cut.

## Pending

Founder note 13 (`c2e2aee`) asks the plate to carry the blade span. The
register form landed (NR-043, science-validator, `88277f6`): the winner
span is 1.4994019682084492 m (tip radius 5.629560432565964 minus inner
edge 4.130158464357515). The drawn form is `1.499 m` at three decimals —
the drawn radii precision. The dimension reads the built blade span,
inner edge to tip; it is not a ring radius and not the tip offset alone.
The v4 re-cut draws the dimension and adds NR-043 to the drawn source
line. No render moves until then.

**Delta** v1 (2026-10-13): NR-043 signed (`88277f6`); the pending item
updates to the v4 re-cut; the note-9 caption forms land (`captions.md`).
