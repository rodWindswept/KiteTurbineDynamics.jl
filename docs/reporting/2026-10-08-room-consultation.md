# Room consultation — report components, story elements, figure resources

**Date:** 2026-10-08. **From:** Rod, via @hermes. **To:** the analysis room
(all six members). **Context:** `docs/reporting/2026-10-08-reporting-framework.md`
and `docs/plans/2026-10-08-genome-landscape-analysis.md`.

**Why this order.** The room owns the valid-science core. The storytelling
bots (@author, @science-writer, @figures-images-diagrams — not in this room)
humanise. We want the room's chapter, diagram, and story suggestions — and as
many finished figure resources as possible — **before** the storytelling bots
start, so the report's skeleton is scientific fact, not narrative invention.

The standing goals shape everything below: **valid science** (only signed,
traceable numbers), **rapid development of clean energy systems** (the
evolutionary-search story is the speed story), and **no spurious jargon**
(every term defined, or it does not appear).

## Track A — Components and chapter structure

- What are the essential chapters of the single report?
- Are the six content units right (U1 AWE landscape, U2 levers, U3 evolution
  story, U4 design implications, U5 achievements, U6 failure ledger)? Wrong?
  Missing?
- What is the logical order for a university-level reader?
- Respond with a proposed outline: one bullet per chapter, each carrying the
  one-sentence claim that chapter must make.

## Track B — Story elements (the KTD development story)

- Which milestones and decisions are story-worthy: Daisy anchor, honest
  windows, tension-supplied capacity, the fold, the k-alignment faults, the
  dead geometry genes, the measured bank derate, Phase 0 signing?
- Which failures teach, and what is the stated lesson of each? (Honest
  failures are content — but each failure enters the report with its lesson,
  not as decoration.)
- Mission framing: for each element, say what it advances — valid science,
  development speed, or the clean-energy case. At least one of the three, or
  it does not belong.

## Track C — Figure resources (buildable now)

The report's figures divide into four classes; the room can deliver the first
three before the reporting group exists:

1. **Charting plans** — the figure list: lever sensitivity panels, PCA
   thrive/fail regions, the evolution strip, design-family renders, scaling
   laws. Name, axes, one-line claim, which landscape-plan phase supplies it.
2. **Charting data** — the prepared extracts: CSV slices and aggregates from
   the signed Phase 0 dataset, so the figures bot never touches raw
   telemetry. One file per figure, provenance-stamped.
3. **Charting scopes** — which figures can be **finished charts now**
   (house standards, dual captions: one plain-English sentence + the
   STE-clean technical caption).
4. **Charting frameworks** — the machine renderer spec: any decoded genome
   drawn as lines/blades/rings at a fixed scale, for design families and the
   evolution strip. The island winner PNGs already exist; the reporting need
   is the family renderer.
5. **Evaluation fidelity** — the rapid (`:warm` static pre-solve) path vs
   the ODE (`:cold` settle+kickstart) path. First probe
   (`scripts/probe_rapid_vs_ode_winners.jl`, 2026-10-08): `:cold` reproduces
   all three recorded winners exactly (P_mean, P_end, FoS, fitness, T_lift
   to 3 dp), while `:warm` REJECTS all three (P=0, FoS=Inf) — the rapid
   tier cannot see the best machines. The pool-sample band chart needs:
   (a) root cause of which warm reject fires (`sizing.omega_eq` nothing/NaN
   vs settle NaN), (b) a sample of ok designs across the fitness range run
   under both modes, (c) chart of accept-set agreement plus the value band
   where both accept. Note: `start_mode=:warm` is the evaluator DEFAULT —
   any analysis consumer that does not pass `:cold` is measuring the
   instrument, not the machine.

Phase 0 is signed (dataset committed), so Track C may use Phase 0 numbers
now. Anything else waits for its phase gate.

## Track D — Terminology discipline (Rod's guard)

The report may only use terms that exist in the codebase, DECISIONS, or
physics-topology — or are introduced **with a definition** at first use.

- List the load-bearing terms the report MUST define: tensegrity, TRPT,
  tension-supplied capacity, MTR, bank derate (cos²·⁶⁵), honest window,
  instrument floor, the fold, expansion rotor vs topmost rotor, L/r, β,
  and whatever the room adds.
- The room's list becomes `docs/reporting/glossary.md` — the writers may only
  use glossary terms. A shortcut-jargon term that lands without a glossary
  entry is a release blocker, gated like a number.

## Response format

- Reply in the room (chat) **and** commit the record to
  `docs/reporting/room-responses/<your-bot>-<date>.md` — the repo stays the
  authoritative record.
- Figures go to `docs/reporting/figures/`: the PNG/SVG, the generating
  script, and a one-line source stamp (data commit + row range).
- Numbers in Tracks A/B only if signed in Phase 0; Track C may use Phase 0
  numbers. Register v1 will supersede.
- Timebox: answer before register v1 signs — this consultation is the report
  skeleton; Phases 1–3 will revise Track C afterwards.
