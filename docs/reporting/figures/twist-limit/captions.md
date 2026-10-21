# Captions: twist limit

**Slug** `twist-limit`. **Status** GENERATE. **Date** 2026-10-08.
**Caption split** 2026-10-12. **Review carry** 2026-10-12.

Site: the report at §3.4, beside the census and envelope figures. Reading
order: census, envelope, ring utilisation, twist limit. The wording comes
from the author draft (v4) unchanged, except the capture slot, the
2026-10-12 caption split, the 2026-10-14 leads, the 2026-10-14
takeaway rewrite and the 2026-10-18 re-cut. Values cite
NR-022, NR-023, NR-040, NR-052 and NR-053.

The split (2026-10-12): the plain and technical captions carry the
scientific text only. The provenance line carries the audit tokens: data
commit, capture, rows, script commit. It resolves to the
figure-provenance appendix (draft v0.15). The report prints the
scientific captions. The plate stamp and the appendix carry the
provenance.

## Plain caption

The shaft passes its twist and torque checks along its whole length.

## Technical caption (undergrad register, STE-clean form)

All five TRPT segments remain inside their over-twist limits at the
winner's final operating point. S1 carries the least segment torque
margin, 2.03 (NR-040).

Panel A draws the transmitted twist of each segment as a magnitude,
against its limits: the over-twist limit δcrit and the realisability
floor. δcrit comes from the committed authority `trpt_twist_limit`. The
floor follows sin Δα ≤ 1/1.05 and holds the geometry only to 72.25°
(NR-053).

The crossing limit δα* is a per-segment collapse-detector limit. It is
not the over-twist limit.

A no limit segment carries no torsional ceiling. Its tension lines cannot
reach the axis, so no over-twist limit exists. The figure draws no ratio
for such a segment. Tether break strain and ring compression carry its
limit instead.

Panel B pairs segment torque against torsional capacity at the final
operating point of the campaign winner. Each segment draws the torsional
FoS gate at capacity divided by 1.5 (NR-052). Pair a capacity only with
the load of the same state.

## Provenance line

Data commit `dd3cc6a` · capture `pair-extract-2026-10-08-winner-ops` ·
rows NR-022, NR-023, NR-040, NR-052, NR-053 · script commit `e3d664c` · full
record: the figure-provenance appendix.

## Generation note

Resolved at GENERATE by the figures seat. The capture slot alone changed.

The ruled capture carries Case A segments only. The no-limit class does
not occur at the campaign winner. The crossing-limit bridge stays in the
census prose and carries no form here.

Split note (2026-10-12): the capture pair and the capture instant leave
the caption prose. The instant (s = 1724859, t = 49.99999483862295 s)
stays on the plate stamp and in NR-025. The text changed only. No render
moved.

Review carry (2026-10-12): the 2026-08-13 line (22,425° against its 42.6°
limit, off scale) leaves the plate notes for the failure-ledger appendix
at the plate's next render pass.

Counter-read (2026-10-12, `9ba8dae`): the carry-note reads accurate, and
the caption claims trace. Tracked before sign-off: register rows for the
drawn mechanism values (72.25°. The 42.6° limit and the 22,425° overshoot
retire with the v2 render). The floor row rides with the ledger pass.
The floor and binding-limit treatment routes through work item 1.3 (the
row-7 gate). It executed at the 3.5 render deltas.

Caption lead (2026-10-14): the round-3 leads land in both tiers. The
technical tier adds the least segment torque margin (NR-040). Text
only, no render moves.

Render delta (2026-10-14): the 3.5 deltas land. The 2026-08-13 and
read-cap lines leave the plate notes for the failure ledger. The δcrit
labels re-space clear of the tick column.

The title, subtitle and panel-A label measure against the binding limit,
the realisability floor. Render moved. No drawn value moves.

Takeaway (2026-10-14): the plain tier reads one takeaway sentence
(the round-5 caption dedupe). The tier no longer repeats the
technical claim. Text only, no render moves.

Retirement note (2026-10-14): the hub-name retirement (round-6
comment 1). The top ring label reads "R6 (top)" and the subtitle
reads "ground to top". Text only. No value moves. The plate
re-renders at the round-6 script commit.

Feedbackbot re-cut (2026-10-18): the four method notes leave the canvas
for the technical tier, panel B draws the FoS 1.5 gate (NR-052), and the
plate shrinks to a single legend row in the foot. The caption text and
the render move together at the new script commit.
