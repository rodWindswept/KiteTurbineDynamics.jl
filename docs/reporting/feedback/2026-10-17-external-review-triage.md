# External review triage: 2026-10-17

Source: `docs/reporting/feedback/2026-10-17-significant-external-review.md`
(docx also archived). Relayed verbatim. exempt from the STE gate. This file
tracks every recommendation and its disposition.

Status keys: OPEN, DONE, DEFERRED (needs a seat or a call), WONTFIX (with reason).

Priority tiers:
- **T1 definitive errors**: wrong number or internal contradiction. Fix first.
- **T2 numerical or consistency**: a number does not close, or two pages disagree.
- **T3 documentation**: a method or definition the reader cannot reconstruct.
- **T4 minor or formatting**: typos, labels, headings, provenance strings.
- **T5 release blockers**: already flagged in the draft itself. close before release.

---

## T1: definitive errors

| ID | Item | Status |
|---|---|---|
| T1-1 | FoS quoted 15.0 everywhere; register NR-009 says 14.972. Penalty closes only on 14.972. Derived margins on p.9 wrong. | DONE (`c97a7fd`) |
| T1-2 | §4.2 "k-alignment fault" says 50 kW gain 1.94 equals double power; §2.2.2 shows 1.94 is lighter than 2.24, double-power anchor was 5.39/3.55. Numbers unsigned. | DONE (`85e4d08`); unsigned numbers route to T5-1 |

## T2: numerical or consistency

| ID | Item | Status |
|---|---|---|
| T2-1 | Power-speed closure off ~1.07%: P_mean 5.309 kW vs k·ω³ 5.366 kW. τ 396.76 vs k·ω² 401.03. State how P_mean and τ are averaged. | DONE (`580d33b`) |
| T2-2 | Twist-gate margin quoted at loosest limit 2.91× (δcrit) while figure shows realisability floor 2.13× and crossing gate 2.28×. Standardise %-margin formula across the p.9 table. | DONE (`e67a407`) |
| T2-3 | Blade-scale 0.82 vs true 0.8213255 (NR-050/NR-043/NR-011). Built span 1.4994 not 1.4970. Record unrounded float. | DONE (`e67a407`) |
| T2-4 | Provenance commit strings differ: §3.4 inline (dd5a9dd/0b8948d/b587c50) vs appendix (dd3cc6a/1af63fc). Reconcile. | DONE: already reconciled in the draft (appendix reads dd3cc6a/1af63fc) |
| T2-5 | Objective score rounding: 25.698 + 1.665 = 27.363 not 27.364. Add a rounding note. | DONE (this pass) |
| T2-6 | NR-006 says "gen 1" but 0-indexed convention (gen 0) used elsewhere. Standardise to gen 0. | DONE: register seed-generation block (2026-10-15) already resolves it |

## T3: documentation

| ID | Item | Status |
|---|---|---|
| T3-1 | 10-gene vector never enumerated with bounds and decode equations (§2.1, §2.2.1). Add a parameter table. | DONE (`f7de920`) |
| T3-2 | r_rotor power-sizing formula vs r_hub never defined (§2.1). State the formula and the offset. | DONE (`e67a407`) |
| T3-3 | Objective penalty seam: P_score, swing, twist_ratio, r=1 singularity, clearance 1.5 m threshold not defined in §2.4. | DONE (`f7de920`) |
| T3-4 | DE hyperparameters missing: N_pop=10, 31 gens, mutation scheme, F, CR, island isolation. | DONE (`f7de920`) |
| T3-5 | "pre-fold winner", "folded class", "cp fix", "span shrink" undefined (§2.2.2). | DONE (`f7de920`) |
| T3-6 | R5 zero axial share is physically tension, not "no load" (§3.4). Explain the cone-flare tension. | DONE (`f7de920`) |
| T3-7 | PCA PC2 dominated by inactive genes (bank_bottom, blade_scale_bottom) when rotor_count equals 1. Add caveat. | DONE (`f7de920`) |
| T3-8 | Shaft bow does not converge (0.209 to 0.613 to 0.833 m). State whether it asymptotes and at what duration. | DONE (`bd628af`) |
| T3-9 | P_mean vs k·ω³ ~1.07% offset unexplained (overlaps T2-1). Also note fixed-k couples radius search with TSR. | DONE (`f7de920`) |

## T4: minor or formatting

