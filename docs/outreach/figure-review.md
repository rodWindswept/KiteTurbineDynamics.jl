# Figure Review — docs/outreach/figures (2026-07-16)

> **⚠ HISTORICAL — all audited data is pre-fix triangle geometry** *(banner
> added 2026-07-18, doc-staleness audit)*. Every dataset this review audits
> (`wind_sweep`, catalog, dumbbell, viability) predates the builder fix
> `7d43455` (2026-07-17): `wind_sweep.csv` at HEAD is byte-identical to
> `legacy/wind_sweep_triangle_legacy.csv`. The review's fixes were largely
> executed within 24 h, but the figure PNGs (rendered 07-17 12:05, eight
> minutes before the fix commit) still plot triangle data. **Do not regenerate
> Phase-E figures until the post-fix sweep CSVs land** (re-run in flight
> 2026-07-18).

Scope: all 8 PNGs, their .tex sources, cross-checked against `wind_sweep.csv`,
`chart-prd.md`, `phase-e-design-landscape.md`, and `handovers/handover-2026-07-14-audit.md`.

---

## Cross-cutting problems (fix these first)

### 1. Three figures carry the retracted design's name

`chart-structural-efficiency.tex`, `design-landscape-scatter.tex`, and `design-cards.tex`
all title themselves **"V10 Tight"**. Per the 2026-07-14 handover, V10-Tight is the
*retracted* 49.2 kg centre-constraint design; all Phase D/E work is **V10-Spoke**.
`fig2`, `fig4`, and `chart-power-curve` already say V10-Spoke. Anyone who has read the
retraction will assume these three charts use the inflated-FoS spoke model.
`phase-e-design-landscape.md` has the same header defect.

### 2. Figures cite data files that are not in the repo

Every provenance box cites `catalog_corrected_geo.csv` (commit 8cb23f9); the fig4 PRD
also cites `kickstart_sweep.csv`. Neither file exists — `scripts/results/control_maps/`
contains only `wind_sweep.csv`, `power_curve_quick.csv` (header only, 0 rows), and the
tier-X directory. The catalog and kickstart numbers survive only as transcriptions in
`chart-prd.md` and the design cards. The handover's claim that "campaign CSVs are
tracked" is not true for these two. Until the sweeps are re-run and the CSVs committed,
none of the catalog-based figures are reproducible and none of their numbers are
independently checkable.

### 3. The two data sources disagree — on the headline designs

The catalog sweep (30 s MPPT) and `wind_sweep.csv` (45 s per point) publish different
numbers for the same design at the same 11 m/s wind, and both sets are on charts
sitting in the same folder:

| Design @ 11 m/s | Catalog (fig2, cards, scatter) | wind_sweep (power-curve chart) |
|---|---|---|
| 0.90·k6 "Safest" | **81 kW**, FoS 11.3, 168 rpm | **204 kW**, FoS 6.4, 323 rpm |
| 0.95·k4 "Sweet spot" | **199 kW**, FoS 5.2, 257 rpm | **163 kW**, FoS 3.9, 288 rpm |
| 1.10·k4 "Max power" | 297 kW, **FoS 2.3**, 272 rpm | 297 kW, **FoS 5.3**, 391 rpm |

The 0.90·k6 case is a 2.5× power discrepancy on the design recommended "for first
demonstration". As published, an outside reader comparing the design cards to the
power curve will conclude the numbers are made up.

**Root cause (desktop reconciliation, 2026-07-16):** the catalog used r_bottom=1.30
(Round 1), the wind sweep used the builder default r_bottom=1.00; settle code is
identical (ω_max=9.5), durations differ (30 s vs 45 s). Two consequences:

1. **chart-power-curve is mislabeled.** Its curves carry the catalog design names
   ("0.95·k4 Sweet spot", "0.90·k6 Safest", "1.10·k4 Max power") but are r=1.00
   geometry — per the design cards' own variant key, those names belong to r=1.30
   designs. The r=1.00 variants have their own designations (e.g. V10·λ0.95·k2ʳ).
   Either relabel the curves with the ʳ superscript convention or re-run the sweep
   at r=1.30.
