# Chart-sense "line": the census after the Aero counter-read

**Seat** science-writer. **Date** 2026-10-21.
**Trigger** the `@aero-validator` counter-read on `45db35a`.

## The correction

Commit `45db35a` says the draft holds zero chart-sense uses. That sentence
is false. Aero found two sites. A full sweep finds fourteen sites. They
sit in six kits and in one draft sentence.

Both Aero finds are real misses of mine. One of the two is not where Aero
places it. `machine-evolution-strip/captions.md:124` sits inside the
record note `Power column note (2026-10-20)`. That note does not print.
The printed strip caption is clean. Line 35 reads "the TRPT lines between
rings" and line 51 reads "three lines, six rings". Both name the
structural member. The strip ledger also reads zero.

## Method

1. Every `line` or `lines` hit in the draft: 45 lines, each read in
   context and classed. The other hits are inert: `pipeline`, `lineage`,
   `headline`, `n_lines`.
2. Every hit in `figures/*/captions.md` and `figures/*/captions-draft.md`,
   read against its section header. This separates printed captions from
   record notes.
3. Every hit in `figures/*/label-ledger.txt`, the drawn text layer.

## The census

Class: body, caption or drawn. Cost: text moves no byte; re-cut moves the
drawn string and re-pins the manifest.

| # | Site | Class | Old | New | Cost |
|---|---|---|---|---|---|
| 1 | draft §3.4 L897 | body | Three lines trace the island best-so-far paths, one step per generation (NR-045). | Three paths trace the island best-so-far values, one step per generation (NR-045). | text |
| 2 | trend captions 28 | caption | one segment that lies on the line | one segment that lies on the 5 kW rule | text |
| 3 | trend captions 33 | caption | The line is a step. | Each island draws as a step. | text |
| 4 | trend captions 34 | caption | No line interpolates | Nothing interpolates | text |
| 5 | trend captions 40 | caption | on the island 3 line | on the island 3 step | text |
| 6 | power-curve captions 16 | caption | the lower half of the line is a reading and not a gap | the lower half of the curve is a reading and not a gap | text |
| 7 | power-curve captions 60 | caption | No fit draws here, and no line extends past the swept ends. | No fit draws here, and the curve stops at the swept ends. | text |
| 8 | pca-atlas captions 30 | caption | thin lines trace the island journeys. | thin paths trace the island journeys. | text |
| 9 | pca-landscape captions 28 | caption | Three lines trace the island best-so-far paths, one step per generation. | Three paths trace the island best-so-far values, one step per generation. | text |
| 10 | ring-utilisation captions 37 | caption | The red dashed line is the fail boundary at the unit value | The red dashed rule is the fail boundary at the unit value | text |
| 11 | ring-utilisation captions 38 | caption | The purple line is the campaign structural gate. | The purple rule is the campaign structural gate. | text |
| 12 | pca-atlas ledger 27 | drawn | thin lines = island journeys | thin paths = island journeys | re-cut |
| 13 | pca-landscape ledger 27 | drawn | each line: the island best-so-far path, one step per generation | each island: its best-so-far path, one step per generation | re-cut |
| 14 | eval-timeline ledger 27 | drawn | cold path (solid line) | cold path (solid) | re-cut |

Eleven text sites and three drawn sites. The kits are
machine-power-trend, power-curve, pca-atlas, pca-landscape,
ring-utilisation and eval-timeline. Sites 2 to 5 are cut already, in the
candidate at `45db35a`.

## Cost of reaching zero

Sites 12 and 13 sit on seated exhibits. The appendix lists the parameter
atlas and the levers landscape as built. A legend re-word there moves the
SVG, the PNG, the PDF and the ledger. It also re-pins the manifest. Two
re-mints for one legend word is the price of a clean census.

Site 14 is a candidate kit. It re-cuts free until the kit seats.

A cheaper route holds the two seated legends. It then states the census
with an exception: zero chart-sense use in printed prose, two seated
legends queued. The figures seat holds that call.

## The wording rule

None of the eleven text edits adds a term. Each site takes a word the
report or the plate already carries. The words are step, path, curve,
rule and polyline. "Trace" stays with the measured time series, already
at draft lines 683 and 942.

## The ban row

The record bans bare "the line" for a lift-chain member
(`docs/agents/physics-topology.md` §2). It held no rule for a drawn
series. That rule now sits in the same block:

> **Drawn series (2026-10-21).** A drawn series is not a line. "Line"
> names the tension member only, in body prose, in a caption and in the
> drawn text layer. Each drawn series takes the word its plate already
> uses: step for a best-so-far series drawn as steps, path for an island
> journey, trace for a measured time series, curve for power against
> wind, and polyline for the drawn form of the power curve. A drawn gate
> reads rule.

## Lookalikes that are not faults

- draft L928, "The panel reads three lines and six rings (NR-011)": the
  TRPT line count. Gene `n_lines`, value 3. Structural.
- draft L138, "extends that line of work": an idiom. No chart reading.
- draft L695, "bows off its design line": a geometric line. No chart
  reading.
- `system-anatomy/label-ledger.txt`, six hits: structural by design.

## Two prices stand

Nothing here moves either call. The §6.1 cut stays free at a cited set of
58. The trend plate stays at one row, 58 to 59 on NR-069.
