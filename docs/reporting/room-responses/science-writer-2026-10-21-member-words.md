# Member words: beam and line (Rod, 2026-10-21)

The ruling from Rod sits in the terminology block of
`docs/agents/physics-topology.md` §2, beside the drawn-series ban and the
path bar:

> **Member words (Rod, 2026-10-21).** "Beam" names the rigid tube of a polygon
> ring. "Line" names a tensile rope segment between ring polygons. A ring is a
> polygon of nodes and tubular beams, so its tubes never take "line". Load sign
> does not change the member word: a tube in tension is still a beam, and a rope
> never carries compression.

The row then bounds the rule, because the first draft swept wider than its
evidence. Three sentences say what the rule does not reach. The boundary governs
the bare word inside the column. The named members of the lift chain sit outside the
ring polygons and keep their own names. A bare "line" holds where the nearest
named member supplies the referent. The word defining itself is exempt.

## The sweep, measured twice

**Before the repair, at `c9da885`.** 41 lines carrying `line` or `lines` in the
draft, and all ten `beam`, `tube` and `strut` lines, each read in context.

| class | count | sites |
|---|---|---|
| the rope segment | 37 | §2.1 definition, TRPT counts, lift line, cyan line, bridle runs, break gate |
| idiom, not a member | 2 | L138 "extends that line of work", L695 "bows off its design line" |
| drawn series | 1 | L897, the chart-sense site that takes `curve` |
| **wrong member** | **1** | **L369** |

L369 read "It is the ratio of what the line can carry to what the load
demands." The FoS it defines is the ring beam FoS: `min_airborne_fos` reads
`ring_fos`, the beam-column interaction, and the gates table rows it as the
safety floor against NR-015. The member is the beam, and the repair landed in
the Author seat at `0233f22`.

**After the repair, at `0233f22`.** 42 occurrences on 39 lines, and no residue.

| class | occurrences | sites |
|---|---|---|
| column ropes, bare or compound | 25 | L151 to L160, 215, 297, 347, 373, 392, 436, 456, 565, 616, 710, 735, 845, 875 to 876, 928, 1120, 1259 |
| named members of the lift chain | 8 | L674 to L675, 744 to 745, 752, 758, 846, plus "bridle line" at L1259 |
| referent-supplied bare | 3 | L759, and L1260 twice ("two lines", "the line tension") |
| the word defining itself | 4 | L102, L107, L144, L146 |
| idiom, not a member | 2 | L138, L695 |
| **total** | **42** | |

Three lines carry two occurrences each: L152, L1259 and L1260. The count is 42
occurrences, not 41. A case-sensitive grep misses the register row at L565,
which capitalises the word ("Line length").

No beam site names a rope. The gate idiom is already exact on both sides:
"break a line at the rope-break gate, not a beam FoS breach" (L616, L1120).

## Two hazards for the next re-cut

**L155, the shared count.** "The polygon count names the number of lines
(`n_lines`)" is true, and "each line meets the ring at one vertex" pins the
sense. But `n_lines` also sizes the polygon itself: `builders_util.jl:203`
labels a system "V10 3-gon 6 rings". A pentagon has five tubes and five ropes
at one count. A re-cut must not read the tubes of the pentagon as lines.

**L353, the bare beam.** "The team sizes the beam for a bounded generator load
step" holds. The evidence for NR-048 is `closed-form-beam-sizing.md`, with
`F_helix` about 1278 N per vertex on the hub segment. The boundary permits a
bare beam where the ring is the subject, and a sweep that demands a named ring
would break this sentence.

**L1085, outside the pair.** "The team deferred the full beam-on-supports blade
model (PRD 0006:147)" names a model of the blade, not a member of the TRPT. It
says beam and holds no `line` for the boundary to bite on. The sentence stays.

## Price

The ruling opens no new repair set on the printed page. One swap at L369, in
the Author seat, and one at L897. No caption moves, no drawn byte moves. Bless
stays free at 58. Seat stays one row, 58 to 59 on NR-069.
