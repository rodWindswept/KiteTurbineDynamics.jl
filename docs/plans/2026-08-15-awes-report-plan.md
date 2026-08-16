# AWES Community Report — Implementation Plan (5 kW Kite Turbine, corrected model)

> **Goal:** A human-readable, visual-first scientific report that conveys the
> metrics and implications of the 5 kW kite-turbine work (2026-08-12 → 08-15)
> to scientists, engineers, and clean-energy enthusiasts.

**Audience & voice:** scientists, geeks, engineers, enthusiasts. Human
attention spans, visual-overdependence, plain English — not robot. All
numbers preserved exactly. Every prose draft passes a stop-slop pass
(strip AI voice). Rod's first person for outreach framing.

**Report architecture:** 8 sections + figures, assembled as PDF via LaTeX,
figures as TikZ (schematics) + matplotlib (data charts, 300 dpi).

**Materials (all verified to exist):** `ladder_v13.csv`,
`v13_5kw_len{18.0,21.2,25.0}/{island_1_best.csv, telemetry.csv,
convergence.csv, regate_verdict.md}`, `void_v13_pre-fix_len*/island_1_best.csv`,
`DECISIONS.md`, `docs/agents/{instrument-trust-log,exploit-register}.md`,
`REPRODUCIBILITY.md`.

**Skills in force:** ktd-chart-design (3 review cycles, ≤3 visual channels,
design cards, HTML prototype first), scientific-diagrams (spec-first,
narrative before drawing, data-verified only, space budgets, pixel checks),
diagram-patterns (heatmaps, implications captions, RdYlGn), stop-slop (prose).

---

## Report section map (scientific structure)

### Front matter
Title (candidates for Rod): "A 5 kW airborne wind turbine that survives its
own simulator" / "The machine that taught us it couldn't work — until it
could" / "TRPT at 5 kW: proof on a corrected physics model". Abstract:
3-4 sentences, the numbers: 7.7-8.3 kW transmitted, three lengths, what the
model denies above 15 kW.

### 1. Why this matters (half page, zero jargon)
Airborne wind energy in one paragraph. The TRPT idea in one paragraph
(spinning ring chain on Dyneema lines driving a ground generator). The
question this work answers: *does it scale, and can we prove it?* F1 sits here.

### 2. The machine (F1)
TikZ schematic: wind → rotor blades → ring chain → lines → ground generator.
One labelled figure replaces 500 words.

### 3. The physics gates (F2)
The seven checks that made the model honest: per-rotor Betz, blade Cp
falloff (drag brake past λ=9.61), torque saturation (crossing limit), rope
break (SK99 3.5%), twist collapse, tip-speed ceiling (100 m/s), ground
clearance. F2: a layered TikZ "gate stack". Why each exists — one line each.

### 4. The method (F3 + F4)
Differential evolution: 3 islands × 30 generations, full-genome telemetry,
per-length campaigns (18.0/21.2/25.0 m). F4: convergence curves (fitness vs
generation, all three lengths). One paragraph on why we let the optimiser
cheat us first — the DE as auditor.

### 5. Results (F3 + F5 + F6)
- **The ladder (F3):** heatmap of P_gen across 7 rungs × 6 lengths. Green
  5-15 kW band, the 25-50 kW stall wall (Betz: 40 m² swept vs 19.3 kW
  ceiling), the 40 m twist wall. This is the scalability picture.
- **The winners (F5):** three design cards (18.0/21.2/25.0 m) — genome,
  P_gen 7.68/8.24/8.32 kW, chain coherence, verdicts. ktd-chart-design card
  convention.
- **The honesty figure (F6):** ω_gnd vs ω_hub traces — corrected-model
  winner (16.18/16.18, coherent) against the void-era winner (hub
  freewheel, ω→1e66). One figure that shows why these results are different
  from last week's.

### 6. What went wrong on the way (F7 + F8)
The instrument faults (gate read the wrong ring; the flywheel-window bias;
NaN filters hiding divergence) and the exploits the DE found (inverted
taper, thin rings, freewheel). F7: failure census from the telemetry
(rejection reasons per campaign). F8: timeline of the cycle — one strip,
dates, what was believed vs what was true. This section is the trust
argument: *we publish the failures because they're the evidence the model
is now honest.*

### 7. Implications and open questions
The 5 kW rung is proven; the ladder denies ≥25 kW until redesign (area, not
numerics); single-rotor dominance is either a design truth or a model
preference — stated honestly. The 7 kW rung is seed-viable and next.

### 8. Reproducibility (appendix)
Condensed from REPRODUCIBILITY.md: the four steps, ~11 h, one command each.
Links: repo, DECISIONS, issue tracker.

---

## Figure inventory (each gets a spec document before any drawing)

| # | Figure | Kind | Skill | Data source | Status |
|---|---|---|---|---|---|
| F1 | TRPT schematic | TikZ | scientific-diagrams | schematic | to build |
| F2 | Physics gate stack | TikZ | scientific-diagrams | DECISIONS.md | to build |
| F3 | Ladder heatmap (rungs × lengths, P_gen) | matplotlib | diagram-patterns | ladder_v13.csv ✓ | data ready |
| F4 | Convergence curves (3 lengths) | matplotlib | ktd-chart-design | convergence.csv ✓ | data ready |
| F5 | Winner design cards ×3 | TikZ cards | ktd-chart-design | island_1_best.csv + regate_verdict.md ✓ | data ready; SimFrame renders Tuesday |
| F6 | Coherence traces (winner vs void winner) | matplotlib | diagram-patterns | needs extraction script | data extractable |
| F7 | Failure census (stacked bars) | matplotlib | diagram-patterns | telemetry.csv ✓ | needs parse script |
| F8 | Cycle timeline | TikZ | scientific-diagrams | trust-log + exploit-register | schematic from docs |

