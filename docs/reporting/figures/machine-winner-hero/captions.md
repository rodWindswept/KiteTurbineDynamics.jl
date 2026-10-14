# Captions: machine winner hero

**Slug** `machine-winner-hero`. **Status** GENERATE (first build 2026-10-14).
**Caption split** in force from the first build.

Site: the report at §3.3, the winner. Reading order: plan, side and
downwind. The wording comes from the figures seat, STE-gate checked.
Values cite NR-011, NR-017, NR-021, NR-022 and NR-043. The geometry
sources are the signed genome extract and the signed capture.

## Plain caption

The campaign winner, drawn three ways: down the shaft, from the side,
and along the wind. The machine stands at its settled operating point.
The six rings sit at their recorded stations. The shaft carries its
recorded wind-up. Each ring turns against the ring below it. All three
views share one scale, so the drawn size reads true.

## Technical caption (undergrad register, STE-clean form)

The island-3 winner at its final operating step. The machine reads six
rings, three lines and one active rotor (NR-011). The ring stations and
the per-segment twist come from the signed capture (NR-021, NR-022).

The main rotor carries three blades of span 1.499 m and a bank of 7.088
degrees (NR-043, NR-017).

The plan view looks along the shaft. It draws each ring as its node
polygon. The side view uses the shaft frame. Distance along the shaft
is vertical, and the operating elevation is not drawn. The downwind
view looks along the wind, so the shaft reads foreshortened.

The swept annulus draws as one truncated cone in the side view. It
draws as a ring band in the plan view and as a flattened band in the
downwind view. One scale holds across the three views. A 5 m scale bar
sits in the footer.

## Provenance line

Data commit `dd3cc6a` · genome extract `strip-extract-2026-10-09-best-so-far` (row i3-g26-i9) · capture `pair-extract-2026-10-08-winner-ops` · rows NR-011, NR-017, NR-021, NR-022, NR-043 · script commit `c438398` · full record: the figure-provenance appendix.

## Generation note

Resolved at GENERATE by the figures seat. The engine is CairoMakie, the
machine-renderer D7 steer. The drawn state is the recorded final
operating pose (SPEC delta D9, 2026-10-14). The built decode supplies
the section classes and the rotor spec. The capture supplies the ring
stations and the twist.

The plain built state reads an untwisted shaft
(probe `scratch/fig_hero_state_probe.jl`). No ODE runs.

The capture stores twist magnitudes only. The drawn winding sense takes
the declared spin-sense convention, recorded in the manifest.

The SVG emits glyph paths, not a text layer. The PDF chain takes the
-g garbage collect, then the date pin (2026-10-14).

The ground-station glyph is schematic and carries no number. The
lift-chain overlay and the section markers stay absent by declaration.
