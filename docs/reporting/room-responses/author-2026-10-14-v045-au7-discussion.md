# Room response: draft v0.45, AU7 folds the era map and the failure-ledger table (2026-10-14, author)

**Status** LANDED. **Seat** author. **Read at** `34e3f81` (branch `bank-derate-cos2p65`). The origin readback rides this pass.

**Scope** This pass runs AU7, the discussion folds. Two verified supplies land, one pass. The era map (SW3b, sweep 16) lands at section 3.3. The failure-ledger table (SW3a, sweep 16) lands at section 4.2. SV7 audited both. The fold sims stand in `scratch/sw_sw3b_erasim.md` and `scratch/sw_ws3a_ledgersim.md`.

## What lands

- Section 3.3, beside the era note. The short pointer block lands. The bank derate is a calculated depowering of the main-rotor disc (NR-019, NR-020). The window basis sits at section 2.2.2, and the gate set at section 2.4.

- Section 3.3, continued. The four-row era table lands, byte-frozen from the supply (md5 `d268d253b37d5388f8db36554d7ba3fa`).

- Section 4.2. The six-entry failure-ledger table lands, byte-frozen from the supply (md5 `f2e9df2399d89224300e11ea5038c7e8`). The verified sim shape holds: the lead line, the table, and the narrative after it, entry for entry.

## Guards held

- The token diff asserts exact sets. Draft add: `45`, `18.8`, `2.2`, `2`, `2.4`, `1.94` and `5.18`. Draft remove: `44`. Tracker add: `45`, `3.3` and `4.2`.

- The two tables carry the accepted table class. The long_paragraph count gains two flags, one per table, per the sweep-16 sims. Every other category holds, and both files exit rc=0.

- The frozen levers block re-checks carried once (pass-log md5 `6d953ec1…`). The methods region, the levers-to-ledger region and the boundaries-to-end region hold byte-identical.

- The seven seated markers hold. The number-gate brackets, the classified line, the rename, the objective block and the safety forms hold. The era note, the ledger lead and the standing gate line hold.

## STE holds

- Draft: 6545 to 6876 words. Total 6 to 8: the two accepted table flags alone.

- Tracker: 2760 to 2817 words. Total 11 to 11. No category gains.

## Receipts

- Checks: `scratch/au_v045_au7_discussion.py` and its log. 21 guards run closed. Both supply tables assert byte-identical to their fold sims.

- Candidate hashes: draft sha256 `2763f6c2ace5237277d616dd904bc2655cbbe65e279fdf20bf33b69ea5580b24`, tracker sha256 `6b9a401789e4cbe98999ef1a50088e9cfa041089fde42c4c670e13146daa49e3`.

- Citation gate: rc=0. 42 cited rows, all signed (50 signed rows total). NR-019 and NR-020 enter the cite set. No cite drops.

- Review copy: `scratch/report-pdf-build/draft-live.docx` rebuilds on this push. Record draft `34e3f81`, seven seats resolved, 42 cited all signed, checker exit 0. Built 2026-10-14T20:41:06Z. Live md5 `c88d1901…`, byte-identical to the archived build `draft-34e3f81-20261014-204106.docx`. The delta from the copy the founder holds (v0.43): the era map and the failure-ledger table. The sections read 3.3 and 4.2.

## Notes

- One pass, both AU7 folds, per the plan. The era map keeps the routing form: the table plus the short pointer block.

- The pointer block points only. It prints no new value. It mirrors the calculated-depowering form of the abstract.

- The spelled forms of the supply stand byte-frozen in both tables. The ledger table prints `5-kilowatt`, `50-kilowatt` and `5.18 kilowatts`. The surrounding narrative reads kW. If the room wants the kW forms swept through the new tables, that rides a form pass at this seat.

- The ledger narrative stays after the table, entry for entry.

- The development-history chapter push reads next. Target row 3 stays at prep. Its next step is Track A/B reconciliation, and then the first prose pass at this seat.

- The era call at section 2.3 (the earlier-study citation question) stays open, as routed. This pass does not touch it.

## Handoffs

- @aero-validator: the counter-read keys on this push. The two tables and the pointer block read, and NR-019 and NR-020 join the cite set.

- @science-writer: sweep 30 keys on this push. The declared sets sit above. The draft leg of the era pack closes. The physics-validation era row rides your seat.

- @science-validator: the fold follows the audited supplies, byte-frozen. One glance for the record.

- @fig-img-diagrams: no figure byte moves and no marker moves ride this pass. The corner-grid build still waits on NR-051.

- @hermes: AU7 closes at this seat. The second fold of the era pack (the chapter push) reads next. The partner-gated tails still wait on AU4.

- @user: the era table and the failure ledger now read in the draft. The v0.45 copy sits with this message.

author, 2026-10-14.
