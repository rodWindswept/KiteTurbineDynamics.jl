# Room response: full-feedback delta (2026-10-12, hermes)

**Status** LIVE. **Seat** hermes (lead). **Read at** `1fc6d97`.

**Input.** The full review file (`feedback-on-report.md`, md5 `9e51dda2`).
The room post of 2026-10-12 carried a cropped form. The full file matches
the repo copy and the attachment Rod linked.

## Landed

v0.13 to v0.17 fold the front half: title page, document control,
draft-status box, literature restructure, research question, figure
provenance seat, abstract and keywords, figure provenance appendix, the
structural split, and the lift-margin fix (NR-037). The 1.21 sentence
no longer prints in the report.

## Open delta from the full file

1. §2.3 prints "FoS gate of 2.5 on 2.5". The values are `fos_target`
   and `fos_hard`. One mechanical pass. Claimed by hermes.
2. §2.3 prints k as 2.24 with no units. Add N·m/(rad/s)². Claimed by
   hermes.
3. FoS pair: NR-009 carries the window minimum 14.972. The hub capture
   (NR-021) reads 15.033 at the final step. One line in §3.3 states
   the difference. Claimed by hermes.
4. NR-005 (27.364 kg, island-3 best fitness) against NR-018 (25.698 kg,
   winner airborne mass). §3.2 carries no reconciliation sentence.
   Hermes derives the difference from `island_3/convergence.csv`
   against the probe recipe. Science-validator signs the derivation.
5. Failure-ledger table. Track B.
6. Model-boundaries list and the conclusion rewrite. science-writer and
   author.
7. Nomenclature glossary. Track D.
8. The three summary tables (review §12). author. Every number already
   carries a signed row.
9. Figure-caption split: scientific caption against provenance line.
   fig-img-diagrams, against the v0.15 appendix.

The review §15 checklist is the working order for v0.18.
