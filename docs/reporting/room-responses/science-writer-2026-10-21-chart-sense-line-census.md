# Chart-sense "line": the census after the Aero counter-read

**Seat** science-writer. **Date** 2026-10-21. **Revision** v3.
**Trigger** the `@aero-validator` counter-read on `45db35a`, and the room
reads that followed at `c9da885`. v3 appends the seat landing, the coverage
line and the two-name split; the v2 text stands as the record at `c9da885`.

## What changed from v1

1. **The series word is `curve`, not `path`.** My v1 table gave `path` at
   four sites. Author ran that word against the draft before pasting it.
   The draft reads `path` or `paths` 32 times. The fidelity sense holds
   most of them: rapid 8, ODE 5, cold 3, then warm, default, scoring and
   "the paths". Section 2.5 owns the word. `curve` reads five times, and
   every hit is a plotted relation: the load curve at 303, the power
   curve at 489, the trade curve at 1223, 1228 and 1271. Fig found zero
   `curve` in any ledger. So `curve` costs nothing. `path` would cost a
   second sense of a defined term.
2. **Only six of the sites can reach the page.** Author read the two
   builders. `build_draft_docx.py:52` and `build_draft_pdf.py:195` both
   open `kit / "captions.md"`. `parse_caption_sections`
   (`build_draft_pdf.py:142-158`) keeps only the plain and the technical
   tier, and drops every record note. The draft holds eight seat markers
   and no marker for `power-curve` or `machine-power-trend`. I re-ran
   that check: both slugs read zero in the draft. So the printed set is
   five caption faults and one body sentence.
3. **My ledger sweep covered ten kits of thirteen.** `machine-corner-grid`,
   `machine-evolution-strip` and `machine-winner-hero` hash `checks.log`
   and carry no `label-ledger.txt`. `system-anatomy` has no SVG: its five
   outputs are `checks.log`, the ledger, `.pdf`, `.png` and `.tex`. The
   method line in v1 overstated the sweep. The three ledger-less SVGs carry
   no `<text>` node at all: their labels are glyph paths built from string
   literals in the generator. A sweep of those literals reads no series-sense
   `line`, `curve`, `trace` or `polyline`, and one member form, "TRPT lines",
   on all three. The anatomy `.tex` reads six hits, all the tension member
   ("line - one tensioned line of the TRPT", "cyan line", "lift line").

   The coverage line is ten surfaces by drawn text layer (nine SVG kits plus
   the anatomy `.tex`) and three by generator source. The blind spot is
   stated: an interpolated value is not a literal, so a generated label that
   builds its text at run time can still carry a word the sweep cannot read.

## The printed set: six repairs, no byte

| # | Site | Old | New |
|---|---|---|---|
| 1 | draft §3.4 L897 | Three lines trace the island best-so-far paths, one step per generation (NR-045). | Three curves trace the island best-so-far values, one step per generation (NR-045). |
| 2 | `pca-landscape/captions.md:28` | Three lines trace the island best-so-far paths, one step per generation. | Three curves trace the island best-so-far values, one step per generation. |
| 3 | `pca-atlas/captions.md:30` | thin lines trace the island journeys. | thin curves trace the island journeys. |
| 4 | `ring-utilisation/captions.md:37` | The red dashed line is the fail boundary at the unit value | The red dashed rule is the fail boundary at the unit value |
| 5 | `ring-utilisation/captions.md:38` | The purple line is the campaign structural gate. | The purple rule is the campaign structural gate. |
| 6 | `twist-limit/captions.md:39` | Its lines cannot reach the axis, so no over-twist limit exists. | Its tension lines cannot reach the axis, so no over-twist limit exists. |

Site 6 is not a chart-sense fault. My v1 census classed it structural,
and that reading holds. `src/trpt_twist_limit.jl:50`, Case B, `disc < 0`,
reads "The lines cannot reach the axis, so they cannot cross and there is
no stability limit." The caption translates that docstring. The referent
is the segment tether. The added word earns its place anyway: the caption
sits 300 lines from the §2.1 definition. Author counted the site as a
sixth fault. Aero reclassified it. Both are right about the fix. The
print count is five faults plus one disambiguation.

`captions.md` sits in no manifest output list. All six moves are text
only: no hash, no re-mint, no F-VALUE reopen.

## The queued set: forty-eight sites, no re-mint fires alone

The full queue reads 14 (v1) + 29 (Aero doc surfaces) + 5 (the trend
kit, found by Science Validator) = 48.

Series take `curve`. Gates take `rule` or `boundary`. The member takes
`tension lines`. The trend kit doc strings read "31 points on each step"
and "No step joins two eras."

Two drawn legends stay queued on seated kits. `pca-landscape` and
`pca-atlas` need a re-cut to reach zero. The string lives in the render
script, the ledger and the caption, so the SVG text layer moves and four
output hashes follow. Each waits for the next re-cut that kit needs for
another reason.

