# Reporting framework — presenting KTD to the AWES community

**Date:** 2026-10-08. **Status:** PLAN. **Audience:** university-level students —
inspired, not merely informed. **Bar:** the reporting stage carries the same
rigor as the science. Same discipline rules, same validator gates, same
provenance culture.

Parent: `docs/plans/2026-10-08-genome-landscape-analysis.md` (the analysis
this reporting presents). Reporting *prep* runs in parallel with analysis;
reporting *content* waits on analysis gates.

## 1. Principles (rigor parity)

1. **Reporting consumes only from the Numbers Register** (§3). Writers and
   figure bots never read raw CSVs or re-derive physics — that is the
   instrument-floor class of failure in prose form.
2. **Recorded > derived; derived states its recipe.** Same rule as the code.
3. **Honest failures are content.** The dead geometry genes (2026-08-24), the
   voided campaigns, the k-alignment faults, the stale-gate near-miss — these
   are the story of real engineering, and they are what makes the work
   credible to students. The report tells them, not hides them.
4. **Dual captions.** Every figure: one plain-English sentence for a first-year
   reader, plus the STE-clean technical caption for the record. Accessibility
   without losing precision.
5. **Voice.** Rod's first person, AI voice stripped, numbers exact
   (stop-slop discipline).
6. **Nothing public before sign-off.** Every figure and every prose block is
   validator-gated before it leaves the repo.

## 2. The Numbers Register (the load-bearing device)

`docs/reporting/numbers-register.md` — the single source of truth between the
simulation and the audience.

Each entry: claim · value · units · source (telemetry row range / script /
gate run / commit) · derivation recipe if derived · validator signature ·
date signed.

Rules:
- Writers and figures bots may cite ONLY signed register entries.
- Unsigned entries do not exist for reporting purposes.
- A number that changes (re-baseline, new campaign) supersedes by dated row,
  never by edit.
- Validators sign entries exactly like they sign code claims.

First entries come from Phase 0 of the landscape plan (campaign stats, winner
numbers, status mix) — nothing else until Phase 0 closes.

## 3. Bot characters (briefs)

### @author — narrative architect
Owns: story arcs and coherence. The journey of the machine through the
evolutionary search; where we pushed real boundaries; what we achieved.
Builds the skeleton every piece hangs on, so the series reads as one story,
not a pile of results. Writes Rod's first-person voice. Never invents
numbers — quotes the register. Gates: science-validator for factual claims,
Rod for voice.

### @science-writer — the explainer layer
Owns: university-level explanations. The analogies and plain-language blocks
that make the physics teachable: a TRPT is a tensegrity shaft that transmits
torque by tension; transmission capacity is supplied by tension itself; Betz
and tip-speed ceilings; mass-power scaling laws. Inputs: the register,
`docs/agents/physics-topology.md`, the AWE-context outline. Outputs:
explainer blocks keyed to specific figures. Gate: science-validator.

### @figures-images-diagrams — chart and machine craft
Owns: (a) data figures to house standards (ktd-chart-design, diagram-patterns,
scientific-chart-design; one figure per chart, HITL rounds per the diagram
registry pattern); (b) **the physical machine renders** — genome decoded into
a drawn turbine (lines, blades, rotor count, ring positions, relative sizes)
at a fixed scale, for design families and for the evolution strip
(best-per-generation). Works from the Numbers Register only: every figure
cites its signed register rows, carries a data-commit + row-range source
stamp, and ships with the generating script. Dual captions on every figure
(plain English + STE-clean technical). Figure families from consultation
Track C: evaluation-fidelity band (rapid vs ODE), lever sensitivity panels,
PCA thrive/fail regions, scaling laws. Gate: aero-validator +
science-validator, visual pass by Rod.

**Figure workflow — the three-phase HITL cycle** (diagram-registry
standard), 3 rounds, adapted to the register:
1. **SPEC** — the claim, the register citations, axes, data extract, and the
   dual-caption plan. Room-authored where the physics is theirs: the Track C
   charting plans are the spec seeds. Spec depth tiers by figure complexity:
   full spec for interpretive figures (fidelity bands, PCA regions, evolution
   strips, family renders); a light claim+axes+source spec for routine
   single-claim charts — a 1000-word spec for a bar chart is overhead, not
   rigor.
2. **GENERATE** — the chart or render, plus the generating script and the
   data-commit + row-range source stamp.
3. **CHECK — external, never self-graded.** Aero/science validators check
   the numbers and the house standards; Rod does the visual pass. The spec
   evolves by deltas between rounds, not by rewrite.

Machine renders carry one extra assertion in the CHECK phase: geometry
fidelity — every drawn dimension (line count, ring radii, span, bank) must
equal the decoded genome value. A render that misdraws the machine is a
reject (the ADR-0005 wrong-geometry class, in pixels).

