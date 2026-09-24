# dc1 — Topology document integrity

> Part of [Decisions Conformance Audit](../wayfinder-decisions-conformance.md) · `wayfinder:grilling` · **frontier**

## Question

Every session reads `docs/agents/physics-topology.md` first. The document contradicts
itself in five verified places. Which rulings stand, and what shape does the document
take so that it can judge code correctly?

The five defects, verified 2026-09-24:

1. The header says `Last updated: 2026-09-12`. The body carries rulings through 09-22.
2. Section 3.2 holds a conflict. The heading states the prior: "The back line is an
   altitude limiter, not a load path". The ruling under that heading states the
   opposite: the back line is TAUT at the design point and carries residual vertical
   tension.
3. Every citation is a line range into a file that grows at the top. All three are
   dead. `DECISIONS.md:1806-1822`, claimed as "12/13 bridles slack", now lands on a
   settle-versus-ODE fidelity note. `:2108-2120`, claimed as "the gold bridles go
   slack", lands on `lift_for` hoisting. `:1776-1779` lands on a geometry follow-on.
4. Section 4 declares that it supersedes the 2026-08-22 top-ring exclusion. It then
   says that `CONTEXT.md` still records that exclusion as current, and that the code
   still enforces it. The document names the conflict and leaves it standing.
5. Section 5 item 5 quotes the thrust split that `instrument-trust-log.md` forbids
   re-quoting: "309 N of 2044 N", "~15 %". The ledger measured that probe as 3x high.

## Rulings

- **Defect 2. RULED 2026-09-24, landed.** Both statements stand, on separate axes.
  The heading keeps the structure statement, a height limiter and not a load path. A
  labelled pair under it carries the condition: taut, inside its elastic range, at the
  design point. Defect 2 closes.
- **Defect 4. RULED 2026-09-24, landed for documents.** The ruling retires the
  top-ring exclusion everywhere, the code included. Any rotor may be an expansion
  rotor, the topmost rotor included. `CONTEXT.md` records the 2026-09-12 replacement,
  so the claim that `CONTEXT.md` still holds the exclusion was itself stale, and the
  text goes. A code change remains owed. Section 4 lists the three sites, and the
  change is a physics change that needs its own test and acceptance run.
- **Defect 5. AWAITING ROD'S WORD.** The brief went out on 2026-09-24 with the
  measurement that replaced the retracted figures. Island 1 adds 125.3 N to a
  1537.3 N axial total, so expansion is 8.2 per cent, and the main rotor carries
  91.8 per cent. The report carries the recommended replacement text. **The direction
  reverses.** The old figures implied that the expansion rotors dominate, and the
  measurement says the opposite. The item's rule stands, and its reason changes.

## Landed 2026-09-24

Commit `8479600` landed defects 2 and 4 for documents. Commit `51d881d` landed the
eight harvested rulings that touch sections 3.2, 4 and 5.

Remaining editorial work for this ticket:

- **Defect 1.** Fix the header date on the next edit.
- **Defect 3.** Replace the three dead line-range citations with stable ruling
  identities.

## Accepted at the start of this ticket

- CONDITION, not value. The back-line ruling states where the element sits, at its hard
  stop at the design point, and lets the tension follow from `k_soft × travel`. The
  `312-320 N` figure is the design constant reporting itself, so it evidences nothing.
  Either re-evidence it or remove it. Ruled by Rod, 2026-09-24.
- The document splits STRUCTURE, CONDITION and MEASUREMENT. Derived numbers leave the
  STRUCTURE rules. Ruled by Rod, 2026-09-24.
- Name a prior once, as a scope boundary, in its own section. It never appears as a
  prohibition inside a rule. Ruled by Rod, 2026-09-24.
- Stable ruling identities replace line-range citations, so no citation can rot again.

## Sizing

One session. Mostly editorial work, with rulings from Rod.
