# Register status: machine evolution strip

**Slug** `machine-evolution-strip`. Status note for the figure row.
**Date** 2026-10-09.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-005 | Island 3 best fitness. The winner panel identity, found gen 26 | Signed (science-validator, 2026-10-08) |
| NR-006 | The common seed. The first panel identity | Signed (science-validator, 2026-10-08) |
| NR-011 | Winner geometry. The winner panel check at GENERATE | Signed (science-validator, 2026-10-08) |

The figure draws no other row. The panel genomes come byte-exact from
the signed extract (`strip-extract-2026-10-09-best-so-far`).

Note on labels: the extract labels use the telemetry generation index
(gens 0 to 30, per the extract README). NR-006 prints the convergence.csv
index (gen 1) for the same seed. Flagged for the science-validator
counter-read.

Closed 2026-10-09 (science-validator): no mislabel. The convergence row i
is the running best over telemetry gens up to i, so the seed surfaces at
row 1 and the winner at row 26.

## Checks at GENERATE

The science-validator panel check recomputed the extract from the raw
telemetry (2026-10-09). The in-script checks cover all seven panels:
decode cross-check against the extract display columns, drawn counts,
and the NR-011 winner check. All pass. `checks.log` holds the full
record.

## Validator gates

F-COUNT and F-PARSE both PASS (science-validator, 2026-10-09), on
the delivered SVG that matches the manifest pin (sha256 `193e9f0d…`).

The count agrees panel-by-panel between the SVG, the manifest and a
fresh built-state probe. The parse re-measured every panel shape.
Maximum residual 0.0026 px over about 720 point checks, at a declared
0.05 px tolerance.

Two sub-pixel notes wait for the next deliberate re-render:

1. The axes are not exactly square. x reads 16.6267 px/m, y reads
   16.6013 px/m, +0.153 per cent. The largest effect is 0.15 px. Make
   the two scales equal at the next render.

2. The panel width rounds 211.67 to 212 px, which drives the offset.
   The manifest declares no tolerance field. Add one at the next
   render.

A re-render now would void the pass for a 0.15 px effect. The five
GENERATE outputs stay byte-identical to `9aeeed4` until then.

On the text layer, the PDF already carries selectable text, and
mutool extracts every label and both stamps. Print and PDF editions
need no change.

Only the SVG has no text layer. The figures seat proposes to close
the SVG text-layer item. A TikZ variant stays available if a web or
SVG edition must select text.

## Reproduce

Command:
`scripts/ktd-julia docs/reporting/figures/machine-evolution-strip/machine-evolution-strip.jl --script-commit 52ba1e7`

Toolchain pin: julia 1.12.5, CairoMakie 0.15.11, mutool 1.23.10. The
PDF carries a normalised creation date (1970-01-01). The pipeline
replaces the cairo wall-clock stamp. The manifest pins the extract and
the output hashes.

Self-check: two consecutive runs stay byte-identical across all five
outputs (png, svg, pdf, manifest, checks.log). Verified 2026-10-09,
committed set against a fresh run.