### Validators (unchanged roles, new surface)
science-validator: every factual sentence, every register entry.
aero-validator: every aerodynamics figure and machine render.
software-validator: every artifact's provenance (which commit, which run).
Rod: the final visual and narrative pass.

## 4. Content units (mapped to Rod's list)

| Unit | Content | Owner | Input (gated by) |
|---|---|---|---|
| U1 | The AWE landscape: fly-gen vs ground-gen, soft vs rigid, where the TRPT kite turbine fits | @author + @science-writer | awe-knowledge, physics-topology, register |
| U2 | The levers: parameter sweeps, grid-search bands, PCA thrive/fail regions, the working parameter lines | @figures + @science-writer | landscape plan Phases 1–2 |
| U3 | The evolution story: DE generations rendered as *the turbines themselves* (best-per-generation strip, design families, relative sizes) | @figures + @author | convergence + decoded genomes (Phase 3) |
| U4 | Design implications: mass, force, scaling, torque, power of each design choice | @science-writer + @figures | Phase 3 regime table, scaling laws |
| U5 | Achievements: Daisy-anchored honesty, honest windows, tension-supplied capacity, the fold, the guards | @author | DECISIONS, trust-log, register |
| U6 | The failure ledger as story: dead genes, instrument floors, void campaigns | @author + @science-writer | trust-log, archive dirs |

The units are **internal chapters of one report** — they assemble into a
single document and release once, never as separate posts.

## 5. Missing pieces this framework adds (beyond the obvious)

1. **The Numbers Register** — without it, the writers will re-derive physics
   from memory and we will relive the 2026-08-24 record errors at report scale.
2. **The machine renderer** — we already render winners (island report PNGs);
   the reporting need is a *family* renderer: any decoded genome drawn at a
   fixed scale, so design families and the evolution strip are comparable.
   The "pictures of turbines, not just PCA plots" requirement is a pipeline
   extension, not a drawing task.
3. **The AWE-context layer** — the "where we fit" story must be grounded in
   the literature (awe-knowledge skill), validated, not recalled.
4. **Dual captions** — accessibility rule enforced from figure one.
5. **Prose validation** — science-validator reads prose for factual claims
   exactly like it reads code; stop-slop strips the AI voice.

## 6. What can start today (prep, not content)

1. Register template + first entries after Phase 0 signs.
2. Distribute the bot briefs in the room (Rod dispatches).
3. Renderer extension spec (@figures + @software-worker).
4. AWE-context outline (@author + @science-writer).
5. **Channel plan (ruled 2026-10-08):** repo-hosted report first; then
   forum.awesystems.info; then the Open Source AWE Sim/Control Signal group;
   the broader socials last (§8).

## 7. Sequencing summary

Analysis Phases 0–3 (landscape plan) → register v1 → U2/U3/U4 content →
U1/U5/U6 narrative → **assemble the single report** → whole-report validator
gate → Rod's pass → ONE release per channel (§8). Reporting prep (§6) runs
now, in parallel.

## 8. Channel plan (ruled 2026-10-08)

1. **Repo-hosted report** — the canonical, validator-gated artifact. Every
   public post links to it and cites register entries only.
2. **forum.awesystems.info** — the primary community channel. Discourse;
   Rod posts there as a frequent poster, so the voice is first-person and the
   tone is engineering, not marketing. The deliverable is **one report**:
   all content units assemble into a single document and release once,
   whole-report sign-off — no per-unit drip. The forum presentation is a
   single topic carrying the report (follow-up topics only as the community
   asks). Relevant categories: System Design, Blade Design, Math & Physics,
   Engineering, News.
3. **Open Source AWE Sim/Control Signal group** — the practitioners' channel,
   the same single report, tooling-focused framing.
4. **Broader socials** — last, and only after the community channels have
   seen the work.

Rule: a public post may only contain numbers that exist as signed register
entries; the post links the register row.

## 9. Room phasing (the 6-bot limit)

The current room has no writer/figure bots and a 6-bot cap. Split by phase:

- **Analysis room (unchanged).** Keeps the landscape plan Phases 0–3 and the
  campaign work. Writers are not needed here.
- **Reporting room (new).** Composition: @hermes (lead), @author,
  @science-writer, @figures-images-diagrams, plus Rod — five seats, one spare
  for a rotating validator when a dispute needs live adjudication.
- **The reporting trio works only from:** the Numbers Register, this
  framework, the handover doc, and signed analysis docs. They never touch
  simulation context directly — the register is the firewall.
- **Validators review via repo artifacts** (their existing rooms / Bot
  Chats), not by residency: sign register entries, figures, and prose blocks
  as they land.
- **Handover:** the reporting room boots from a handover doc (skeleton now,
  filled at register v1), not from chat history.
