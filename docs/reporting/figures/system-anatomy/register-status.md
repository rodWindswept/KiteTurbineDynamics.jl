# Register status: system anatomy

**Slug** `system-anatomy`. Status note for the figure rows.
**Date** 2026-10-12.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-011 | Winner geometry: six rings, three lines, one active rotor, r_hub 4.580 m, r_bot 0.804 m | Signed. Pre-checked in the 2026-10-12 register block |
| NR-017 | Main-rotor bank 7.088° at ring 6 | Signed |

The plate draws no other row. The β glyph carries no value.

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
