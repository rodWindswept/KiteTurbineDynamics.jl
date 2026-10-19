# Handover: the aero-validator seat, KTD reporting room

**Date:** 2026-10-19. **From:** @aero-validator. **To:** the successor session.
**Base:** branch tip `60a6f24` on `bank-derate-cos2p65` (read 2026-10-19). The draft on disk reads `daab5102`, byte-verified this session.

This page holds the rotation insurance for this seat. It is an index, not a retelling.
The receipts carry the story.

## The live hold: section 6.1 phase 2

The hold sits at the top of the open queue. The base is the post-join draft `daab5102` (1291 lines, 10570 words, STE 22 at 0.21).

The old azimuth-resolved gate died on the words Rod used. The flown practice holds the blade tips down, from the underside, the concave side of the chord.

The rebuild set below replaces it. Candidates live in scratch. Nothing has run against the draft on disk. It still reads `daab5102`.

The rebuild set, pinned string-exact at `daab5102` (four hunks plus one word pair):

```
H1 168
- Bank is the blade angle away from the ring plane about its chord axis at the ring.
+ Bank is the blade angle away from the plane of rotation about its chord axis at the ring.

H2 old, 1115 to 1117
- A lag short of 90 degrees turns the tilt azimuth.
- The bank and steer then act off the intended axis.
- The tilt gives side force and moment: bank, steer and load relief.

H2 new
+ The tilt azimuth turns whenever the rotor phase lag is not zero.
+ The tilt and steer then act off the intended axis.
+ If the lag exceeds 90 degrees, the part of the tilt along the intended axis reverses sign.
+ The tilt gives side force and moment: steer and load relief.

H3 1148
- First, can one-per-rev cyclic pitch on a TRPT rotor give useful bank and steer authority with no bending-capable shaft?
+ First, can one-per-rev cyclic pitch on a TRPT rotor give useful tilt and steer authority with no bending-capable shaft?

H4 old, 1162
- That check supplies the phase lag the sweep varies.

H4 new checks
+ Check the ring tilt against the rim bridle.
+ Until they run, the rotor phase lag stays a free parameter.

H4 new gate block (one blank line above it)
+ A tether-to-blade bridle holds the blade tip down, from the underside, the concave side of the chord.
+ The model carries no tether-to-blade bridle. It gives every blade one bank angle, all the way round.
+ No such bridle exists to go slack, so no design in this report can check that a bridle stays loaded.
+ So the bridle rule binds only on a design the genome cannot yet generate.

W 1189 and 1205
- with one stated capacity factor for the whole curve
+ with one capacity factor for the whole curve
- The curve states one capacity factor.
+ The curve takes one capacity factor.
```

Measured end states, all reproduced at this desk on 2026-10-19:

```
base daab5102   1291 / 10570   STE 22 / 0.21
D2   0b9d09bd   1299 / 10667   STE 22 / 0.21   word 6c1396ec
F1   01e2ec9f   1298 / 10664   STE 23 / 0.22   word 536076fe   (retired)
F2   559ce2dc   1298 / 10665   STE 22 / 0.21   word e76c8223
F3   9a7a5d17   1298 / 10664   STE 22 / 0.21   word a308305d
G3   4b49cfca   1298 / 10667   STE 22 / 0.21   word faf3d9a6
```

The G3 word hash `faf3d9a6` is the fresh measure from this desk. The other five states reproduce byte for byte from the hashes the room declared.

The F3 defect and the G3 ruling. The two absolutes in F3 print false against the source.

The model builds bridle rope segments from the lift bearing to the hub-ring vertices. The build sits at `src/initialization.jl` lines 342 to 359. The stiffness reads `BRIDLE_EA`, 500 kN, at line 318.

The draft names the lifting bridles at 648 and the rim bridle at 1142. The 1143 pin the room gave reads one line off. `src/aerodynamics.jl:349` states only the blade bridle lines are absent.

So the scoped pair in G3 is the only true form. The source forces the repair. It is not a wording call.

F3 is dead as a declaration target. G3 is the target. The author seat may still adjust the words. Any change re-measures.

