# SPEC — V10 Convergence Trajectory Diagram

## Purpose
Show how the global best design evolved across the 60-island V10 campaign.
Three key narratives:
1. Island 30 did almost all the convergence work
2. A long constraint-wall plateau at 83.9 kg (960 iterations) preceded a reseed breakthrough
3. Two other islands independently confirmed the 76.7 kg global basin

## Data provenance
`scripts/results/v10_campaign_50kw/convergence_history.csv` — filtered to global-best steps.
Every mass value is real data.

## Layout
Single wide panel, iteration on x (log scale implied), mass on y.
Two curves: Island 30 as the main line, Islands 32/56 as confirmation markers at their convergence points.

## Data coordinates (TikZ: x=0..15, y=0..10)
Island 30 trace (subsampled every 40 iters):
(0.2, 9.3)  (0.6, 7.5)  (1.0, 7.2)  (1.4, 6.8)  (1.8, 6.7)  — rapid descent
(2.2..9.0, 6.7)  — PLATEAU at 83.9 kg (flat)
(9.4, 9.0)  (9.8, 7.2)  (10.2, 6.5)  — reseed + descent
(10.6, 6.3)  (11.0, 6.2)  (11.4, 6.15)  (11.8, 6.14)  — approaching final
(12.2, 6.13)  (12.6..15.0, 6.13)  — CONVERGED at 76.7 kg

Confirmation markers:
Island 32 at (13.5, 6.13) — label "Island 32"
Island 56 at (14.0, 6.13) — label "Island 56"

## Annotations
- "Rapid descent: 116→84 kg (160 iters)" at (1.5, 8.5)
- "Constraint plateau: 83.9 kg (960 iters)" at (5.5, 7.3) with bracket
- "Reseed breakthrough → 76.7 kg" at (10.5, 8.5)
- "Verified: Islands 32, 56" at (13.8, 5.5)

## Design
- documentclass: article with geometry (paperwidth=18cm, paperheight=10cm)
- dark background (black!95), light green curve, yellow annotations
- line width=1.5pt for main curve, dashed for plateau
- Red spike marker at reseed point
- Y-axis: "Best Mass (kg)" with ticks at 70, 75, 80, 85, 90, 100, 120
- X-axis: "DE Iterations" with the three phases labeled

## Verification
1. pdflatex → check page count=1
2. pdftoppm → pixel content >2%
3. vision_analyze: check plateau flat, reseed spike visible, islands 32/56 markers
