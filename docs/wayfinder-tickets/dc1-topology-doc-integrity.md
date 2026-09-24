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
- **Defect 5 — RULED 2026-09-24, landed.** The item now states the design rule: scale
  each rotor to take **an equal share of the torque and the power requirement**. Two
  corrections follow from the geometry, and they pull in opposite directions. The
  lowest rotor sits in the slower part of the wind profile and carries the column
  above it, so expect a larger ring, a stiffer ring and possibly larger blades. Every
  rotor above the lowest takes the co-axial wake de-rate. The retracted split is
  named in the item and retired there.
  **One discrepancy stays open.** Rod recalled the topmost rotor's blocking as
  15 per cent. Four sites in the record set 0.75x freestream power for each blocked
  rotor, which is an inflow multiplier of 0.9086. The `DECISIONS.md` entry holds both
  figures and waits on his word. It also records that the de-rate is non-cumulative
  and that in a 3-rotor stack the top two rotors are blocked, not only the topmost.

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