The script on disk (`scratch/au_sec61_phase2.py`) still declares the old three-block chain. Its declared result `207bd022` and word `5be0a47d` are stale.

The rebuild applies H1 to H4 and W above. Each old block occurs exactly once. A reverse substitution returns the base hash.

The release conditions (not this seat). The author rules the final gate-block wording. Rod blesses the gate block and calls keep-gene or rename-command.

The rename surface is prose only. Every printed bank in the figure set is gene-sense. Keeping the gene name costs no plate.

The figure seat holds an open direction clause for 168. It is a seventh block with one re-measure. A coning echo at `figures/figure-generation-notes.md` line 62 aligns in the same pass.

## What this seat does

This seat counter-reads the numbers and the claims that enter the report.
It recomputes values from the source data, checks every cite against a signed register row,
and lands one receipt per read. It signs the F-VALUE gate for a figure family or a claim block.
The desk keeps one rule: one rigorous read per gate. The sign-off stays at this desk.

The legwork can fan out to sub-agents when the sections are independent.

## Open items

0. **The section 6.1 phase-2 hold.** See the live-hold section above. The declaration target is G3 (`4b49cfca`, word `faf3d9a6`). The release is the final gate-block wording and the two founder calls.

1. **Figure watches.** The item-5 lever-statistics extract takes an F-VALUE read if drawn values or pins move. The ring lead flag (15.033 against 15.0) stays with the room. A seat move on the machine winner hero re-keys a copy read here. The winner-form re-keys read closed with the relabel pass.

2. **Form notes.** The system-anatomy captions provenance token closes at the round-6 re-cut. The ring and twist stamp schema form stands for the builder seat. Both notes stay form only.

3. **The value-claims ledger (the report-room track).** The v1 seed reads at `aa76367`. The counter-read on the section 5 close opens when the author fold lands: every ledger row classed `measured` or touching a signed row, plus the outside-the-close target-number scan. The cost and carbon hold and the flagged set stay live until their reads class them.

Each leg runs three tests.

- Every printed value maps to a signed row at the printed form.

- The recompute matches the raw data where raw data exists.

- Every cite resolves.

Land the receipt in `docs/reporting/room-responses/` and the evidence in `scratch/` with the `av_` prefix.

## Closed, last (evidence index)

- The assumption-class counter-read (2026-10-19). The fourth class lands and survives the counter-read. Receipt `docs/reporting/room-responses/aero-validator-2026-10-19-assumption-class.md`.

- The section 6.1 phase-sentence receipt (2026-10-19). The three settled texts land in the patch script. The declared chain is stale. Receipt `docs/reporting/room-responses/aero-validator-2026-10-19-sec61-phase-sentence.md`.

- The value-claims ledger seed read at `aa76367` (readback `9789b55`): v1 classes every value-track element (measured to a signed row, capability to a landed artifact, target to a label plus pointer, with the plain label for missing pointers); eight capability rows with resolved pointers, six target rows, and the figure-seat rung seed (5 kW solid, 7 to 50 kW open plus label, matching `const RUNGS`); the cost and carbon set reads HOLD and the pointer-less set stays flagged. Checker 44 checks, 0 fail. STE rc=0 at 0.49/100w on the ledger and 0.00/100w on the receipt. Receipt `docs/reporting/room-responses/aero-validator-2026-10-16-value-claims-ledger.md`. Evidence `scratch/av_vcl_*`.

- The NR-059 counter-read read at `271182b`: the signed block passes at this desk (checker 101 checks, 0 fail; the peer checker re-runs 41 checks, 0 fail), with one scope correction riding for the science seat: the direction bound reads over the extension series and from t=38 s onward. The window decays from 0.0374 (hub, t=11 s); the relax sampled peak reads 0.2359 (t=2 s). No row value moves, and the proposed amend text sits in the receipt. Receipt `docs/reporting/room-responses/aero-validator-2026-10-16-nr059-counterread.md`. Evidence `scratch/av_nr059_*`.

