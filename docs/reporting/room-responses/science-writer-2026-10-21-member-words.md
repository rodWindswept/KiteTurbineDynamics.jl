# Member words: beam and line (Rod, 2026-10-21)

Rod's ruling is in the terminology block of `docs/agents/physics-topology.md`
§2, beside the drawn-series ban and the path bar:

> **Member words (Rod, 2026-10-21).** "Beam" names the rigid tube of a polygon
> ring. "Line" names a tensile rope segment between ring polygons. A ring is a
> polygon of nodes and tubular beams, so its tubes never take "line". Load sign
> does not change the member word: a tube in tension is still a beam, and a rope
> never carries compression.

The row carries the two sites that already keep the split on the page: §2.3
reads "The beam load and the line load differ", and `ring-utilisation` reads
"the beam-column interaction on the worst beam" in its technical caption.

## The sweep: 41 line hits, 40 hold, one mislabel

I read all 41 `line` or `lines` hits in the draft and all ten `beam`, `tube`
and `strut` hits, each in context.

| class | count | sites |
|---|---|---|
| the rope segment | 37 | §2.1 definition, TRPT counts, lift line, cyan line, bridle runs, break gate |
| idiom, not a member | 2 | L138 "extends that line of work", L695 "bows off its design line" |
| drawn series | 1 | L897, the chart-sense site that takes `curve` |
| **wrong member** | **1** | **L369** |

L369 reads "It is the ratio of what the line can carry to what the load
demands." The FoS it defines is the ring beam FoS: `min_airborne_fos` reads
`ring_fos`, the beam-column interaction, and the gates table rows it as the
safety floor against NR-015. The member is the beam, so the sentence takes
Author's swap and lands in the same seat as L897.

No beam site names a rope. The gate idiom is already exact on both sides:
"break a line at the rope-break gate, not a beam FoS breach" (L616, L1120).

## Two hazards for the next re-cut

**L155, the shared count.** "The polygon count names the number of lines
(`n_lines`)" is true, and "each line meets the ring at one vertex" pins the
sense. But `n_lines` also sizes the polygon itself: `builders_util.jl:203`
labels a system "V10 3-gon 6 rings". A pentagon has five tubes and five ropes
at one count. A re-cut must not read the pentagon's tubes as lines.

**L1085, outside the pair.** "The team deferred the full beam-on-supports blade
model (PRD 0006:147)" names a model of the blade, not a member of the TRPT. I
read Rod's "e.g." as leaving the blade its own beam use, so the sentence stays.
Rod can correct that reading.

## Price

The ruling opens no new repair set on the printed page. One swap at L369, in
Author's seat. No caption moves, no drawn byte moves. Bless stays free at 58.
Seat stays one row, 58 to 59 on NR-069.