2. **The PRD's "r_bottom is a null parameter" claim (chart-prd.md, counterintuitive
   finding #2) is wrong as stated.** It was established by comparing r=1.30 vs 1.15
   (bit-identical); r=1.00 clearly produces different power, FoS, and ω. The claim
   should be narrowed ("insensitive over 1.15–1.30") or retracted — it must not
   appear on any figure.

**Reconciliation outcome (desktop, 2026-07-16, commit 417819d):** multi-equilibrium
confirmed on top of the geometry difference — 0.95·k4 shows the clearest bifurcation
(standard settle 8 kW @ 97 rpm vs kickstart 127 kW @ 209 rpm, same r=1.30 frame).
Caveats: the reconciler used 15 s captures (memory limits killed the 120 s runs), so
its absolute numbers are not converged and must not appear on charts; catalog (30 s
MPPT) values remain canonical. Open items: (a) `equilibrium_090k6.csv` (committed to
`figures/data/` at repo root, not `docs/outreach/figures/data/`) exports a *static*
P_aero(ω) curve peaking at 10.9 kW with a single equilibrium at ~120 rpm —
contradicting every observed 0.90·k6 state (81–204 kW); the static–dynamic gap again.
The multi-equilibrium explainer chart is blocked until a dynamic-model export exists.
(b) `viability_grid.csv` marks 0.69·k8 (13.8 kW) as `pass=true` — pass flag suspect.
(c) 0.75·k6 recovered at 161 kW but no ω recorded — absent from fig4a/4b (noted on
both). (d) 0.85·k2 spans 117–167 kW depending on start protocol/capture time;
figures use the settle_dumbbell value (167 kW @ 391 rpm) with the range noted.

### 4. Suspect FoS values plotted without caveat

wind_sweep FoS spikes (30.7 at 0.95/13 m/s, 27.4 at 1.10/15 m/s, 14.0 at 1.00/11 m/s)
coincide with equilibrium jumps and look non-converged. The 657 kW / FoS 27.4
bifurcation point is the most-annotated feature of the power-curve chart yet is the
least trustworthy number on it. The chart-prd itself warns FoS on non-converged states
is meaningless. Mark these tier-provisional or re-run with the dual-duration check from
`gate1-control-map-rerun.md` §3.4 before featuring them.

---

## Figure-by-figure

### chart-mass-origin — IRRELEVANT HERE (your instinct is right)

Content is the V6.2 DE mass campaign (n-gon count, 74.17 kg, 60 islands × 10k iters,
14-DoF) — a different work section, different model generation, nothing to do with the
Phase-E 50 kW design landscape. It also has broken layout: the three "System Reality"
paragraphs float outside their coloured boxes (boxes render empty), "Coupled system
dominates" collides with the rotor-consolidation paragraph, and the "n=3 lightest"
arrow points into blank space. **Recommendation: remove from this figure set.** If the
outreach report needs a "why 12-gon" sidebar, rebuild it there — with V6.2 clearly
labelled so it isn't read as V10-Spoke evidence.

### chart-eff.png — DELETE

Orphan duplicate of chart-structural-efficiency (no .tex, older render, same content,
same defects). Two visually-identical files with different pixels invites citing the
stale one.

### chart-structural-efficiency (FoS vs P, iso-quality curves)

Data: matches the catalog numbers in phase-e/cards. ✓
Presentation defects:

- Bounding box broken: title sits mid-canvas, iso-quality hyperbolae shoot off the top,
  ~40% of the canvas is whitespace above the title.
- "1.10·k4 [297 kW, FoS 2.3] Max power" and "0.95·k4 … ★ Sweet spot" labels are typeset
  through each other — the sweet-spot label is unreadable.
- The 1.00·k2³·⁵ point (223 kW, FoS 2.5) renders near-white — a colormap bug makes one
  of your 13 designs invisible.