- The winner bow probe read at `c6d2885`: the winner bow reads at the founder station (midpoint ring 0.10531 to 0.31005 m through the window, 0.42202 m at the extension end; hub max 0.61302 m and 0.83331 m), and the September check reads: the settle and the run do not agree on the bowed shape, an instrument finding per the 2026-09-15 ruling. Receipt `docs/reporting/room-responses/aero-validator-2026-10-16-winner-bow-probe.md`. Evidence `scratch/av_bow_probe.jl` + `.log` plus the three iteration logs. The proposed NR-059 waits at the science seat; the section 3.3 sentence then folds at the author seat.

- The placement label re-cut counter-read read at `feaaa82`. The vector census reads two drawn strings (the label and the footer script-commit stamp refresh), one box, zero values. The manifest pins recompute. F-REPRO holds at four locations. The register join verifies (the three extract blobs vs NR-013 ext2). The figures checker re-runs at this seat at 63 checks, 0 fail. Receipt `docs/reporting/room-responses/aero-validator-2026-10-15-eval-timeline-recut-counterread.md`. Evidence `scratch/av_et_pl_*`.

- The rope-break gate placement fix (the aero code seat): read at `317d9cd`. The evaluator arms break detection at the relax boundary (2026-09-16 ruling). The placement check reads 5 checks, 0 fail; the fixed path reproduces the condition CSV at 0.000e+00; cold parity holds on all three winners; the warm extract stands for the register. Receipt `docs/reporting/room-responses/aero-validator-2026-10-15-rope-break-gate-placement.md`. Evidence `scratch/av_rb_*`.

- The v0.52 basics-of-TRPT copy counter-read read at `98f7aa5`. The copy (md5 `3c386dc2`) reads its record, its 32 pins, its eight embeds and its 43-row appendix. The ten block sentences read digit-free and cite-free at the term-set junction. Receipt `docs/reporting/room-responses/aero-validator-2026-10-15-v052-copy-counterread.md`. Evidence `scratch/av_v052_copyread.py` plus log.

- The corner-machines fold and the v0.51 copy counter-read read at `7e68f0e`. The copy (md5 `74aa4c02`) reads its record, its 32 pins, its eight embeds and its 43-row appendix. The eighth embed is the corner plate (`517a77bf`). The draft folds v0.50 and v0.51 read their exact sets, with no value moves. Receipt `docs/reporting/room-responses/aero-validator-2026-10-15-v051-copy-counterread.md`. Evidence `scratch/av_v051_copyread.py` plus log.

- The lifting-bridles relabel and the v0.49 copy counter-reads read at `08b8523`. The SA relabel bytes read pin for pin, and the chain re-runs byte-identical at five locations. The draft folds v0.48 and v0.49 read their exact sets, and the corner cites close at `cb862df`. The rebuilt copy (md5 `24f98df6`) reads its record, its 28 pins, its seven embeds and its holds, with no value moves. Receipt `docs/reporting/room-responses/aero-validator-2026-10-15-bridles-relabel-and-v049-copy-counterread.md`. Evidence `scratch/av_br_relabel_read.py` and `scratch/av_v049_copyread.py` plus logs.

- The corner-grid F-CITE + F-VALUE counter-reads (row 23) read at `ec19c2f`. The kit reads its manifest and pins, and the extract binds to the raw rows at all 128 fields. The projection and the four picks recompute from the raw draw columns to the signed digits. Two fresh runs read byte-identical (F-REPRO). Two cite findings (`8855d9a` to `cb862df`) ride @fig-img-diagrams. The receipt and the evidence sit in `docs/reporting/room-responses/aero-validator-2026-10-15-corner-grid-cite-value-counterread.md`, `scratch/av_cg_cite_value.py` and `scratch/av_cg_repro_check.py` plus logs.

- The v0.47 copy counter-read and the leg folds: read at `eb93928`. The rebuilt copy (md5 `1115a201`) reads its record, its 28 pins, its seven embeds and its five register holds. The science-writer leg folds read their exact diff sets. Receipt `docs/reporting/room-responses/aero-validator-2026-10-15-v047-copy-counterread.md`. Evidence `scratch/av_v047_copyread.py` plus log.

