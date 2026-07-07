# Phase D — Charts and Ramp Check (Exacting Spec)

**Status:** SPEC (2026-07-07)
**Feeds from:** `docs/gate2-map.md`, `scripts/results/control_maps/*.csv`
**Blocks:** Phase E (community report), Phase F (map overlays), Phase G (Zenodo)

## Data requirements

All charts consume the frozen Gate 2 envelope:
- `scripts/results/control_maps/gate2_reinforced_tmp_summary.csv` (local only)
- `scripts/results/control_maps/gate1_blade_scaled_069_maxpower_summary.csv` (local only)
- Timeseries CSVs for the stability exhibit

Script must be idempotent: run `julia --project=. scripts/gen_phase_d_charts.jl` →
all 6 charts in `docs/figures/`.

---

## Chart D1 — λ=0.69 Operating Map

**File:** `docs/figures/d1_lambda069_operating_map.pdf`
**Type:** 4-panel or 4 overlaid plots on shared x-axis (v_wind 5–15 m/s)

| Panel | Y-axis | Curve | Source column |
|-------|--------|-------|---------------|
| (a) | P (kW) | P_kw vs v_wind | `P_kw` |
| (b) | ω (rpm) | ω_rpm vs v_wind | `ω_rpm` |
| (c) | FoS | min_fos vs v_wind | `min_fos` |
| (d) | Spoke tension (N) | max_T_spoke_N vs v_wind | `max_T_spoke_N` (from post-process) |

**Annotations:**
- Horizontal dashed line at P_rated = 50 kW on panel (a)
- Horizontal dashed line at FoS = 1.5 on panel (c)
- Vertical grey band for deficit winds (v < 9 m/s)
- k_mppt value annotated at each operating point on panel (b)

**Post-processing needed:** spoke tension must be computed from the evaluator
with spokes enabled and expansion blade mass. Script `postprocess_gate2_spokes.jl`
provides this (requires debugging the force-per-vertex convention — see its
KNOWN BUG comment).

**Fallback:** if spoke post-processing is not yet functional, mark panel (d)
as a placeholder and note that spoke columns require the post-processor fix.

---

## Chart D2 — MPPT vs Neutral Overlay

**File:** `docs/figures/d2_mppt_vs_neutral.pdf`
**Type:** Single plot, ω (rpm) vs v_wind (m/s), two curves.

| Curve | Description | Source |
|-------|-------------|--------|
| ω_mppt(v) | Controller operating line | `ω_rpm` from Gate 2 envelope |
| ω_neutral(v) | Bisection on net radial load = 0 | `ω_neutral_tool.jl` |

**ω_neutral tool:** New script `scripts/omega_neutral.jl`. Per wind speed,
bisect ω until the evaluator returns `n_spokes_engaged == 0` or
`max_outward_N < 10 N (threshold)`. Output: CSV `omega_neutral.csv` with
columns `v_wind, ω_neutral, ω_mppt, gap_rpm, gap_pct`.

**Chart annotation:**
- Shade region between curves → label "Power reserve" (ω_mppt > ω_neutral)
  or "Fatigue margin" (ω_mppt < ω_neutral)
- Vertical line at the wind where gap crosses zero
- Text annotation: "Operating at ω_mppt leaves X% ω margin to neutral" at v=11 m/s

---

## Chart D3 — Spoke Tension vs ω

**File:** `docs/figures/d3_spoke_tension.pdf`
**Type:** T_spoke (N) vs ω (rpm), both designs on same axes.

| Curve | Design | Symbol |
|-------|--------|--------|
| T_spoke(ω) | λ=0.69 | Filled circles |
| T_spoke(ω) | Reinforced | Open squares |

**Annotations:**
- Horizontal dashed line at SWL = 19.8 kN
- Horizontal dashed line at caveat threshold = SWL / 1.5 ≈ 13.2 kN
- Label: "Caveat band" between the two lines
- Arrow pointing to the neutral crossing (T_spoke → 0 at low ω)

**Note:** requires spoke post-processing per D1.

---

## Chart D4 — Reinforced vs λ=0.69 Side-by-Side

**File:** `docs/figures/d4_design_comparison.pdf`
**Type:** 2-column, 3-row faceted plot.

| Row | Left (λ=0.69) | Right (Reinforced) |
|-----|---------------|-------------------|
| P vs ω | P_kw vs ω_rpm | P_kw vs ω_rpm |
| FoS vs ω | min_fos vs ω_rpm | min_fos vs ω_rpm |
| ω vs v | ω_rpm vs v_wind | ω_rpm vs v_wind |

