# Room response: draft v0.43, the round-5 wording set (2026-10-14, author)

**Status** LANDED. **Seat** author. **Read at** `e5541e9` (branch `bank-derate-cos2p65`, local == origin).

**Scope** This pass folds the feedback round 5 wording set, keyed on the two signed source reads. NR-049 signs the shaft transition cone, one fixed 22 degrees. NR-050 signs the blade-scale base, 0.75 and 0.113 of the sized rotor radius. The routing map (`d1e9bf1`) and the queue item 3 carry the set.

## What lands

Fold sites, comment by comment:

- Comment 1 (id 0), section 2.1. The blade-scale block takes the base clause. The base span reads 0.75 of the rotor radius. The base chord reads 0.113 of it. The power sizing sets the radius for the rotor at its local wind speed (NR-050).

- Comments 2 and 17 (ids 1 and 16), sections 2.1 and 3.5. The shaft transition cone holds one fixed angle, 22 degrees, by construction. It is not a search gene (NR-049). Section 3.5 carries the every-machine form and the campaign lead. A later campaign can vary it. The Tulloch parenthetical does not print.

- Comment 4 (id 3), section 2.5. The cold-path line lands beside the probes paragraph. The campaign scored every design on the cold path (NR-012).

- Comment 5 (id 4), section 3.1. The campaign-scale context lands. This campaign is the first screen after the physics-validation era. Larger and wider campaigns sit ahead.

- Comment 6 (id 5), section 3.3. The window-swing reading lands. The machine held a steady operating point through the measurement window.

- Comment 7 (id 6), section 3.3. The lifter rationale lands. A fixed kite would need its own single kite per weather band, and that kite would reach giant sizes. The staged-launch assumption lands as its own paragraph.

- Comment 8 (id 7), section 3.3. The blade-scale slots take their decode names. The main rotor reads `blade_scale_top`, 0.82. The second slot reads `blade_scale_bottom`, 0.20, and it stays inactive at a rotor count of one.

- Comment 9 (id 8), section 3.3. The second bank slot names `bank_bottom`. It reads 22 degrees at the top of its search box. The bound is 22 by construction (`scripts/compute_seeds.jl:204-206`). The two 22-degree facts stay apart, each named.

## Guards held

- The token diff asserts exact sets. Draft add: `43`, `0.75`, `0.113` and `22` twice. Draft remove: `42`, `1` and `2`. Tracker add: `43`.

- Sections 4 to the appendixes hold byte-identical against the base. The frozen levers block re-checks carried once (pass-log md5 `6d953ec1…`, raw file `7bbd964d…`).

- The seven seated markers hold. The number-gate brackets, the classified line, the rename, the objective block and the safety forms hold.

- The two 22-degree facts never merge. The bank sentence names `bank_bottom`. The cone sentence names the shaft transition cone.

## STE holds

- Draft: 6388 to 6545 words. Total 6 to 6. No category gains.

- Tracker: 2660 to 2714 words. Total 10 to 10. No category gains.

## Receipts

- Checks: `scratch/au_v043_round5_wording.py` and its log. 24 guards run closed. The gates pass on the first dry run.

- Candidate hashes: draft sha256 `b742dac0…`, tracker sha256 `f6a9f553…`.

- Citation gate: rc=0. 40 cited rows, all signed (50 signed rows total). NR-049 and NR-050 enter the cite set. No cite drops.

- The AU9 receipt normalises. The add list takes the end-power form `5.314` (commit `b7f09ed`).

- Review copy: `scratch/report-pdf-build/draft-live.docx` rebuilds on this push. Record draft `e5541e9`, seven seats resolved, 40 cited all signed, checker exit 0. Built 2026-10-14T20:08:39Z. Live md5 `3374a638…`, byte-identical to the archived build `draft-e5541e9-20261014-200839.docx`. The delta from the copy the founder holds (v0.42): the round-5 wording set. The changed sections read 2.1, 2.5, 3.1, 3.3 and 3.5.

## Notes

- One writer, one pass, per the queue item 3. The era pack (queue item 5) stays held for its slot with @science-writer.

- The cone statement folds at both signed sites. The lead line lands once, at section 3.5.

- The cold-path line sits beside the probes paragraph, per the routing. A one-line move to the names-map paragraph stands if the counter-read prefers.

- The version pin takes v0.43. The pending appendix refresh at the figures seat bumps from this base.

## Handoffs

- @aero-validator: the counter-read keys on this push. The two 22-degree sites and the slot names read by name at that fold.

- @science-writer: sweep 29 keys on this push. The declared sets sit above. One glossary note: the physics-validation era phrase enters section 3.1.

- @science-validator: the two clauses fold at the signed forms. One glance for the record.

- @fig-img-diagrams: the version pin reads v0.43. The pending anatomy re-cut and appendix refresh bump from this base.

- @hermes: queue item 3 closes at this seat. The kMppt plain pass and the partner-gated tails stay next.

- @user: the round-5 comments now read in the draft. Every one folded.

author, 2026-10-14.
