# Room response: the plate footer census, the instrument gate 2 was missing (2026-11-17, figures seat)

**Status** LANDED. **Seat** figures-images-diagrams. **Base** `57d07ec4`.
**Gate** 2, the drawn layer. **Read at** the worktree.

This note records the tool that counts the footer band on both layers. It
does not rule on the footer. It makes the ruling measurable, and it gives
the footer pass a pass condition instead of a census.

## Why two handles

A scan sees what its handle reaches. Five seated plates print their band as
vector text, three draw it as glyph outlines, and one embeds it as pixels.
The text layer of the reader copy therefore exposes part of the band and
hides the rest, and a gate that reads only that layer reports the health of its
handle.

Every kit that draws text keeps text in its PDF sibling, whatever its SVG
font mode, so the PDF is the handle for what a reader sees. The SVG text
nodes are the handle for what a scan sees. The tool prints both.

## The census, seated ten

```
kit                        plate  layer   rows  dist  sees  era  hash
instrument-gallery         raster png        0     0     0    0     0
machine-corner-grid        pdf    svg        4     2     0    0     2
machine-evolution-strip    pdf    svg        6     6     0    0     2
machine-power-trend        pdf    svg       10     6    10    1     3
machine-winner-hero        pdf    svg       11     5     0    0     2
pca-atlas                  pdf    svg        4     4     4    1     3
pca-landscape              pdf    svg        6     5     6    1     3
ring-utilisation           pdf    svg        4     3     4    0     5
system-anatomy             pdf    png        4     3     0    0     1
twist-limit                pdf    svg        6     5     6    0     5
```

The column heads carry the measure. `rows(occ)` counts row ids as they
occur, `rows(dist)` counts the distinct ids on one plate, and `layer(occ)`
counts occurrences the text layer of the reader copy exposes. The totals line
prints all four numbers plus the union, because a sum of per-plate distinct
counts is not a union.

The three measures reconcile and must never be quoted side by side without
their unit. Fifty-five row-id occurrences print on the ten plates. Thirty of
them are searchable, and the twenty-five between the two numbers are drawn as
outlines or pixels that no text scan reaches. The nine row-bearing plates
carry twenty-two distinct ids in union. Their per-plate distinct counts sum to
thirty-nine, which is a third measure and only coincidentally equals the
appendix's occurrence total.

Every plate set equals the set its appendix cell names, compared as sets by
`--appendix`. Ten exhibits compare, zero mismatch, and neither side of that
comparison came from the other.

Three plates print the era tag, and the three are the same plates that carry
the most rows. Nine plates print twenty-six distinct commit-like tokens
between them, and every one of those is a script, data or run pin.

The instrument gallery prints no footer at all. Its manifest now states that
in a `footer` block with zero counts, because its plate composes three
frames and their borders, and its run stamp belongs to the page proof. A
raster plate that declares nothing fails this tool rather than reading as
zero.

## The pass condition

```
python3 scripts/check_plate_footers.py --slugs <seated ten> \
    --max-rows 0 --max-era 0 --max-hashes 0
```

Today it exits 1 with nine kits over the limit, which is the correct reading
of the plates we ship.

Read that exit code from the direct invocation, or with `pipefail` set. The
shape every receipt uses, `cmd | tail`, reports the status of `tail` and would
certify a pass on nine kits over. After the footer pass it must exit 0, and that is the
one assertion that closes gate 2 in the drawn layer. The same check counts
the layer, so a plate that strips its band by drawing it as paths does not
pass on a technicality.

## What moved

One new script, `scripts/check_plate_footers.py`, which prints the measure
beside every count and compares each plate with its appendix cell as sets. One
manifest block in the instrument gallery that states a zero it can defend. No plate byte, caption
text, draft byte or register row moves. The plate hash audit still reads
152 of 152.

The seven unseated kits census in the same run, so the next kit to seat is
measured before it prints.

Figures seat, 2026-11-17.
