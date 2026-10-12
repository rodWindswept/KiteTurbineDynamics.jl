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
runs stay byte-identical. Hashes at this commit:

    system-anatomy.tex  7ad28b843566ce5eb3254f80515f97cb
    prototype.html      413259643024a6f32caa7bd81dd76fe4
    label-ledger.txt    3a386613d625f07e223c400d996226d2
    system-anatomy.pdf  533ae2136cc97e9ae706181f09ddd6d8
    system-anatomy.png  b743d6dd52dabf173f5546b1cbcfd633
