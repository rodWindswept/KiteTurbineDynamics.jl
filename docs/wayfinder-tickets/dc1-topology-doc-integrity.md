# dc1 — Topology document integrity

> Part of [Decisions Conformance Audit](../wayfinder-decisions-conformance.md) · `wayfinder:grilling` · **frontier**

## Question

`docs/agents/physics-topology.md` is the reference document every session reads first,
and it contradicts itself in five verified places. Which rulings stand, and what shape
does the document take so it can judge code without judging it wrongly?

The five defects, verified 2026-09-24:

1. The header says `Last updated: 2026-09-12`, and the body carries rulings through
   09-22.
2. §3.2's heading states the prior — "The back line is an altitude limiter, not a load
   path" — and the ruling under that heading states the opposite: the back line is TAUT
   at the design point and carries residual vertical tension.
3. Every citation is a line range into a file that grows at the top, and all three are
   dead. `DECISIONS.md:1806-1822`, claimed as "12/13 bridles slack", now lands on a
   settle-versus-ODE fidelity note. `:2108-2120`, claimed as "the gold bridles go
   slack", lands on `lift_for` hoisting. `:1776-1779` lands on a geometry follow-on.
4. §4 declares that it supersedes the 2026-08-22 hub exclusion, then says `CONTEXT.md`
   still records that exclusion as current and the code still enforces it. The
   conflict is named and left standing.
5. §5 item 5 quotes the thrust split that `instrument-trust-log.md` forbids
   re-quoting: "309 N of 2044 N", "~15 %". The ledger measured that probe as 3× high.

Open rulings needed from Rod, one per defect:

- **Defect 2.** Does the heading change to match the ruling, or do both stand as
  separate statements (limiter as its field job, taut at the design point)?
- **Defect 4.** Does the 2026-08-22 hub exclusion get retired from `CONTEXT.md` and the
  code in this workstream, or does §4 lose its claim and keep the exclusion?
- **Defect 5.** Do the retracted magnitudes leave the document, and does the rule keep
  an illustrative case from the measurement that replaced them (8.2 % on island 1)?

## Accepted at the start of this ticket

- CONDITION, not value: the back-line ruling states where the element sits (at its hard
  stop at the design point) and lets the tension follow from `k_soft × travel`. The
  `312–320 N` figure is the design constant reporting itself, so it evidences nothing.
  Either re-evidence it or remove it. Ruled by Rod, 2026-09-24.
- The document splits STRUCTURE, CONDITION and MEASUREMENT, and derived numbers leave
  the STRUCTURE rules. Ruled by Rod, 2026-09-24.
- A prior is named once, as a scope boundary, in its own section. It is never a
  prohibition inside a rule. Ruled by Rod, 2026-09-24.
- Stable ruling identities replace line-range citations, so no citation can rot again.

## Sizing

One session. Mostly editorial, with three rulings from Rod.