- Colorbar overlaps its own caption; iso-curve labels (400/1200/1600) clipped at right
  edge.
- Redundant with fig2 (same 13 points, same axes). **Merge**: keep ONE FoS-vs-P chart —
  fig2's band shading plus this chart's iso-quality (FoS×P) curves and Pareto front are
  complementary and belong on the same figure.

### fig2 (FoS vs Power, band version)

Data: all 13 points verified against the phase-e table. ✓
Presentation defects:

- "Blade:" legend row overlaps the x-axis tick labels (100/150/200 collide with
  swatches).
- "FoS=2.0" gate label collides with the "Marginal (2–2.5)" band label — renders
  garbled.
- The P=50 kW gate line sits on the y-axis (x starts at 50) — invisible and pointless;
  start x at 0 or drop the line.
- Only 4 of 13 points labelled, and labels float far from their points ("1.00" sits
  next to the orange 1.05 point).
- Band fills stop at FoS=2 but the Marginal band is defined to 1.5.
- No sweet-spot / max-power callouts; no kickstart-regime annotation (PRD asked for
  both).

### design-landscape-scatter (P vs ω, catalog only)

Data: matches cards. ✓
Defects:

- "V10 Tight" title (see cross-cutting #1).
- Redundant with fig4 — same axes, subset of the data. Keep one P–ω chart.
- Leader lines cross the entire plot (the sweet-spot label is at the right edge, its
  leader passes through the point cluster; 0.90·k6's leader crosses the P=50 line).
- The dotted "Pareto front" path is drawn in P–ω space where it isn't a front — it
  zigzags backwards through ω. The front lives in P–FoS space (fig2); here it misleads.
- Colorbar dropped on top of the x-axis "400" tick and the footnote caption.

### design-cards — KEEP (best artifact of the set)

Accurate against phase-e, honest variant/kickstart footnoting, roles column is
genuinely useful. Fixes: retitle V10-Spoke; the intro says "13 viable designs
discovered in a 50-point catalog sweep" — the kickstart designs were *not* discovered
by the catalog, which is your own headline finding; reword. Consider adding a
"discovered by" column (catalog vs kickstart) — it turns the table into the
settle-bug story.

### chart-power-curve (P vs wind, 4 strategies)

Data: every plotted point and FoS label verified against `wind_sweep.csv`. ✓
Defects:

- Label collisions (the ones you spotted, plus more): "0.95·k4 Sweet spot" is
  overprinted by the "FoS jumps 3.9→30.7" annotation; "0.90·k6 Safest" collides with
  the red dashed bifurcation branch; "Power-limited (k-adaptive)" is overprinted by
  the "FoS dips to 3.5" warning; "FoS 11.9"/"FoS 4.0" collide at the right edge; the
  legend box covers the 5–7 m/s x-tick labels.
- **Physics contradiction in the chart itself**: the grey "Below cut-in" zone extends
  to 7 m/s, but the red 1.10·k4 curve shows 65 kW at 7 m/s — above the 50 kW gate,
  inside the "below cut-in" shading. Either cut-in is ~5.5–6 m/s (blade-dependent) or
  the shading is wrong.
- The 657 kW bifurcation point stretches the y-axis and squashes the 0–300 kW region
  where all the real content lives. Consider clipping at 450 with a broken-axis marker
  for the bifurcation, or a log-y inset.
- Subtitle says "45s sim per point"; every catalog chart says "30s MPPT". Combined
  with cross-cutting #3, state on the chart which settle path / duration produced each
  curve.
- **Geometry mislabel (see cross-cutting #3 root cause):** the curves are r_bottom=1.00
  geometry but carry the r=1.30 catalog design names. Relabel with the ʳ convention or
  re-run at r=1.30 — as drawn, "Sweet spot" on this chart is a different machine than
  "Sweet spot" in the design cards.
- The purple dashed "power-limited (k-adaptive)" 50 kW line is an analytical estimate
  with no CSV behind it (`power_curve_quick.csv` is empty). Label it "analytical
  estimate — sim pending" or drop it.

### fig4 (P vs ω, catalog + kickstart) — right story, failed execution

This is the only chart that shows the discovery (kickstart-recovered designs, two
regimes), but it's overloaded past legibility:

- The pale-pink "kickstart" rectangle floods the entire left half, reading as
  "everything below 290 rpm needs kickstart" — only k=2 does. The blue and pink family
  ellipses overlap it and each other; the "λ=0.85 family" label sits nowhere near its
  ellipse; "λ=0.95 family" text is buried under a red point.
- Both callout boxes overflow their frames; the legend's bottom row renders garbled
  ("2.5–4 ●<2.5 ³·⁵ = 3.5mm" collide).
- The dashed red line at P=50 kW is labelled "FoS≈1.5 structural floor" — that
  conflates the power gate with the FoS gate. A horizontal power line cannot encode an
  FoS boundary; this is wrong, not just cluttered.
- Label pile-ups at (315–360 rpm, 110–160 kW): 1.05³·⁵/0.75, 1.10³·⁵/0.69/0.85.
- Failed points (grey open circles) are nearly invisible, yet "the catalog is a lower
  bound" is the whole point.

**Recommendation:** split into two charts — (a) a clean P–ω regime map: FoS colour,
k-shape, kickstart wedge attached only to k=2 triangles, max 3 callouts, no ellipses;
(b) a dedicated settle-bug chart (below).

---

## Missing charts — the discovery story you're not showing

The PRD specced **fig1** (power vs blade scale, two-regime) and **fig3** (k×λ viability
heatmap with settle-blind hatching) and neither was ever built. Fig3 in particular is
the single best visual for the campaign's core finding. In priority order:

1. **Settle-bug dumbbell (before/after)** — one row per (λ, k), catalog P vs kickstart
   P joined by an arrow: 0.85·k2: 4.9 → 156 kW; 0.85·k14: 18 → 107; 0.80·k6: 15 → 134;
   0.80·k4: 0.2 → 131. Caption: "the catalog is a lower bound on viability." This is
   the discovery narrative in one chart, currently told only in fig4's footnotes.
2. **fig3 viability heatmap** (as specced) — k × λ grid, green power gradient, hatched
   settle-blind zone, kickstart overrides marked. Shows the viable corridor AND the
   unexplored frontier at a glance.
3. **Multi-equilibrium explainer** — P_aero(ω) and P_gen = k·ω³ curves for 0.90·k6,
   showing both intersections: 168 rpm/81 kW (catalog branch) and 323 rpm/204 kW
   (wind-sweep branch). Turns cross-cutting problem #3 from an embarrassment into the
   physics insight, and explains the power-curve "bifurcations" with the same picture.
4. **Design-target overshoot (the 50 kW story)** — every viable design produces 70–297
   kW at 11 m/s against a 50 kW rating; the DE optimizer, compensating for the 3.3×
   load under-prediction, oversized the rotor (gate1 plan, §2). A rated-line chart with
   rated-crossing wind per design connects this figure set to the scaling-rebuttal work.
   Blocked on the Gate-1 re-run.
5. **fig1 power vs blade scale** — nice-to-have once 1–2 exist; much of its content is
   covered by the heatmap.

## Suggested execution order

1. Delete `chart-eff.png`; drop `chart-mass-origin` from the set.
2. Rename "V10 Tight" → "V10-Spoke" in the three .tex files + phase-e header.
3. Re-run catalog + kickstart sweeps (local machine — needs Julia), commit the CSVs,
   re-stamp provenance boxes. Everything downstream depends on this.
4. Reconcile or footnote the catalog-vs-wind-sweep discrepancies (0.90·k6 especially).
5. Merge fig2 + chart-structural-efficiency into one FoS–P chart; merge
   design-landscape-scatter into a rebuilt fig4a; fix power-curve labels/cut-in zone.
6. Build the dumbbell chart and fig3 heatmap.
