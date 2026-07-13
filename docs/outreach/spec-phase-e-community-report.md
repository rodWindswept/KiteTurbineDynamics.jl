# Phase E: KTD Community Report

## Problem Statement

The TRPT kite turbine community needs a published, citable report showing the validated design envelope, structural constraints, and open research questions — enabling collaboration with Strathclyde, Freiburg, Christof Beaupoil, and the wider AWES community. The current technical report (v0.2) uses ⟨RB⟩ provisional numbers from the pre-settle-fix era and lacks the Phase D constrained-map data.

## Solution

A LaTeX community report with five TikZ-charted figures, anchored to the verified Phase D findings (Gate 2 constrained map). The report introduces the design landscape, documents the spoke physics implementation, explains the ring compression boundary, and invites collaboration on ring topology innovation. Published as a versioned PDF with Zenodo DOI.

## User Stories

1. As an AWES researcher, I want a clear, citable TRPT status report with verified data, so I can reference it in my own work and identify collaboration opportunities
2. As Windswept's founder, I want to present the Phase D envelope honestly — one viable design, clear structural boundaries — so the community sees an open research challenge, not a finished product
3. As a Strathclyde collaborator, I want the structural compression data, so I can contribute ring topology improvements
4. As a Freiburg collaborator, I want the left-flank architecture and loss model data, so I can integrate it with wake induction models
5. As Christof Beaupoil, I want the spoke and kickstart findings, so I can evaluate autogyro lift integration
6. As a future contributor, I want the build/test/campaign commands, so I can run my own variants
7. As a technical reviewer, I want data provenance — every number traces to a specific commit, campaign, and test run

## Implementation Decisions

- LaTeX template: extend the existing `docs/community/ktd-community-report.tex` or write a new `docs/outreach/phase-e-community-report.tex`
- **Figures** (5 total, TikZ/LaTeX, each with 3+ quality-check rounds):
  1. Design landscape scatter plot: FoS vs ω for all 9 tested designs
  2. Structural envelope: ring FoS vs tether diameter, annotated with cascade threshold
  3. Power curve: P vs wind speed for V10 Reinforced (5–15 m/s)
  4. Spoke drift verification: max vertex drift per ring for the working design
  5. Loss model: P_loss vs ω³, showing c ≈ 2.2–2.9 fit
- Data source: `docs/outreach/phase-d-findings.md` + Gate 2 CSVs (NAS only, not in git)
- Figure script: `scripts/generate_phase_e_figures.jl` — runs off the Gate 2 CSVs, generates TikZ .tex files
- PDF generation: `latexmk -pdf phase-e-community-report.tex`
- First figure draft → visual review → data check → style review → final

## Testing Decisions

- Tests are **visual + data**: each figure must pass three checks
  1. **Data correctness**: every plotted point matches a CSV row (diff-based verification)
  2. **Visual layout**: no overlapping labels, all axes labeled, legend clear, consistent styling with existing diagrams in `docs/awes-forum-diagrams/`
  3. **LaTeX compilation**: `latexmk` exits clean, no overfull boxes, fonts embedded
- Prior art: `docs/awes-forum-diagrams/diagram1-polygon-v4.tex` through `d7-param-convergence.tex` for TikZ style, `docs/porto-2026/KTDPaper_preprint.tex` for report structure

## Out of Scope

- Full Gate 2 multi-wind hunt for V10 Reinforced (data exists at 11 m/s only; extrapolation noted)
- Hardware validation
- Lift subsystem integration
- Wake interaction modelling
- Pitch depower campaign analysis
- Offline PDF rendering (local build only; Zenodo DOI after user review)

## Further Notes

- The report should target the AWES Forum / AWEC 2027 community, not a journal
- Tone: honest, data-forward, invites collaboration — not promotional
- Key audience members to email directly: Strathclyde crew (scan AWEC posters), Moritz Diehl (Freiburg), Christof Beaupoil, Ollie Tulloch (courtesy copy)
