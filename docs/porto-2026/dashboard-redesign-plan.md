# Dashboard Redesign Plan — "Dashboard-new"
# 2026-06-28

## Current Issues

The dashboard (`src/visualization.jl`, 1805 lines) has grown organically. Controls are
scattered in definition order rather than grouped by function. Key problems:

1. **Slider for V10 capped at 200** (fixed 2026-06-28 → 10:600)
2. **No Kp slider** — controller gain is auto-computed from power ratio, no user control
3. **k_mppt label unclear** — "MPPT gain k_mppt" doesn't explain τ = k·ω²
4. **Controls scattered** — run params, auto-ramp, depower, structural all interleaved
5. **No visual hierarchy** — everything at same font size/weight
6. **State indicator buried** — controller state label is small, easy to miss
7. **60% of sliders not used in typical session** — clutter

## Proposed Layout — Logical Grouping

```
┌──────────────────────────────────────────────────┐
│ DASHBOARD CONTROLS                    [collapse] │
├──────────────────────────────────────────────────┤
│                                                    │
│ ┌─ CONFIG ────────────────────────────────────┐   │
│ │ Config: [dropdown]  Wind: [slider 0.1-20]   │   │
│ │ Scenario: [run] [depower] [stop]            │   │
│ │ Status: ✓ Canonical 5-line complete (3000)  │   │
│ └──────────────────────────────────────────────┘   │
│                                                    │
│ ┌─ GENERATOR CONTROL ─────────────────────────┐   │
│ │ k_load = k · ω²  [========○================]│   │
│ │         555.0 N·m·s²/rad²                    │   │
│ │                                               │   │
│ │ ☐ Auto-Ramp k   State: HOLDING               │   │
│ │   Ramp speed Kp: [=====○====================]│   │
│ │   Target power:  50.0 kW                     │   │
│ └──────────────────────────────────────────────┘   │
│                                                    │
│ ┌─ STRUCTURAL GUARDS ─────────────────────────┐   │
│ │ Ring buckling FoS soft limit: [==○==========]│   │
│ │                       2.5 (taper below)       │   │
│ │ Ring buckling FoS hard floor: [=○===========]│   │
│ │                       1.5 (freeze at)         │   │
│ └──────────────────────────────────────────────┘   │
│                                                    │
│ ┌─ GEOMETRY (click to expand) ────────────────┐   │
│ │ Elevation β:  [===========○================] │   │
│ │ (advanced: tether L, ring radii, n_lines)    │   │
│ └──────────────────────────────────────────────┘   │
│                                                    │
│ ┌─ DEPOWER (click to expand) ────────────────┐    │
│ │ Generator mode: [Standard ▼]                 │   │
│ │ Winch payout:   [15m Baseline ▼]             │   │
│ │ ☐ Active winch  ☐ MPPT stall  ☐ Field IMU   │   │
│ └──────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────┘
```

## Key Changes

### 1. Generator Control — unified panel
- **Rename**: "MPPT gain k_mppt" → "Generator load k (τ = k·ω²)"
- **Slider**: already extended to 600 for V10
- **Auto-Ramp toggle**: stays, but state indicator enlarged and colour-coded:
  - IDLE → grey
  - RAMPING → amber pulsing
  - HOLDING → green steady
- **NEW: Kp slider** — user-adjustable ramp gain instead of auto-computed
  - Range: 1e-5 to 1e-2, log scale
  - Default: computed from power ratio as before
  - Label: "Ramp speed Kp (Δk per W·s)"

### 2. Structural Guards — own panel
- FoS soft limit slider (currently inline)
- FoS hard floor slider (currently inline)
- Tulloch collapse margin threshold (add slider, currently hardcoded 5°)
- Live FoS readout: "current min FoS = 12.3" in green/amber/red

### 3. Collapsible sections
- Geometry and Depower are advanced — collapse by default
- Reduces visual clutter for routine operation
- "Click to expand" pattern keeps power users happy

### 4. Visual hierarchy
- Panel headers: bold, 12pt, with subtle background fill
- Primary controls: 11pt
- Secondary labels: 9pt, grey
- State indicator: 14pt, colour-coded, positioned prominently

### 5. HUD data integration
- Live structural readouts in the guards panel:
  - "min FoS = 12.3" (green if >2.5, amber 1.5-2.5, red <1.5)
  - "collapse margin = 43.2°" (green if >10°, amber 5-10°, red <5°)
  - "T_max = 2.4 kN"
- These update in real-time during simulation, not just at frame capture

## Implementation Plan

### Phase A — Reorganise existing controls (1-2 hours)
1. Group controls into panels as shown above
2. Move structural sliders into their own section
3. Enlarge state indicator, add colour coding
4. Rename k_mppt label

### Phase B — Add new controls (1 hour)
1. Kp slider with log scale
2. Collapse margin threshold slider
3. Live FoS/margin/T_max readouts in guards panel
4. Collapsible sections for Geometry and Depower

### Phase C — Visual polish (1 hour)
1. Panel headers with background fills
2. Consistent font hierarchy
3. Colour-coded state indicator with pulse animation
4. Tooltip-style help text on hover (if Makie supports it)

### Phase D — Test and iterate
1. Verify all existing functionality preserved
2. Test with canonical 10kW, V10 Tight, V5, V6 configs
3. Test auto-ramp with new Kp slider
4. Test with and without expansion rotors

## Files to Modify
- `src/visualization.jl` — main dashboard layout (lines ~1500-1700 for controls section)
- No new files needed — pure reorganisation

## Not Doing (deferred)
- Real-time HUD data during simulation (requires callback hook into Makie render loop)
- Touch/gesture support
- Dark mode toggle (use system theme)
