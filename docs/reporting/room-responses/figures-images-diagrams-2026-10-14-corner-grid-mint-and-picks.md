# Room response: the corner grid mints, and its picks record (2026-10-14, figures seat)

**Status** LANDED (mint and picks). **Seat** figures-images-diagrams. **Read at** `2f79aae`.

## The mint

The feedback routing sent comment 14 (id 13) to this seat: four machine
renders, one typical of each corner of the PC1-PC2 field. Row 23 mints
for it at §3.4: "The corner machines", slug `machine-corner-grid`. Map
delta v36 records the mint.

## The picks

The picks replicate the certified projection of the pca-landscape kit.
Every NR-044 anchor re-verifies first: the variance shares
22.434667 / 17.263044, the seed point, the winner point and both fits.

The rule: for each corner of the drawn [1,99] percentile window, the
feasible design of least distance in PC1-PC2 space. A diagonal-extreme
cross-check agrees on three picks of four.

| Corner | Design | PC1, PC2 | Objective (kg-eq) |
|---|---|---|---|
| low PC1 / low PC2 | `i1-g13-i1` | -1.454, -1.238 | 60.646 |
| low PC1 / high PC2 | `i1-g7-i7` | -2.088, 0.152 | 58.864 |
| high PC1 / low PC2 | `i2-g21-i4` | 1.132, -1.489 | 33.704 |
| high PC1 / high PC2 | `i3-g26-i8` | 1.680, 3.051 | 33.812 |

The two low-PC1 picks are many-line, two-rotor machines. The two
high-PC1 picks are one-rotor machines. The corner spread reads as the
shape of the search: the light feasible machines gather at high PC1.

## The value list, for sign

@science-validator: the plate would print, per machine, the identity
label and the search objective in kg-equivalent, beside the corner
name. Proposed display forms: the objectives at 3 dp (60.646, 58.864,
33.704, 33.812), from the telemetry fitness field (data commit
`dd3cc6a`, run `a76c5e9`). The strip sets the precedent at 3 dp. One
derived row carries the four picks, the rule and the display forms;
NR-051 is the next free number.

No value prints before that row signs.

## Next

The family-mode build takes the four genomes after the row signs. The
renders then carry the usual value list, ledger and reproducibility
passes.

## Checks

- `scratch/fig_cg_picks.py` and its log hold the anchors, the window,
  the rule and the picks.
- STE rc=0 on this receipt and the map.

---

figures-images-diagrams, 2026-10-14.
