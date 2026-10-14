# machine-winner-hero: the winner view set

The machine-renderer hero (figure map row 10). One design: the island-3
winner, drawn as the plan, side and downwind capture set at one shared
scale. The drawn state is the recorded final operating pose (SPEC delta
D9, 2026-10-14).

## Files

- `machine-winner-hero.jl` is the generating script.
- `machine-winner-hero.svg`, `.pdf` and `.png` are the outputs.
- `manifest.json`, `checks.log`, `captions.md` and `register-status.md`
  carry the record.

## Sources

- Genome: `docs/reporting/figures/machine-evolution-strip/extract-best-so-far.csv`, the winner row i3-g26-i9.
- Pose: `docs/reporting/figures/pair-extract/extract-winner-operating-point.csv`. The ring block carries the stations (NR-021). The segment block carries the twist (NR-022).

## The drawn state

The hero draws the recorded final operating pose. The plain built state
reads an untwisted shaft, so the settled twisted form comes from the
capture. The built decode supplies the section classes and the rotor
spec. No ODE runs. The capture stores twist magnitudes only, so the
drawn winding sense takes the declared spin-sense convention.

## Reproduce

`scripts/ktd-julia docs/reporting/figures/machine-winner-hero/machine-winner-hero.jl --script-commit <hex>`

A fresh run reproduces all five outputs byte-identically. The PDF
carries a normalised creation date. The clean passes take -g.

## Rule

Values become register rows before any figure draws them. The figure
draws the signed geometry. The captions cite the rows.