- The round-6 counter-reads: read at `9b414f3`. The read covers the hub-name fold, the count and winner pair, and the heading. It also covers the five plate re-cuts, the three caption kits, the NR-042 footer and the re-pins. The five generators re-ran twice, out of tree, byte-identical to the delivered bytes. Receipt `docs/reporting/room-responses/aero-validator-2026-10-15-round6-counterread.md`. Evidence `scratch/av_r6_counterread.py` plus logs.

- The v0.45 copy walk: read at `8855d9a`. It covers the v0.44 figure re-pin, the AU7 folds and the v5 re-cut re-key. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-v045-counterread.md`. Evidence `scratch/av_v045_counterread.py` plus log.

- The v0.43 copy counter-read: read at `e104f30`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-v043-counterread.md`. Evidence `scratch/av_v043_counterread.py` plus log.

- The v0.41 hero copy counter-read: `e3446db`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-v041-hero-counterread.md`. Evidence `scratch/av_v041_hero_counterread.py` plus log.

- The v0.40 shape counter-read: `b0d7f70`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-v040-shape-counterread.md`. Evidence `scratch/av_v040_shape_counterread.py` plus log.

- Item-8 aero leg (the counter-reads, the NR-025 amend, the sibling sweep and the v0.39 copy read): `a7d09eb`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-item8-aero-leg.md`. Evidence `scratch/av_nr047_nr048_counterread.py`, `scratch/av_sibling_sweep.py`, `scratch/av_v039_copy_read.py` plus logs.

- Review copy last mile, v0.37: `d9d4fc4`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-review-copy-last-mile.md`. Evidence `scratch/av_v037_copy_lastmile.py` plus `.log`.

- NR-046 counter-read (the objective seam): `9d96a4b`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-nr046-counterread.md`. Evidence `scratch/av_nr046_counterread.py` plus `.log`.

- Appendix re-census (the rows 6 and 7 closure): `c30b2ca`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-appendix-repin-recensus.md`. Evidence `scratch/av_appendix_recensus.py` plus `.log`.

- Polish counter-reads (sections 3.4 to 3.6 and 5): `7b8c101`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-polish-counter-reads.md`. Evidence `scratch/av_polish_counterread.py` plus `.log`.

- Harris-3.5 F-VALUE counter-read (map rows 6 and 7): `a3f4ae3`, fix `ef36c6c`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-harris35-fvalue-counterread.md`. Evidence `scratch/av_fig35_fvalue.py` plus `.log`.

- F-VALUE re-census, levers family: `7329191`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-pca-fvalue-recensus.md`. Evidence `scratch/av_pca_fvalue_recensus.py` plus `.log`.

- F-VALUE counter-read, levers family: `331f60d`. Receipt `docs/reporting/room-responses/aero-validator-2026-10-14-pca-fvalue-counterread.md`. Evidence `scratch/av_pca_fvalue_counterread.py` plus `.log`.

## Boot

- Repo `KiteTurbineDynamics.jl`, branch `bank-derate-cos2p65`. Fetch first. Every seat pushes to this shared tree.

- Read `handovers/handover-2026-10-08-reporting-room-boot.md` and the rulings page beside it.
  Then the register at `docs/reporting/numbers-register.md`.

- Load the skills `ste-writing` and `physics-model-validation` before the first read.

- Nothing of this seat lives only in a chat. This page plus the receipts resume the seat in one readback.

## Working rules

- Cite only signed rows. Recompute, never re-read a prior report.

- Stage only your own paths. Peers may hold staged files in this shared tree.

- Add evidence logs with `git add -f`. The `*.log` pattern sits in `.gitignore`.

- Run `python3 ste-lint.py --fail-above 2.0` on the file before the commit.

- Verify the push. The local branch matches origin, and the blob reads byte-identical at origin.

- Never run `git clean` in this tree. The untracked files carry seat evidence.

- Route findings through the room and the receipts. Do not post to the Signal Note to Self channel (TEAM_CHARTER section 4). The mechanics sit in `docs/reporting/room-responses/aero-validator-2026-10-12-signal-silence-mechanics.md`.

**Owner:** @aero-validator. **Next action:** the section 6.1 hold waits on the gate-block wording and the two founder calls.
The close fold and the fixed-defect read wait on the author fold. The figure watches hold.
The field-pair seat call holds. The warm extract register fold closed at `fab730a`.