Every data figure: values computed from the CSV in the generating script —
no hardcoded numbers (diagram-patterns pitfall). Every chart: 3 review
cycles minimum (ktd-chart-design). Every TikZ: spec → spec self-review →
generate → pixel check → pdftotext check (scientific-diagrams).

---

## Bite-sized tasks

### Task 1: Report skeleton
**Files:** Create `docs/outreach/report/main.tex`, `docs/outreach/report/sections/*.tex`
**Steps:** write main.tex with article class + section includes; commit.
**Verify:** `pdflatex` compiles to an 8-section empty skeleton, 0 errors.

### Task 2: Single-source numbers table
**Files:** Create `scripts/report/extract_metrics.jl` → `docs/outreach/report/metrics.csv`
**Steps:** extract every number the report uses (winner P_gen, ω, twist,
ladder cells, Betz numbers, test counts) into one CSV with provenance
column; commit CSV + script.
**Verify:** grep every figure/prose number against metrics.csv.

### Task 3: F3 ladder heatmap
**Files:** Create `scripts/report/fig3_ladder_heatmap.py` → `docs/outreach/figures/fig3_ladder.png`
**Steps:** read ladder_v13.csv, RdYlGn with explicit vmin/vmax, PASS/FAIL
cells (diagram-patterns heatmap pattern), implications caption computed
from data. HTML prototype first for Rod.
**Verify:** 300 dpi, caption claims match CSV values exactly.

### Task 4: F4 convergence curves
**Files:** `scripts/report/fig4_convergence.py` → `docs/outreach/figures/fig4_convergence.png`
**Steps:** three lines (one per length), fitness vs generation, annotate
final values from convergence.csv only.
**Verify:** max y values match CSV.

### Task 5: F6 coherence traces
**Files:** `scripts/report/fig6_traces.jl` → `docs/outreach/figures/fig6_coherence.png`
**Steps:** run gate_design trace dumps for the 21.2 m winner AND the
void-era 18 m winner; plot ω_gnd/ω_hub per chunk for both; commit the
trace CSVs as data provenance.
**Verify:** winner lines overlap; void winner diverges (hub → 1e66).

### Task 6: F7 failure census
**Files:** `scripts/report/fig7_census.py` → `docs/outreach/figures/fig7_census.png`
**Steps:** parse telemetry.csv rejection-reason column from all three
campaigns; stacked bars per campaign; caption = the census story.
**Verify:** bar totals equal telemetry row counts.

### Task 7: F1 + F2 TikZ schematics (spec-first)
**Files:** `docs/outreach/figures/spec-f1.md`, `spec-f2.md` then `fig1_trpt.tex`, `fig2_gates.tex`
**Steps:** write specs (story, provenance, space budget, coordinates) →
self-review checklist → generate (article+geometry class, base64 method) →
compile → pixel check → pdftotext check → PNG 300 dpi.
**Verify:** scientific-diagrams verification checklist per spec.

### Task 8: F5 design cards
**Files:** `docs/outreach/figures/spec-f5.md`, `fig5_cards.tex`
**Steps:** ktd-chart-design card convention (`V13·L21.2` naming, bracketed
shorthand labels); hold SimFrame renders until Tuesday's dashboard session,
ship cards with data fields first.
**Verify:** 3 review cycles with Rod.

### Task 9: F8 timeline
**Files:** `docs/outreach/figures/spec-f8.md`, `fig8_timeline.tex`
**Steps:** one horizontal strip: 08-12 → 08-15, believed-vs-true entries
from the trust-log and exploit register; dashed = provisional.
**Verify:** every date matches the ledgers.

### Task 10: Prose drafts (sections 1-8)
**Files:** `docs/outreach/report/sections/*.tex`
**Steps:** one section per task-pair, plain English, numbers from
metrics.csv only; stop-slop pass on every draft; Rod reviews in his voice.
**Verify:** no AI-voice markers (stop-slop checklist).

### Task 11: Assembly + review
**Steps:** include figures, caption check (every figure cites its data
provenance), 3 full read-throughs, print-test at A4.
**Verify:** PDF opens clean; every number greps back to metrics.csv.

### Task 12: Publish paths
**Files:** `docs/outreach/report/README.md` (where to publish: AWES forum
post skeleton, repo link block)
**Verify:** forum post draft reviewed by Rod before posting.

---

## Timeline

| When | What |
|---|---|
| now → Monday | Tasks 1-6 (data figures + skeleton) — no new compute, all from existing CSVs |
| Monday | retrospective — report findings feed §6/§7 |
| Tuesday | dashboard flight → SimFrame renders for F5; Rod reviews F1/F2 specs |
| Wed-Thu | TikZ figures + prose drafts, review cycles |
| Fri | assembly, Rod's final read, publish paths |

**Open questions for Rod:** title pick (or leave to last); F8 timeline —
include the void campaigns explicitly, or fold into the prose?; publish
target — forum post only, or also a repo release note?
