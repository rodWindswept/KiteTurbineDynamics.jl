# Decisions Conformance Audit: the model record versus the code

> **wayfinder:map**: track decisions, not deliverables. Tickets live in `docs/wayfinder-tickets/`.
> `label:wayfinder:map`
> Charted: 2026-09-24.

## Destination

Every active ruling in the record sits in one place with a clear status. Each ruling links to the source that implements it and the test that checks it. Every conflict is either ruled by Rod or listed as open. A ratchet exists, so a new decision cannot arrive without a guard.

This shape fixes the repeats. The repeats come from decisions that nobody can check. They do not come from decisions that are wrong.

## Notes

- **Tracker:** local markdown. `gh` is absent on this machine, verified 2026-09-24. The GitHub tracker is unreachable from here. Tickets are files under `docs/wayfinder-tickets/`. The map is this file.
- **Skills every session:** `grilling`, `domain-modeling`, `physics-convention-audit`, `literature-crosscheck` in internal-consistency mode, `doc-staleness-audit`.
- **The domain trap.** The physics here is extreme tensile flying networks. The default answer is wrong. Use the annulus, not the disc. Use `1/N²`, not `1/√N`. Lines carry tension only. The column floats as a tensegrity. One ring has one plane. A rule therefore names a prior only as a **scope boundary**. Example: "the law of Peter Jamieson is derived for disc rotors, where area grows as the span squared". A rule never states a prohibition. Absolutes go only to rules that a test enforces.
- **The record lives in more than one place.** `DECISIONS.md` holds newest entries first. Rulings also live in `docs/agents/physics-topology.md`, `CONTEXT.md` and `docs/adr/`. Harness state outside git holds a fifth set.
- **Baseline.** HEAD `aa3d62a` plus the working tree, as of 2026-09-24. Another session works in that tree at the same time.
- **Restraint on new claims.** A derived result stays DERIVED until an external measurement validates it. No in-model check can promote it.

## Rulings of this charting session

Rod ruled these. They are decisions, so they sit here and not in a ticket.

- **Back line (Q1).** State the ruling as a condition, not a value. At the design point the element sits at its hard stop. The tension then follows from `k_soft × remaining travel`. The figure `312-320 N` is the design constant reporting itself. It proves nothing about the physics. It needs independent evidence, or it leaves the document.
- **Topology voice (Q2).** The document separates STRUCTURE, CONDITION and MEASUREMENT. STRUCTURE says which nodes and lines exist. CONDITION says what the structure must satisfy at a stated operating point. MEASUREMENT records a value at one seed. Derived numbers stay out of STRUCTURE rules.
- **Multi-rotor sizing (Q3).** `1/N²` is the chain from Peter Jamieson with the annulus area-span relation in place of the disc relation. It is the small-span limit of the exact quadratic. The knuckle floor blunts it. That is why the recorded ratio is 0.128 and not 0.111. Status: DERIVED. The island 1 against island 3 comparison does not count as evidence, because both were mis-sized. The rule now sits at `docs/agents/physics-topology.md` section 4.1.
- **Priming (Q4).** A named prior can trigger that prior. A rule states the positive invariant and the check that holds it. The document names a trap once, in its own section, with an applicability boundary.
- **Entry point (Q5).** `CLAUDE.md` now sends the reader to the top of `DECISIONS.md`. The test counts match `AGENTS.md`.
- **Handovers (Q5).** The two documents of 2026-09-23 now sit in `handovers/` with dated names and an index row each. They had broken both the naming rule and the location rule in `handovers/README.md`.

## Decisions so far

- [Harvest the rulings made outside git](wayfinder-tickets/dc3-harvest-harness-records.md): eight rulings were made outside git and never landed. The item this map ranked first is refuted as stated. The reported maximum tension tracks the elastic maximum at 0.97 times.

## Open tickets

| Ticket | Type | Blocked by | Question |
|---|---|---|---|
| [Topology document integrity](wayfinder-tickets/dc1-topology-doc-integrity.md) | grilling | none | Which rulings stand where the headings contradict the bodies, and what shape does the reference document take? |
| [Conformance of the record to the code](wayfinder-tickets/dc2-topology-conformance.md) | research | dc1 | For each ruling: the source line that implements it, the test line that checks it, and one verdict. |
| [Ratchet design](wayfinder-tickets/dc4-ratchet-design.md) | grilling | dc2 | What makes a decision checkable, and what enforces it? |

## Not yet specified

- Whether `CONTEXT.md` splits into a glossary and a separate campaign history. It mixes both today, and the skill suite expects a glossary. This waits on the rulings about where decisions officially live.
- Whether `docs/adr/` absorbs the topology laws, or keeps only hard-to-reverse architecture decisions. This waits on ticket dc1.
- The dead line-number citations across the record. One example is `DECISIONS.md:1806-1822`. The fix is mechanical once the citation convention is ruled.
- The maximum tension the instrument reports. The damper term is signed and the scan covers TRPT sub-segments only, so the read does not bound the bridle cone. The measured maximum tracks the elastic maximum at 0.97 times, which refutes the 2.6 times claim. The break-on-stretch ratio stays unmeasured. The record home is the trust log plus the ledger, and it is one of the eight harvested rulings.
- An STE pass on `docs/reports/2026-09-24-unlanded-rulings.md`. It sits at 4.33 violations per 100 words and the commit gate refuses it. The prose, not the research, needs the work.
- Whether the revocable protobuf stores under `~/.gemini/` hold rulings a text scan cannot reach. They were unread, and that is a live residual risk for the harvest.
- The BEM sizing defects upstream of every sizing claim. `power_split = 0.6`, the `n_active == 1` branch and the unanchored 50 m shear reference all distort the numbers the record quotes. They may need a rule of their own.

## Out of scope

- **Fixing the BEM sizing defects in `src/objective_v10.jl`.** The defects are real and open. The remediation workstream owns them, at Phase 5 of `handovers/handover-2026-09-23-multirotor-bem-sizing.md`. This map decides what the record says about the sizing. It does not rebuild the sizing.
- **The TDD application audit**, at `docs/reports/2026-09-24-tdd-application-audit.md`. That is an adjacent question with its own effort. Its hook and its test list serve as prior art for ticket dc4.
