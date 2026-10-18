# T4 render pass at the figures seat: five plates

**Date** 2026-10-18. **Seat** figures-images-diagrams.
**Script commit** `d0e410d`. **Cover** T4-6, T4-7, T4-8, T4-9, and the
plate side of T3-6.

## What moved

| Item | Plate | Change |
|---|---|---|
| T4-7 | `pca-atlas` | Gene colour-bar ticks keep trailing zeros. Three significant figures print, as the prose claims. |
| T4-6 | `pca-landscape` | The PC1 panel line wraps to two rows, the second indented. Nothing clips at the page margin. |
| T4-8 | `pca-landscape`, `machine-corner-grid`, `machine-evolution-strip` | The drawn objective labels read `kg-equivalent`, not `kg`. |
| T4-9 | `machine-winner-hero` | Callouts 13 pt, legend 11.5 pt, scale label 11.5 pt. The R6 anchor moves left to stay inside the clip box. |
| T3-6 (plate) | `ring-utilisation` | The caption names net axial tension and the compression-only clip. Text only. |

No signed value moves. Every printed numeral keeps its source row.

## T4-6, the clip

The line read `wider spacing (x3), ground ring (x2)` on one row at 7.6 pt
in a 2.2 in panel. The closing parenthesis fell outside the axes. The
panel now draws one row per line with the continuation indented. The
wording is unchanged.

## T4-7, the precision

The old form used `:.3g`, which drops trailing zeros. The tick `1.5`
printed as two significant figures and `1` as one. The new `sig3()`
keeps the zeros. The tick labels are ledger strings, so
`label-ledger.txt` moves with them.

## T4-8, the unit

The plates read `kg` on the objective. The objective is a penalised
score in kg-equivalent, not a mass reading. The subtitles and the
per-machine labels now read `kg-equivalent`. The captions already read
kg-equivalent, so the drawn form now follows the text.

## T4-9, the type size

The plate renders 3744 px wide and prints at about 17 cm. At that
scale a 10.5 pt callout lands near 5 pt. The four callouts now read
13 pt and the legend 11.5 pt. The R6 label needed a new anchor: at
13 pt the old one ran past the axes clip box and lost its last
character. The anchor moves from 1.75 m to 0.80 m right of the ring end
and the leader shortens to match.

## T3-6, the caption line

The technical caption read:

> R5 reads far below the other rows. It carries bending alone. Its worst
> checked beam holds no axial share. The readout prints the true value,
> FoS 326,974 (NR-021).

It now reads:

> R5 reads far below the other rows. It carries net axial tension from
> the cone flare (NR-060). The check scores compression only, so the
> axial share enters the interaction as zero. The readout prints the
> true value, FoS 326,974 (NR-021).

NR-060 carries the force, -157.622 to -142.792 N tension on three
beams. The line points at the row and prints no force digit. The FoS
stays on NR-021. The plate bytes do not move.

The same sentence sits in the draft body and in the plate caption block
on p. 26. The author fold carries both.

## Reproducibility

Each plate rendered in place and twice into scratch outdirs, all at
`d0e410d`. Fifteen of fifteen outputs stay byte-identical across the
three locations. The table sits at `scratch/fig_t4_repro/table.md5`.

Pins, md5:

    pca-atlas.svg                 7ce307f7f34d94cc103f72eca8517508
    pca-landscape.svg             e923bf490c4a16f62950b5958b4dd856
    machine-corner-grid.svg       598b79acb93eeab6786585534e3467f4
    machine-evolution-strip.svg   21db9e1ed103a39984c8341e61cf3731
    machine-winner-hero.svg       e83bf02bd63a44ef9664369c9298d55b

The full set, PNG and PDF included, sits in each plate's
`register-status.md` and `manifest.json`.

## What stays open at this seat

- **T4-14.** The `system-anatomy` plate emits no SVG. It renders
  `.tex` to `.pdf` to `.png`, and the `prototype.html` carries an
  inline SVG at 884 x 695 px. The appendix hash block asks for an `svg`
  line. Two routes: emit a standalone `system-anatomy.svg`, or state
  the route as PDF and PNG only. The second half of T4-14 is a draft
  side fix: the hash header should say which exhibits carry a `ledger`
  and which carry a `checks` log.
- The appendix hash block and the plate embeds move at the author fold,
  not here. The five plate files are new bytes.
