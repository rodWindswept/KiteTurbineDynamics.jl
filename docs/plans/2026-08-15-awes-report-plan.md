# AWES Community Report v2 — Implementation Plan (5 kW proof, corrected model)

> **Goal:** A versioned, citable PDF report — for general release, the AWES
> forum, and windswept.energy — that fully and honestly presents the 5 kW
> kite-turbine proof: metrics, physics, failures, and implications.

**Audience & voice:** scientists, engineers, clean-energy enthusiasts.
Plain English, human attention spans, visual-first. Every number preserved
exactly; every prose draft passes the stop-slop pass; outreach framing in
Rod's first person.

**Publish targets:** PDF (general release) · AWES forum post · windswept.energy
· Zenodo DOI (prior convention from `spec-phase-e-community-report.md`).

**Base to extend (surveyed 2026-08-15):**
- `docs/community/ktd-community-report.tex` — prior community report (Phase D/E era)
- `docs/outreach/ktd-technical-report.tex` — structure to inherit:
  *Status of Numbers* → *Introduction: The TRPT Kite Turbine* → *The KTD.jl
  Framework* → *Key Findings* → *Comparison with Prior and Parallel Work* →
  *Conclusion*
- `docs/outreach/chart-prd.md` — the per-figure PRD convention (narrative
  research → data verification with source-inventory checkboxes →
  counterintuitive findings → design spec). ~700 lines; this is the spec
  template for every new figure.
- `docs/outreach/figure-review.md` — the failure lessons to engineer out:
  charts carried the retracted design's name; provenance boxes cited CSVs
  that were never in the repo; two data sources disagreed 2.5× on a headline
  design. **New rule: every provenance box cites a CSV that exists in the
  repo at the report commit; one `metrics.csv` is the single source of truth
  for every prose number; cross-source disagreements are reconciled before
  any figure ships.**
- Prior TikZ sources are GONE from git (`docs/awes-forum-diagrams/*.tex` and
  `docs/outreach/figures/*.tex` — only `.aux`/`.log` survive). Style
  reference = the rendered PDFs + `figures/report/*.png`. All new figures
  get fresh specs; no source resurrection attempts.
- Existing rendered figures to reuse/verify: `figures/report/fig_trpt_concept.png`,
  `fig_trpt_system.png` (F1 candidates — concept-level, model-agnostic),
  plus prior convergence/landscape PNGs as style references.

**Skills in force:** ktd-chart-design (3 review cycles, ≤3 visual channels,
design cards, white backgrounds), scientific-diagrams (spec-first, narrative
before drawing, data-verified only, space budgets, pixel + pdftotext checks),
diagram-patterns (heatmaps, implications captions), chart-prd convention
(per-figure PRD), stop-slop (prose).

---

## Report structure (inherits the prior skeleton, updated content)

1. **Status of Numbers** (inherited discipline) — what is verified vs
   provisional, at which commit, on which model era. This section IS the
   trust argument.
2. **Why this matters** — AWE + TRPT in plain words. F1.
3. **The machine** — F1 (reuse fig_trpt_concept/system, regenerate if needed).
4. **The physics gates** — F2: the seven checks. One line each on why.
5. **The method** — DE campaigns, 3 islands × 30 gens, telemetry. F4.
6. **Results** — ladder envelope F3, winner cards F5, coherence traces F6.
7. **What went wrong — and what it taught us** — F8: **a table of failures
   and learnings** (failure → what we believed → what was true → the fix →
   the learning for the next rung) + prose. This replaces my earlier
   timeline idea per Rod.
8. **Implications and open questions** — the 5 kW proof, the ≥25 kW rows
   **unproven** (gate start-up artifact — see F3 caption and retrospective
   §4 correction; the seed-rule area constraint remains a design argument,
   not an ODE verdict), single-rotor dominance, the 7 kW next step.
9. **Comparison with prior and parallel work** (inherited section).
10. **Reproducibility** — condensed from REPRODUCIBILITY.md, ~11 h,
    one command per step.

## Figure inventory (one folder per figure: `docs/outreach/report-figures/<name>/`)

Each figure folder contains: `spec.md` (PRD per the chart-prd convention,
~1000 words), `generate.*` (script), `figure.tex` (TikZ) or `figure.py`
(data chart), `figure.png` (300 dpi), `review-<n>.md` (round log).

| # | Figure | Kind | Data | Reuse |
|---|---|---|---|---|
| F1 | TRPT schematic | TikZ | schematic | verify/regenerate fig_trpt_* |
| F2 | Physics gate stack | TikZ | DECISIONS.md | new |
| F3 | Ladder heatmap (rungs × lengths) | matplotlib | ladder_v13.csv ✓ | new |
| F4 | Convergence curves ×3 | matplotlib | convergence.csv ✓ | new |
| F5 | Winner design cards ×3 | TikZ cards | island_1_best.csv + regate_verdict ✓ | new (card convention) |
| F6 | Coherence traces (winner vs void) | matplotlib | extraction script needed | new |
| F7 | Failure census (telemetry reasons) | matplotlib | telemetry.csv ✓ | new |
| F8 | Failures-and-learnings TABLE + prose | LaTeX table | trust-log + exploit-register | new |