| ID | Item | Status |
|---|---|---|
| T4-1 | Missing section heading 2.3 (jumps 2.2.2 to 2.4). cross-ref on p.10. | DONE (`v0.58` fold): the heading sits before the load law. Numbering runs 2.1 to 2.6. NR-047's section 2.3 reference now resolves |
| T4-2 | system-anatomy inline placeholder on p.4 vs end-of-doc figure. Number the captions. | OPEN |
| T4-3 | n_Lines vs n_lines capitalization (§2.1). | DONE (`v0.58` fold): reads `n_lines`, matching NR-011, NR-044 and the atlas plate |
| T4-4 | Draft-status note says "3.4 to 3.6 carry text" but 1 to 5 all populated now. | DONE (`v0.58` fold): reads "Sections 1 to 5 carry their text" |
| T4-5 | Ranneberg attribution verify (EK_FT_0018): pending source call. | DONE (`55a1a57`): dropped |
| T4-6 | pca-landscape top panel "ground ring (x2)" clipped. | OPEN |
| T4-7 | pca-atlas colour bars print 1 or 2 sig figs, prose claims 3. | OPEN |
| T4-8 | kg vs kg-equivalent labels on pca-landscape, machine-corner-grid, machine-evolution-strip. | OPEN |
| T4-9 | machine-winner-hero top-panel callout font too small. | OPEN |
| T4-10 | Duplicate caption blocks and repeated body paragraphs (sections 3.3 to 3.5). | OPEN. Needs the built doc. The duplicate sits in the rendered caption blocks. Author pen, next pass |
| T4-11 | "3.4 The levers of Performance" to sentence case "performance". | DONE (`v0.58` fold) |
| T4-12 | "rotorcount" to "rotor-count" (§4.2). | DONE (`v0.58` fold): prose only. The dataset path `..._rotorcount_bankderate2` keeps its spelling |
| T4-13 | Double period "reject_twist.." and add NR-036 to Claims appendix. | DONE (`v0.58` fold): NR-036 added; the double period does not exist at source, so it comes from the build. Note for the build pass |
| T4-14 | System anatomy plate missing svg hash line. ledger vs checks naming. | DONE draft side (`v0.58` fold): the header states the file-type rule. TeX to PDF to PNG carries no `svg`. Every exhibit lists its own `ledger` and `checks` lines. No plate byte moves |
| T4-15 | NR-020 note 0.22540=20° bank, 0.26386=0° bank. | DONE (`3a6ddde`): the bank note lands in the register with the reading rule |

## T5: release blockers (already in draft)

| ID | Item | Status |
|---|---|---|
| T5-1 | Unsigned failure-ledger numbers (1.94, 50 kW, 5.18 kW, 20-second-window). | OPEN |
| T5-2 | Unsigned Daisy anchor values (§5). | OPEN |
| T5-3 | Nomenclature pending (§6). | OPEN |
| T5-4 | Unverified references and missing bibliography (§7). | DONE (`55a1a57`): Ranneberg dropped, Jamieson upgraded to Jamieson & Branney 2012, Hancock weaker standard |
| T5-5 | §8 branch vs commit pinning for fidelity probes. | OPEN |

---

## High-level weaknesses (map onto the items above)

- **W1** blade-root FoS=inf, deferred beam-on-supports, omitted bridles. Mass headroom only conditional. Folds into T3-8 and §4.3/§5 prose (T5-2 area).
- **W2** shaft bow does not converge. See T3-8.
- **W3** idealized constant lifter (324.1 N at 70°). Documentation, §4.3 prose.
- **W4** incomplete methods (10-gene, r_rotor, 201 rejects). See T3-1, T3-2, and the reject-cause probe (`6646df0`).

## Cross-reference to the review's section labels

Review sections map as:
- Executive Summary / Abstract / Literature: T4-4, T4-5, plus a §1 literature-gap expansion (T3-10).
- TRPT Mechanics / Pipeline / DE Methodology: T3-1 through T3-5, T4-1 through T4-3.
- Campaign Results / Winner / Visuals: T1-1, T2-1 through T2-4, T3-6 through T3-8, T4-6 through T4-11.
- Fidelity / Ledger / Boundaries / Conclusion: T1-2, T2-5, T5-1, T4-12, T4-13, plus rapid-path rope-break questions (T3-11).
- Appendices / Provenance / Register: T2-3, T2-6, T4-14, T4-15, plus omitted register data blocks (T3-12).

## Deferred seat work (cannot be done by the map seat alone)

- T3-10 (§1 literature gap and Sánchez-Arriaga / IEC 61400-2 refs): author seat.
- T3-11 (rapid-path rope-break methodology questions): aero-validator and science-validator seats.
- T3-12 (NR-044/NR-051/NR-053 missing data blocks): science-validator signs the rows first.
- T4-5 (Ranneberg attribution): pending source call. owner decides.
- T5-1 through T5-5 (release blockers): room close-out.
- T4-6 through T4-9 and T4-14 (figure renders): figures seat.

## Working order

1. T1-1, T1-2 (definitive errors).
2. T2-1 through T2-6 (numerical).
3. T3-1 through T3-9 (documentation).
4. T4-1 through T4-15 (minor).
5. T5-1 through T5-5 (release blockers, mostly deferred to room close-out).