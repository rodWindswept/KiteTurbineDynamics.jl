# PRD — KTD.jl Reporting Chart Standards

**Status**: Draft v0.1
**Date**: 2026-07-04
**Owner**: Rod Read
**Scope**: Chart standards for (a) the public scaling counter-analysis and (b) investor/partner material. Internal diagnostic plots may use these standards but are not bound by them.
**Toolchains**: Toolchain-neutral spec (this document + `charts/chart-spec.toml`), with thin implementations in Makie (`charts/theme.jl`) and matplotlib (`scripts/chart_style.py`, run via `/usr/bin/python3`).

---

## 1. Why this exists

The 2026-07-04 investigation produced findings that will be published against a hostile-scrutiny baseline (the "think garage" video rebuttal). The same day produced three chart-shaped failure modes that a standard must prevent:

1. **Unit ambiguity** — an rpm/rad-s slip made a correct result (20.3 kW) look inconsistent with P = k·ω³ for an hour.
2. **Sampling masquerading as physics** — three designs that happened to operate at the same ω made a possibly ω-dependent loss look like a load-dependent "efficiency collapse" (87% → 45%).
3. **Defensible number, indefensible visual story** — "shaft efficiency collapses with blade size" was true of the three points plotted and misleading about the mechanism.

Every published figure was also produced during a session that found five simulator integrity bugs. Charts must therefore carry **provenance** (what code, what commit, what data) and **confidence** (what has been validated against what) on the figure itself, because the audience for the rebuttal will not read the appendix — and shouldn't have to.

Principle: **a chart must survive the scrutiny we applied to the video, on its own, screenshotted out of context.**

## 2. Audiences

| Audience | Vehicle | Requirement |
|---|---|---|
| Public / technical AWE community | Counter-analysis doc, video response | Self-explanatory; caveats on-figure; every number traceable; adversarial-reader-proof |
| Investors / partners | Deck, one-pagers | Same honesty (Makani standard), curated selection; simpler annotation tier permitted but confidence badges never removed |

The same figure source generates both tiers via a `tier = :public | :investor` switch. Investor tier may drop provenance footers to a doc-level appendix but keeps confidence badges.

## 3. Core standards (toolchain-neutral)

### 3.1 Units
- Angular speed: **rad/s is canonical** in all data files and calculations. rpm appears only as a secondary (twin) axis of the same quantity — the one permitted dual-axis use.
- Power: kW. Force: kN. Torque: kN·m. Mass: kg. Wind speed: m/s. No mixed prefixes on one figure.
- Every axis label carries units in parentheses. No unitless axes except ratios, which state their definition ("η = P_ground / ΣP_aero").

### 3.2 Confidence encoding (the Makani standard, visualized)
Four tiers, encoded redundantly (line style + marker fill + badge), never by color alone:

| Tier | Meaning | Encoding |
|---|---|---|
| **H** hardware-validated | Measured on built hardware | solid line, filled marker, badge "H" |
| **M** model-cross-validated | Two independent models agree (e.g. BEM vs 2D blade-element per PLAN.md protocol) | solid line, half-filled marker, badge "M" |
| **P** provisional | Single simulation model, unvalidated | dashed line, hollow marker, badge "P" |
| **X** invalidated / superseded | Known-wrong, shown only for comparison (e.g. pre-settle-fix 172.7 kW) | dotted grey, × marker, badge "X" |

As of this writing **every KTD.jl result is tier P**. That is not a reason to hide the badge; it is the reason to show it.

### 3.3 Provenance footer (public tier, mandatory)
One line, small type, bottom-left of every figure:
`<script path> @ <git short-hash> · <data csv> · <model: e.g. V10/expansion-2D-constCL> · <date>`
A figure that cannot state its commit does not get published.

### 3.4 Consistency stamps
Figures displaying generator power at an operating point must display the closure check that today's debugging relied on:
- Power/ω figures: annotate `P/kω³ = 1.00 ✓` (or the actual ratio if ≠ 1, which is itself information).
- Energy figures: annotate closure residual `ΣP_aero − P_loss − P_gen = <x> kW (<y>%)`.
A stamp that fails is not cosmetics — it blocks publication of the figure.

