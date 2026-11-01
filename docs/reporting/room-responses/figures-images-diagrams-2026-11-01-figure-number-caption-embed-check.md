# Room response: the figure-number caption and embed check (2026-11-01, figures seat)

**Status** CHECKED. One seated caption prints a stale number. Three draft lines print the same stale number. **Seat** figures-images-diagrams. **Read at** `ff16a22`.

## The builder

`scripts/build_draft_pdf.py` line 191 still prints `Figure (roster row {row}) · {slug}`.
The last builder commit reads `1a95645`.
The builder holds no figure counter.
The map seat owns the counter change.

## The seat order

The draft holds ten seat markers.
They run in this order:

- row 2 at line 218
- row 10 at line 648
- row 6 at line 825
- row 7 at line 827
- row 20 at line 862

- row 21 at line 864
- row 23 at line 866
- row 9 at line 914
- row 30 at line 946
- row 31 at line 1339

That order matches the author proposal for Figure 1 to Figure 10.

## The embeds

Ten of ten slugs resolve to a kit.
Each kit holds its plate file, `manifest.json` and `captions.md`.
The builder reads `{slug}.svg` first, then `{slug}.png`.

The image set reads:

- `system-anatomy.png`
- `machine-winner-hero.svg`
- `ring-utilisation.svg`
- `twist-limit.svg`
- `pca-landscape.svg`

- `pca-atlas.svg`
- `machine-corner-grid.svg`
- `machine-evolution-strip.svg`
- `machine-power-trend.svg`
- `instrument-gallery.png`

No kit fails the read.

## The caption that needs a number

`docs/reporting/figures/instrument-gallery/captions.md` line 5 reads "Section 9, Figure 12."
The row 31 plate takes Figure 10 in the proposal.
Line 21 of the same file reads "the Figure 12 admission paragraph".
Both lines need 12 changed to 10.
The builder emits the label, so the other nine seated captions print no number and need none.

## The unseated caption

`docs/reporting/figures/capability-sheet/captions.md` line 5 reads "Site: section 7, as Figure 10".
The capability sheet sits outside the ten seated plates.
Its number now collides with the new Figure 10.
The author seat rules the number or retires it.

## The draft lines (author seat)

Three draft lines print Figure 12 and all three name the instrument gallery:

- line 1336: "Figure 12 names no dataset extract."
- line 1400: "**Figure 12 admission.**"
- line 1402: "Figure 12 prints only the frames that pass four conditions."

They take Figure 10 with the caption fix.

## Notes

`figure-map.md` row 31 holds an internal phrase about the Figure 11 strip.
The strip takes Figure 11 if it seats later.
This check reruns when the map seat lands the counter.
No plate byte moves and no register row moves.

---

figures-images-diagrams, 2026-11-01.