Wind speed encoded as colour gradient on each scatter point.
k_mppt value as text label near each point.

**Annotation:**
- Single-paragraph callout: "λ=0.69: lighter, lower power, higher ω. Reinforced: heavier, more power, lower ω (larger k_mppt). Both hold FoS ≥ 2.0 at 15 m/s."

---

## Chart D5 — Ramp Trajectory (Fly-Light Validation)

**File:** `docs/figures/d5_ramp_trajectory.pdf`
**Type:** Parametric plot — (tension, ω) trajectory through the structural envelope.

**Data source:** `scripts/record_ramp_traces.jl` run on λ=0.69 with spokes enabled.
- Spin-up: ω=0 → ω_mppt at v=11 m/s (typical operating point)
- Spin-down: ω_mppt → 0

**Chart elements:**
- x-axis: ω (rpm), 0 → 300
- y-axis: Spoke tension (N), 0 → 25 kN
- Parametric curve: (ω(t), T_spoke(t)) during ramp — colour-coded by time
- Overlaid shaded regions:
  - Green: "Cruise band" — operating ω ± 10%
  - Red: "Envelope exceeded" — ω > ω_max (spoke FoS < 1.0 or ring FoS < 1.5)
  - Grey: "Startup/shutdown" — ω < 50 rpm
- Horizontal dashed line: SWL = 19.8 kN
- Vertical dashed line: ω at spoke FoS = 1.0
- Arrow annotation: "Ramp trajectory stays within envelope? Yes/No → fly-light sizing valid/invalid"

**Interpretation:**
- If ramp trajectory stays entirely within the envelope → fly-light sizing is
  cruise-bound. Mass saving is the gap between ramp and cruise load.
- If ramp trajectory exceeds the envelope → ramp case dominates sizing.
  Fly-light claim requires the ramp bound.

---

## Chart D6 — Stability Exhibit

**File:** `docs/figures/d6_stability_exhibit.pdf`
**Type:** 2-panel, shared time axis (t_sim 0–60 s).

| Panel | Content | Source |
|-------|---------|--------|
| Top | ω(t) and P(t) for λ=0.69 at v=15 m/s, k=6.23, 60s trace | `gate1_*_timeseries.csv` |
| Bottom | ω(t) and P(t) for V10 Tight at v=11 m/s, k=6.23, 60s trace | `diagnose_tight_transient.jl` output |

**Annotations:**
- Top panel: label "✓ STABLE — λ=0.69, range/P < 2%"
- Bottom panel: label "✗ UNSTABLE — V10 Tight, range/P > 20%"
- Grey overlay: final 20s window used for windowed-mean P
- Horizontal band: ±5% of P_mean on both panels → shows stability gate visually

**Purpose:** Demonstrate diagnostic discipline. The stable design is shown running
cleanly alongside the unstable one. The stability gate (5%) is visualised as a
band — not just stated as a number.

---

## Implementation

### Script: `scripts/gen_phase_d_charts.jl`

```julia
# Reads Gate 2 CSVs (via tmp copies in results/control_maps/)
# Produces all 6 chart PDFs in docs/figures/
# Dependency: Plots.jl + StatsPlots.jl (Makie optional)
```

### Script: `scripts/omega_neutral.jl`

```julia
# Bisection: find ω where n_spokes_engaged == 0 or max_outward_N < 10N
# Input: λ=0.69 builder, v_wind vector
# Output: omega_neutral.csv
```

### Script: `scripts/record_ramp_traces.jl`

```julia
# Already exists — run on λ=0.69 with spokes enabled
# Capture (ω(t), T_spoke(t)) during spin-up from ω=0 to ω_mppt
# and spin-down from ω_mppt to 0
# Output: ramp_trace.csv
```

---

## Blocking prerequisites

- [ ] Spoke post-processing debugged (force-per-vertex convention in evaluator)
- [ ] `omega_neutral.jl` written and run on λ=0.69
- [ ] `record_ramp_traces.jl` run on λ=0.69 with spokes enabled
- [ ] Plots.jl installed (check: `julia --project=. -e 'using Plots'`)

## Output checklist

- [ ] `docs/figures/d1_lambda069_operating_map.pdf`
- [ ] `docs/figures/d2_mppt_vs_neutral.pdf`
- [ ] `docs/figures/d3_spoke_tension.pdf`
- [ ] `docs/figures/d4_design_comparison.pdf`
- [ ] `docs/figures/d5_ramp_trajectory.pdf`
- [ ] `docs/figures/d6_stability_exhibit.pdf`
