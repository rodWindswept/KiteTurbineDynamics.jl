# Register status: machine winner hero

**Slug** `machine-winner-hero`. Status note for the figure row.
**Date** 2026-10-14. **Script commit** `c438398`. First GENERATE `c438398`.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-011 | Winner geometry: six rings, three lines, one rotor, hub and ground radii | Signed (science-validator, 2026-10-08) |
| NR-017 | Main-rotor bank, 7.088 deg at ring 6 | Signed (science-validator, 2026-10-08) |
| NR-021 | Ring stations at the winner operating point | Signed (aero-validator, 2026-10-08) |
| NR-022 | Per-segment twist at the winner operating point | Signed (aero-validator, 2026-10-08) |
| NR-043 | Winner blade span 1.4994019682084492 m (quote 1.499) | Signed (science-validator, 2026-10-13) |

The figure draws no other row. The radii, the stations and the twist
come byte-exact from the signed capture. The rotor spec and the section
classes come from the built decode.

## Drawn values and precision

| Quantity | Drawn form | Source |
|---|---|---|
| Ring stations R1 to R6 | 0, 2.3182841987165674, 4.636939712683201, 6.9559610374822345, 9.27534680414777, 18.600867750952748 m | capture ring block. The NR-021 register note reads the same station order |
| Segment twist S1 to S5 | 33.94561934829036, 33.811870056223555, 33.67952027817454, 33.54707806507812, 22.821871326820364 deg | capture segment block (NR-022) |
| Radii R1 to R5, R6 | 0.8036829846088207 m and 4.5799790548200496 m | capture segment block. NR-011 display 0.804 m and 4.580 m |
| Blade span | 1.4994019682084492 m | NR-043 |
| Bank | 7.0881314603 deg | NR-017 display 7.088 |
| Elevation (downwind view) | 28.64 deg | the flown-basis edge note in the NR-032 block |
| Scale bar | 5 m | production value, manifest |

The drawn numerals: the blade span 1.499 m (the NR-043 quote form), the
scale bar 5 m, the register cites and the stamps. No other value numeral
prints.

## The state note (SPEC delta D9)

The hero draws the recorded final operating pose: the built geometry
with the captured wind-up. The probe `scratch/fig_hero_state_probe.jl`
reads every ring azimuth state at 0.000 deg in the plain built state,
so the settled twisted form comes from the capture. The capture stores
twist magnitudes only. The drawn winding sense takes the declared
spin-sense convention: the azimuths accumulate the recorded magnitudes
from R1 upward. The manifest records it.

## Checks at GENERATE

All in-script checks pass at `c438398`: 15 state checks, the layout
viewports, the px-per-m squareness at 0.0000 ppm on all three panels,
and the PDF chain. The `checks.log` holds the full record. Three fresh
runs stay byte-identical across all five outputs. That walk caught the
orphan-length wobble in the PDF chain, and the mutool passes now take
-g.

## Validator gates

F-COUNT, F-PARSE and F-VALUE walk at the seats. The aero-validator
counter-read and the visual pass by Rod follow.

## Reproduce

Command:
`scripts/ktd-julia docs/reporting/figures/machine-winner-hero/machine-winner-hero.jl --script-commit c438398`

Toolchain pin: julia 1.12.5, CairoMakie 0.15.11, mutool 1.23.10. The
PDF carries a normalised creation date (1970-01-01). The clean passes
take -g, so the cairo orphan length objects leave the file. The manifest
pins both extracts and the output hashes.

Self-check: three consecutive runs stay byte-identical across all five
outputs. Verified 2026-10-14 at `c438398`.
