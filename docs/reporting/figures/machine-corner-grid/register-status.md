# Register status: machine-corner-grid

**Slug** `machine-corner-grid`. Status note for the figure row.
**Date** 2026-10-15. **Script commit** `a4b4057`. First GENERATE `a4b4057`.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-044 | The certified PCA projection: shares, window and rule basis | Signed (science-validator, `2ad023c`) |
| NR-051 | The corner-grid picks: four machines, one per [1,99] window corner; tags, pc values and objectives at 3 dp | Signed (science-validator, `cb862df`) |

The figure draws no other row. The geometry comes from the extract
rows byte-exact (`corner-grid-extract-2026-10-15-picks`), and the
extract tokens copy the telemetry records. The decode applies the
recorded campaign knobs (manifest). The composition note (many-line
two-rotor / one-rotor) travels with NR-051.

## Drawn values and precision

| Quantity | Drawn form | Source |
|---|---|---|
| Corner names | `low PC1 / low PC2`, `low PC1 / high PC2`, `high PC1 / low PC2`, `high PC1 / high PC2` | NR-051 table |
| Identity tags | `i1-g13-i1`, `i1-g7-i7`, `i2-g21-i4`, `i3-g26-i8` | NR-051 |
| Objectives | `60.646`, `58.864`, `33.704`, `33.812` kg-equivalent at 3 dp | NR-051 display forms |
| Scale bar | 5 m | production value, manifest |

The drawn numerals: the four objectives, the scale bar and the stamps.
No other value numeral prints. The window and pixel values live in the
manifest.

## Checks at GENERATE

All in-script checks pass at `a4b4057`: the per-panel decode checks
(n_lines, rings, n_active, r_hub, r_bot, objective) read true, the
corner order reads the NR-051 signed order, and the objective labels
check at all four panels. The `checks.log` holds the full record. The
window: x ±6.211 m, y -0.759 to 19.742 m, m_per_px 0.060299, square
axes at 0.0000 ppm.

F-REPRO: the kit rendered in place and twice into scratch outdirs, all
at `a4b4057`. All five outputs read byte-identical across the three
locations (table `scratch/fig_cg_repro.md5`).

## Reproduce

Command:
`scripts/ktd-julia docs/reporting/figures/machine-corner-grid/machine-corner-grid.jl --script-commit a4b4057`

Toolchain pin: julia 1.12.5, CairoMakie 0.15.11, mutool 1.23.10. The
PDF carries a normalised creation date (1970-01-01). The clean passes
take -dg and -zg. The manifest pins the extract and the output hashes.

Self-check: three locations stay byte-identical across all five
outputs. Verified 2026-10-15 at `a4b4057`.

**Delta** v1 (2026-10-15): created with the kit landing (family mode,
corner variant; SPEC delta D10). No drawn value moves after this cut.

**Delta** v2 (2026-10-15): the counter-reads close clean (`857f2c1`,
153 checks). The picks and the objectives recompute from the raw draw
columns. The extract binds at all 128 fields. The drawn text reads
clean. Two fresh runs stay byte-identical. The NR-051 cite takes the
sign commit `cb862df`. No drawn value moves.

**Delta** v3 (2026-10-15): the visual pass by Rod reads clean. The fold
lands (draft v0.51): the seat marker joins the field pair at §3.4, and
the figure-provenance appendix takes the eighth exhibit row and its
hashes. No drawn value moves.

**Delta** v4 (2026-10-15): the register read closes clean (`7e68f0e`,
107 checks): the drawn set reads NR-051 to the signed digits, and the
seat marker cites NR-044 and NR-051 only. The v0.51 copy counter-read
closes clean (`ed95cf1`, 304 checks). No drawn value moves.

**Delta** v5 (2026-10-18): T4-8. The drawn objective label read `kg`. The
subtitle and the label now read `kg-equivalent`, the unit the prose uses
for the penalised score. The digits are unchanged and still cite NR-051.
Three runs stay byte-identical across all five outputs. Script commit
`d0e410d`. No drawn value moves.
