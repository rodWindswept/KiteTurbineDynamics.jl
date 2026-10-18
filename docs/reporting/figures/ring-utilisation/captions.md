# Captions: ring utilisation

**Slug** `ring-utilisation`. **Status** GENERATE. **Date** 2026-10-08.
**Caption split** 2026-10-12. **Review fold** 2026-10-12.

Site: the report at §3.4, beside the census and envelope figures. Reading
order: census, envelope, ring utilisation, twist limit. The wording comes
from the author draft (v3) unchanged, except the capture slot, the
2026-10-12 caption split, the 2026-10-14 leads and the 2026-10-14
takeaway rewrite. Values cite
NR-021 and NR-015.

The split (2026-10-12): the plain and technical captions carry the
scientific text only. The provenance line carries the audit tokens: data
commit, capture, rows, script commit. It resolves to the
figure-provenance appendix (draft v0.15). The report prints the
scientific captions. The plate stamp and the appendix carry the
provenance.

## Plain caption

Every airborne ring passes its structural check with a wide margin.

## Technical caption (undergrad register, STE-clean form)

The topmost rotor ring R6 governs the structural check at FoS 15.033. All
other airborne rings hold much larger margins (NR-021).

Each bar shows one checked ring. The bar end reads the ring utilisation:
the beam-column interaction on the worst beam, the axial share N/N_crit
plus the bending share √(M_ip²+M_oop²)/M_el.

The rows run from R2 at the base to R6 at the top. Utilisation is demand
over capacity. The axis is logarithmic across six decades to the unit
value, so the margin of every ring reads at its own scale.

The dashed line is the fail boundary at the unit value, the physical
interaction limit at FoS 1. The campaign structural gate is stricter, at
FoS 2.5 or above (NR-015). The readout at the row end gives the ring FoS:
capacity over demand, the reciprocal of the interaction. The model tracks
torsion outside the interaction formula.

The figure covers every airborne ring. The check does not cover the ground
ring, which sits on ground support. The figure includes and marks the topmost
ring. The values come from the campaign winner at its final operating
point.

R5 reads far below the other rows. It carries net axial tension from the
cone flare (NR-060). The check scores compression only, so the axial share
enters the interaction as zero. The readout prints the true value, FoS
326,974 (NR-021).

For every other checked ring, the bending share sits below 0.05 per cent
of the ring utilisation.

## Provenance line

Data commit `dd3cc6a` · capture `pair-extract-2026-10-08-winner-ops` ·
rows NR-021 · script commit `1af63fc` · full record: the figure-provenance
appendix.

## Generation note

Resolved at GENERATE by the figures seat. The capture slot alone changed.
The bridge to the dashboard bar stays in the census prose and carries no
form here.

Split note (2026-10-12): the capture pair and the capture instant leave
the caption prose. The instant (s = 1724859, t = 49.99999483862295 s)
stays on the plate stamp and in NR-025. The text changed only. No render
moved.

Review fold (2026-10-12): the R5 display-floor sentences and the
capacity-over-demand line fold into the technical caption, from NR-021.
They answer the review's figure items 2 and 3 for this plate.

Counter-read (2026-10-12, `9ba8dae`): passes. All five FoS readouts
recompute as exact reciprocals, and the display-floor sentences read
exact from NR-021. The carried token folds: the top row now reads R6 in
the caption text, to match the plate label.

Caption lead (2026-10-14): the round-3 leads land in both tiers. The
plain tier opens with the governing ring. The technical tier adds the
topmost ring result (NR-021) and the campaign gate line (NR-015). Text only, no
render moves.

Render delta (2026-10-14): the 3.5 deltas land. The axis is logarithmic.
One bar shows each ring. The corrected interaction form (N/N_crit +
√(M_ip²+M_oop²)/M_el) reads in the legend and the caption.

The bending-share sentence replaces the display-floor sentences.
Render moved. No drawn value moves.

Takeaway (2026-10-14): the plain tier reads one takeaway sentence
(the round-5 caption dedupe). The tier no longer repeats the
technical claim. Text only, no render moves.

Retirement note (2026-10-14): the hub-name retirement (round-6
comment 1). The governs sentence takes the full name, and the
direction, marks, carried-token and lead lines take the top forms.
Text only. No render value moves. The plate re-renders at the round-6
script commit.
