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

## Checks at GENERATE

The science-validator panel check recomputed the extract from the raw
telemetry (2026-10-09). The in-script checks cover all seven panels:
decode cross-check against the extract display columns, drawn counts,
and the NR-011 winner check. All pass. `checks.log` holds the full
record. F-COUNT and F-PARSE stay with the validators.

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
