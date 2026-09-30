# TRPT reference library

This directory holds the checked source material for Tensile Rotary Power Transmission
(TRPT) modelling in this repo. Use it to check every physics claim against the thesis.
Do not check a claim against our own derivation alone.

## Source

O. Tulloch, PhD thesis, University of Strathclyde, 2021, 308 pages.

- PDF: `/home/rodbot/.hermes/attachments/Tulloch, PhD Thesis Final Submission.pdf`
- Text extract: `../tulloch-thesis-extract.txt`. It holds 309 pages. Split it on the
  form feed character. The page index then equals the PDF page number.

## Layout

| File | Content |
|---|---|
| `01-tulloch-relations.md` | The printed equations, with symbols and page anchors. |
| `02-reference-values.csv` | The printed numbers that our tests assert. |
| `03-repo-findings.md` | Repo claims that disagree with the source. Each gives file and line. |
| `04-lab-validation.txt` | Verbatim pages 184-185. The laboratory test. |
| `05-trpt-section-physics.txt` | Verbatim pages 221-229. Torque, delta_crit, force ratio. |
| `06-tether-drag.txt` | Verbatim pages 239-246. Tether drag and torque loss. |
| `07-design-application.txt` | Verbatim pages 250-253. The design map in use. |
| `08-trpt1-geometry.txt` | Verbatim pages 69-70. The TRPT-1 cone angle and the dimensioned figure. |
| `09-aerodyn-geometry-knobs.md` | Every AeroDyn geometry knob, its meaning, and which one carries our bank angle. Written 2026-09-30. |
| `figures/` | The printed figures, read from the PDF at 400 dpi. |

The `figures/` images have these contents:

| File | Figure | Printed page |
|---|---|---|
| `fig3.10-trpt1-cone-geometry-printed-p69.png` | The TRPT-1 geometry. Diameters and axial gaps. | 69 |
| `eq5.3-5.4-printed-p198.png` | Equations (5.3) and (5.4) | 198 |
| `fig5.25-torque-vs-twist-printed-p199.png` | Torque against twist. One section. | 199 |
| `fig5.27-fig5.28-dcrit-and-force-ratio-printed-p199.png` | delta_crit against phi. Force ratio against twist. | 199 |
| `fig5.29-force-ratio-vs-phi-printed-p200.png` | The stability map. Force ratio against phi. | 200 |

## Rules

1. No physics claim lands in `src/` without a row in `02-reference-values.csv`. The row
   gives the printed value and the source page.
2. Each quotation carries the printed page number. Add the extract page index when the
   page is hard to find.
3. A test never restates our formula. It compares our result with a printed value, or
   with a numeric maximum computed on a grid.
4. Mark an unverified claim OPEN. Do not delete it.
5. Do not fix a printed equation that the text layer garbles. Read the page image
   instead. The text layer of this PDF drops superscripts.

## Status of this edition

Written 2026-09-26. Eighteen reference values are recorded. Thirteen of them are checked
by `test/test_trpt_reference.jl`. Five stay OPEN: the two tether drag torque losses, and
the four settling times. Seven repo claims disagree with the source, in
`03-repo-findings.md`. Finding F5 was resolved on 2026-09-29 from Figure 3.10.

## How to repeat the figure capture

`pdftoppm` crops in pixels of its own render, so no second tool is needed.

```
PDF="Tulloch, PhD Thesis Final Submission.pdf"
# Figure 3.10, printed page 69 (PDF page 96), full drawing plus caption:
pdftoppm -f 96 -l 96 -r 400 -x 0 -y 430 -W 3309 -H 1180 -png "$PDF" fig310
# Figure 5.25, printed page 199 (PDF page 222), crop taken inside the page:
pdftoppm -f 222 -l 222 -r 400 -x 700 -y 500 -W 2400 -H 1400 -png "$PDF" fig525
```

A letter page gives 3308 x 4678 pixels at 400 dpi. Read the result before you save it: a
crop that loses the caption is not evidence.