### 3.5 Discriminating-variable rule
A quantity claimed to depend on X must be plotted against X **with X varying while confounders are held or shown**. The loss-vs-λ trap: if all λ points share the same ω, the figure must either include ω-varying points or carry the annotation "ω ≈ const across points; ω-dependence not excluded." Reviewer checklist item, not optional.

### 3.6 Color semantics
- Palette: Okabe–Ito (colorblind-safe), defined once in `chart-spec.toml`.
- **Design identity is a constant hue across all figures**: λ=1.0 (V10 Tight) = blue, λ=0.79 = orange, λ=0.69 = green, canonical 10 kW = grey. A reader who learns the colors in Figure 1 keeps them for the whole document.
- Pass/fail and thresholds use reserved colors (vermillion for limits/failures, black dashed for criteria lines like FoS = 1.5) never used for design identity.

### 3.7 Forbidden
- Truncated axes on FoS or safety-margin plots. FoS axes start at 0 and mark 1.5 explicitly.
- Trend lines or smoothing through < 5 points. Three points get three markers and no line, or a line explicitly labeled "interpolation aid, not fit."
- The word "efficiency" on any figure without its definition (numerator/denominator) in the caption or axis.
- Deleting tier-X history from comparison figures where it shaped decisions (e.g., the 172.7 → 193 kW gate drift is part of the integrity story and should be shown as such).

## 4. Figure inventory (the rebuttal set)

| ID | Figure | Axes | Key annotations |
|---|---|---|---|
| F1 | Power curve P(v), λ=0.69 | P (kW) vs v (m/s), 5–15 | 50 kW rated line; v³ reference curve below rated; shading "unregulated MPPT — conservative above rated"; tier P |
| F2 | FoS envelope | FoS vs v, designs λ=1.0/0.79/0.69 | FoS=1.5 floor (vermillion); published V10 Tight 15 m/s failure (tier X, ×-marker); FoS axis from 0 |
| F3 | Energy waterfall at rated | ΣP_aero → shaft loss → P_ground | closure residual stamp; loss bar badged "mechanism attribution ongoing"; η with definition |
| F4 | Static aero vs dynamics | P(ω) static curves + ODE operating points, per design | P/kω³ stamp at each ODE point; "static model: constant-CL, no induction" caveat |
| F5 | Blade-scaling law | P_ground and system mass vs λ² | provisional band; n=3 points, no fit line; m_blade-corrected masses only |
| F6 | Loss mechanism discriminator | P_loss vs ω (all runs, all designs) | constant-τ and constant-P reference curves; this figure answers §3.5 for F3 |
| F7 (investor) | Capacity factor vs site wind class | CF vs mean wind speed | built from F1 only after 5–9 m/s points land; cites wind distribution source |

F6 is the standard's own medicine: it exists because F3's loss number is currently unattributed.

## 5. Implementation

- `charts/chart-spec.toml` — colors, tier encodings, fonts, margins, badge text. Single source of truth; both toolchains read it.
- `charts/theme.jl` — Makie theme + helpers: `ktd_figure()`, `provenance_footer!()`, `confidence_badge!()`, `consistency_stamp!()`, `rpm_twin_axis!()`. Used by dashboard exports and campaign scripts.
- `scripts/chart_style.py` — matplotlib rcParams + the same four helpers, for figures embedded via the existing docx report-patching pipeline (`/usr/bin/python3`, idempotent like all report scripts).
- Export: SVG (source of truth) + PNG @2x, white background (matching GLMakie render convention). Minimum font size 9 pt at final layout size.

## 6. Acceptance checklist (per published figure)

1. Units on every axis; rad/s canonical; rpm only as twin axis
2. Confidence badge present and correct (currently: P everywhere)
3. Provenance footer resolves to a real commit and data file
4. Consistency stamp present and passing where applicable
5. Discriminating-variable rule satisfied or confounder annotated
6. Design hues match the global assignment; thresholds in reserved colors
7. Nothing from the Forbidden list
8. Screenshot test: figure + caption survives out-of-context posting

## 7. Out of scope (v0.1)

Dashboard live theming (dashboard_v2 has its own aesthetic doc), video motion graphics, LCOE waterfall (needs cost model), farm-level visuals. Revisit after the counter-analysis ships.
