# SPEC: lever-set. The lever set, two plates of two panels.

**Slug** `lever-set`

**Status** SPEC v1, R2 landing. Angle brackets ⟨⟩ mark binding slots.
This document carries no drawn value. The numbers register supplies the
citation discipline.

**Owner** @figures-images-diagrams. **Content check** @science-validator
and @aero-validator. **Reader-facing layer** @author.

**Contracts** the reporting framework (SPEC, GENERATE, CHECK, the rounds,
the dual captions). The numbers register (the firewall). The four checks
in `figure-generation-notes.md` (one era, one axis job, one source, the
tree pin). The item-5 extract at `6c51f5c`.

## 1. Why this exists

The founder asked why the prior campaigns' chart classes have not
entered this report. `prior-chart-classes.md` answers with a census and
names the seat. This kit draws the first four classes of that census, in
the two plates the author ruled (`eb7e64a`, `bf22566`).

The plates answer two questions the section 3.4 prose cannot carry: which
gene moves the objective, and where the failure and the penalty mass sit.

## 2. The slot ruling. Two plates, not four.

- **Plate A** — the main effect, then the surface it flattens: the
  sensitivity rank bar, then the response surface.
- **Plate B** — the failure population, then the penalty mass: the
  disqualification census, then the charge waterfall.

Four panels in one plate is arithmetically impossible: the A4 text block
is 174 mm, so a four-up gives each panel 85.5 mm and prints 7.5 pt type
at 3.32 pt, against a 6 pt floor. Two stacked panels keep the 6.85 in
slot and print at 6.76 pt. Four separate plates fit the ink but cost two
pages for two thin panels, and they push the figure count to 15 against
a budget of 14.4.

## 3. Inputs. The record contract.

Four committed tables from `lever-statistics-extract` at `6c51f5c`, over
the telemetry at data commit `dd3cc6a`, run `a76c5e9`:

| table | rows | register row |
|---|---|---|
| `extract-objective-vs-gene.csv` | 10 | NR-074 |
| `extract-objective-by-gene-bins.csv` | 46 | NR-077 |
| `extract-failure-rates-by-value.csv` | 13 | NR-075 |
| `extract-penalty-summary.csv` | 4 | NR-076 |

`extract-penalty-contributions.csv` enters the manifest as the source of
the summary, and no cell reads it directly.

No value draws that a signed row does not carry.

## 4. What each panel draws

**A1. The sensitivity rank bar.** Ten genes, ordered by the absolute
median shift. Bar length is the shift at 2 dp, and `rho` at 3 dp.
**The rho cannot take 2 dp:** `r_hub` 0.0736 and `density_profile`
0.0662 both print `0.07` there, and they rank 8 and 9. They sit two
rows apart and are indistinguishable on the page. At 3 dp the ten
separate with no collision, one character per row. The shift holds at
2 dp because the order is identical at 2 dp and 3 dp, ten of ten, and
no two shifts collide (nearest pair 1.3560 / 1.0705). Science-validator
signed the rounding on 2026-10-21. `<gene>` takes no precision at all
because it names the gene.
Every row prints its bin pair and both populations, as NR-074 signs.
**Two rows hold fewer than five designs at one end** — `rotor_count` at
506 and 2, `n_lines` at 319 and 1 — and they draw hatched and grey. The
caption takes no order from either.

The x axis states its job once: `median shift from the gene's lowest bin
to its highest, kg-equivalent`. A positive shift is heavier and worse.

**A2. The response surface.** One strip per gene, divided by that gene's
own bin count, so a seven-bin gene draws seven cells and a three-bin gene
draws three. Colour is the median fitness; each cell prints its count.
**The panel title names the population and the cell contents only.** The
longer form ran off the canvas and clipped its final glyph in the PDF
text layer, so the colour's meaning sits on the colourbar label,
`median fitness, kg-equivalent`, where it has room.
**Every bin under five designs prints no read**, hatched, with its count:
four bins qualify — `n_lines` 6, 8 and 9, and `rotor_count` 2. NR-077
signed the floor.

**B1. The disqualification census.** Ten bars: seven line counts and
three rotor counts. Each bar stacks ok, reject, clearance reject and
twist reject, and each prints its ok share. Population: **all 930
designs**. `n_active` is not drawn; the caption says the same shape, never
the same values.

**B2. The charge waterfall.** Three channels and a total line, over the
**508 ok designs**. Each bar prints its sum, its share and its dominance
count. The caption states over-power's 69.31 per cent against
utilisation's 12.36 kg-equivalent maximum and never ranks the channels by
their maximum.

## 5. The checks the script runs

Seventeen in-script checks, all reading the source CSV before a byte
draws: the ten rows and the two thin rows, the four dropped bins, the
three channel sums and the total at 4 dp, the three dominance counts, the
utilisation maximum above the over-power maximum, the 4.8 per cent at six
lines, the 110 clearance rejections summing across rotor counts, the zero
at one rotor, and the 508 and 930 population sums.

Two runs reproduce all seven outputs byte for byte.

## 6. What the caption must carry

- Plate A: `508 ok designs of 930`, the survivor conditioning of the rho,
  the kg-equivalent sign, and the two hatched rows taking no order.
- Plate A: two rows and four bins, never "the same four".
- Plate B: each panel names its own population — the census 930, the
  waterfall 508.
- Plate B: over-power 69.31 per cent, utilisation's 12.36 maximum, no
  ranking by maximum.

## 7. What this kit does not do

It opens no roster row: the four classes take row 8's four slots. It
signs nothing: the numbers seat signed NR-074 to NR-077 before the first
draw. It prints no value that a register row does not carry, and it moves
no draft byte.