The atlas node is not a legend row. Its ledger line 27 is one four-clause
string, and three clauses must survive verbatim or the plate loses its
projection note:

> the same PC1-PC2 projection, coloured once per gene · PC1 → horizontal,
> PC2 ↑ vertical · star = common seed, diamond = winner · thin curves =
> island journeys

A re-cut changes the fourth clause only. The landscape legend carries one
clause and is the whole string:

> each curve: the island best-so-far value, one step per generation

`eval-timeline` is cheaper than v1 priced it. Fig read the ledger: line
45 reads `ruling-mode condition run (dashed)` and line 51 reads
`ω gnd (solid) · ω top (dashed)`. The kit writes bare `(solid)` and
`(dashed)` everywhere else, so `cold path (solid)` is house style. It is
a candidate, nine hashes, unseated, and it rides its next re-cut free.

## The rule

`docs/agents/physics-topology.md` §2 now carries it, next to the ban on
bare "the line" for a lift-chain member:

> **Drawn series (2026-10-21).** A drawn series is not a line. "Line"
> names the tension member only, in body prose, in a caption and in the
> drawn text layer. Each drawn series takes the word its plate already
> uses: step for a series drawn as steps, trace for a measured time series,
> curve for a plotted relation, and polyline for the drawn form of the
> power curve. A drawn gate reads rule.
>
> The drawn form decides, not the presence of an axis. A step series holds
> its value flat between generations, so a step series against labelled
> axes still reads step. A journey moves at every generation and its
> ordinate is not the value, so "one step per generation" on a journey
> names the movement and not a staircase: that journey reads curve.
>
> Curve also names a plotted relation whose ordinate is the value: the
> load, power, trade and objective curves. The discriminator separates a
> journey from a staircase, not a curve from a value plot.
>
> Step also names a recorded operating point, not a series: the final
> operating step, the same step, an archived step. Draft L919, register
> L1410 and the strip caption L22 read it that way, and the drawn
> winner-hero subtitles print it.
>
> The class has two printed names. Each plate keeps its own drawn word:
> trend and convergence print running-best, landscape and strip print
> best-so-far, and no sweep renames a plate. Prose takes the word of the
> plate it describes, so the draft prints both: L897 from the landscape and
> L949 from the trend. In the record, a series over generations reads
> running-best and a single generation's value reads best-so-far. NR-054's
> own cell prints both, correctly. running-best machine is neither a series
> nor a scalar: the trend plate owns it, and the plate rule above carries
> it.

> **"Path" is not a series word.** It names the fidelity routes at §2.5.
> The draft reads `path` or `paths` 32 times, and the fidelity sense
> holds most of them: rapid 8, ODE 5, cold 3, then warm, default, scoring
> and "the paths". A drawn series never takes it.

## Lookalikes that are not faults

- draft L928, "three lines and six rings (NR-011)": the TRPT count, gene
  `n_lines`, value 3.
- draft L138 "extends that line of work": an idiom.
- draft L695 "bows off its design line": a geometric line.
- `system-anatomy`, six caption hits and six drawn hits: the member, by
  design of the anatomy plate.
- `ring-utilisation/captions-draft.md`: record debt. No builder opens it.
- `twist-limit/captions-draft.md:19`, "the geometric line-crossing
  limit": the collapse detector's own name for the event.
- drawn `step`, and the winner-hero subtitles "at the final operating step"
  and "read at the same step", plus draft L919, register L1410 and the
  strip caption L22: a recorded operating point, not a series.
- `best-so-far` is drawn on the strip. Its title and its source stamp print
  it as glyph paths, so no ledger sweep sees it, and `running-best` prints
  nowhere in that kit.

## Two prices stand

The §6.1 cut stays free: it cuts §6.1 text, and the trend seat lands in
§3.5, so the cut's own cited set holds. The trend plate paid its one row
at `72dc65a`: the draft reads 58 to 59 on NR-069, and the assembled
document reads 59.

## Seat landing (2026-10-21, after `72dc65a`)

The trend plate seated at §3.5. The four caption words landed with the
seat, so the unseated-caption surface is now one file, not two. Every
builder opens `machine-power-trend/captions.md`, and its four chart-sense
sites read `step` and `rule` now. The file holds one `line`, the
"Provenance line" idiom, and a later sweep must leave it.

The trend entry read nine strings, not five: the five doc strings plus the
four caption sites in the unseated file. The four caption sites landed at
the seat. The five doc strings remain: SPEC S39, S41, S73 and S93, and
README S45. The seat moved no plate byte, so the kit's hashes and pins
stand at `e66dd94`.

`power-curve` still carries two chart-sense sites in an unseated
`captions.md`: L16 "the lower half of the line is a reading and not a gap"
and L60 "no line extends past the swept ends". Both take `polyline`, the
block's word and the kit's ledger line 32. L74 "Provenance line" is the
idiom and stays. That file fixes at its own seat.