## Review loop (per figure — the standard Rod set)

Three full rounds, each round = **styling → data accuracy → formatting →
human-in-the-loop evaluation**, each round logged in `review-<n>.md`, each
fix applied before the next round. Data accuracy check: every plotted point
diffed against its CSV row; every prose number greps back to `metrics.csv`.

## Vision-tool requirement — RESOLVED (2026-08-16 session)

`vision_analyze` is available (Gemini-backed) and was used through 11+
strict review rounds on F9 alone. **Lesson learned the hard way:** a plain
"does it look OK?" prompt ACCEPTS overlaps that a human rejects — Rod's
HITL round caught text-on-data and legend collisions the lenient rounds
passed. The standard is now: strict enumeration prompts ("enumerate EVERY
instance where any text touches, crosses, or overlaps any other text OR
data element; do not say 'legible'"), opaque white bboxes (alpha 1.0) for
text over data, and legend/caption height math (caption height ≈ n_lines
× 0.125 in; an 8-line caption on a 5.6-in figure is ~19% of the height).
Also: the vision model cannot see white-on-white boxes (the invisible-box
paradox) — trust matplotlib's bbox contract, not the model's "no box" read.
Logged in the ktd-chart-design skill.

## Status update (2026-08-16/17 session)

| # | Figure | Status |
|---|---|---|
| F1 | TRPT schematic | pending (TikZ) |
| F2 | Physics gate stack | pending |
| F3 | Ladder heatmap | **DONE** — built, prose'd, vision-passed, 2 Rod HITL rounds (caption: plain language, numbers verified against ladder_v13.csv, ≥25 kW rows reframed as start-up stall — no physics verdict) |
| F4 | Convergence curves | **DONE** — captions plain-language pass |
| F5 | Winner design cards | pending (needs dashboard flight) |
| F6 | Coherence traces | **DONE** — captions plain-language pass |
| F7 | Failure census | **DONE** — reject classes defined from the code (power floor / FoS gate / above-Betz divergence flag); caption states campaigns ran 18/21.2/25 m only |
| F8 | Failures-and-learnings table | pending (Monday retrospective feeds it — now includes the anchor session addendum) |
| **F9** | **April-29 anchor (NEW)** | **DONE** — measured-vs-model power curve, 30-s means, model 234 vs 223 ± 79 W, Cp_sys ≈ 0.16 both (Oliver 0.166); the headline calibration result |

Additional lessons folded into the review loop: every caption must
introduce its own technical terms (no unexplained "rung"/"island"/
"genome"), every number must grep back to its CSV, and each figure's
place in the report's argument must be stateable in one sentence.

**Prose discipline (Rod's standards, applied):** captions are the
reader's only context — plain language, all numbers exact, nothing
asserted that the CSV doesn't show.

## Bite-sized tasks (paths under `docs/outreach/report-figures/` and `docs/outreach/report-v2/`)

1. Report skeleton: `docs/outreach/report-v2/main.tex` — inherit section
   order above; compiles empty; commit.
2. `metrics.csv` single-source extraction: `scripts/report/extract_metrics.jl`.
3-10. F1-F8: per-figure folder (spec → generate → round 1 → fix → round 2 →
   fix → round 3 → final PNG + log), in the order F3, F4, F6, F7 (data
   figures, no new compute), then F1, F2, F5, F8 (TikZ/table).
11. Prose sections 1-10, numbers from metrics.csv only, stop-slop pass each.
12. Assembly + 3 read-throughs + print test.
13. Publish: PDF + forum post draft + windswept.energy copy + Zenodo DOI.

## Timeline

| When | What |
|---|---|
| now → Monday | Tasks 1-2 + F3/F4/F6/F7 (data figures, zero new compute) |
| Monday | retrospective → feeds F8 + §8 |
| Tuesday | dashboard flight → SimFrame renders for F5 |
| Wed-Thu | F1/F2/F5/F8 + prose, review rounds |
| Fri | assembly, Rod's final read, publish paths |

**Status (2026-08-16/17):** F3/F4/F6/F7 + F9 done ahead of schedule
(data figures complete; two Rod HITL rounds on F3/F9 with caption
corrections). Remaining: report-v2/main.tex skeleton + metrics.csv (task
1-2, not yet started), F1/F2/F5/F8, prose sections, assembly. The
Monday retrospective now carries the anchor-session addendum (2026-08-16)
— it feeds both F8 and §8, and it reopens the "≥25 kW denial" wording
(the ladder cells are a gate start-up artifact — see retrospective §4
correction).

**Decisions recorded:** title chosen last; F8 = failures-and-learnings table
+ prose; publish = PDF general release + AWES forum + windswept.energy, full
honest reveal; per-figure folders with PRD specs and 3 review rounds.
