# KiteTurbineDynamics.jl — Dashboard Content Specification

**Date:** 2026-03-17
**Applies to:** `scripts/interactive_dashboard.jl` + `src/visualization.jl`
**Reference implementations:**
- `TRPTKiteTurbineJulia2/src/visualization.jl` — rich HUD and force colouring
- `TRPTKiteTurbineJulia2/scripts/interactive_multibody.jl` — scenario controls, CSV export
- `KiteTurbineDynamics.jl` — rope node geometry, individual line physics, structural safety

---

## Layout

```
┌─────────────────┬──────────────────────────────────┬───────────────────┐
│  CONTROLS       │                                  │  HUD              │
│  (left, 280px)  │        3D VIEWPORT               │  (right, 340px)   │
│                 │        (centre, fills)            │                   │
│                 │                                  │                   │
│                 │                                  │                   │
│                 │                                  │                   │
└─────────────────┴──────────────────────────────────┴───────────────────┘
```

Dark theme (`theme_dark()`). Figure size 1600×900 minimum.

---

## 1 — 3D Viewport

### 1.1 Tether Lines

Each of the 5 lines per inter-ring segment is drawn individually through its rope nodes:

```
points per line = [attach_A, rope_sub_1, rope_sub_2, rope_sub_3, attach_B]
```

That is 75 tether lines total (5 × 15 segments), each rendered as a 5-point polyline.

**Colouring — tension ratio vs SWL (3500 N):**

| Ratio t/SWL | Colour |
|---|---|
| 0.0 | Blue `RGBf(0.0, 0.2, 1.0)` |
| 0.5 | Green `RGBf(0.0, 0.8, 0.2)` |
| 0.8 | Orange `RGBf(1.0, 0.5, 0.0)` |
| ≥ 1.0 | Red `RGBf(1.0, 0.0, 0.0)` |
| slack (T < 5 N) | Light grey `RGBf(0.6, 0.6, 0.6)` — line is slack |

Line width: 1.5 px for tether lines. Slack lines: 0.8 px, dashed style.

Per-line tension is derived from the most recently computed sub-segment spring force
at the attachment points (maximum tension among the 4 sub-segments of that line).

### 1.2 Ring Polygons

One closed polygon per tensegrity ring , connecting the attachment points
of the upper face of each segment in order `[j=1, 2, 3, 4, 5, 1]`.

**Colouring — hoop compression utilisation vs Euler buckling limit:**

| Utilisation | Colour |
|---|---|
| 0.0 | Blue |
| 0.5 | Cyan |
| 0.8 | Orange |
| ≥ 1.0 | Red — buckling threshold exceeded |

Line width: 1.5 px.

### 1.3 Rotor Ring

The ring at the hub (top of TRPT shaft): same polygon as other rings but rendered
distinctly.

- Colour: `firebrick`
- Line width: 3.5 px

### 1.4 Rotor Blades

Quad outline per blade (n_blades = 6), drawn as `[corner1, 2, 3, 4, 1]`.

- Colour: `steelblue`
- Line width: 2.5 px

Blade geometry: inner radius at TRPT hub radius (30% inboard extension), outer radius
at rotor_radius, chord = rotor_radius × 0.15. Blade plane perpendicular to shaft axis.

### 1.5 Lift System — Bridle and Lift Line

**Bridle lines** — one line per TRPT line (5 lines), from each top-ring attachment
point to the bearing point on the shaft axis:

```
bearing_pos = hub_centre + 1.5 × seg_len × shaft_dir
```

- Colour: `gold`
- Line width: 1.2 px

**Lift line** — single line from bearing to lift point:

```
lift_pos = bearing_pos + 1.0 × shaft_dir
```

- Colour: `gold`
- Line width: 3.0 px

**Markers:**
- Bearing point: gold scatter, markersize 12
- Lift point (where kite force applies): white scatter, markersize 10

### 1.6 Ground Anchor

- Lime green scatter at `[0, 0, 0]`, markersize 20

### 1.7 Wind Arrow

Arrow from `hub_pos - v_wind_vec` to `hub_pos`, scaled so that 1 m/s = 1 m.
- Colour: `darkorange`, line width 3
- Orange scatter dot at tip (hub), markersize 10

### 1.8 Ground Plane Grid

Grid lines at z = 0 from −20 to +60 m (x), −25 to +25 m (y), 5 m spacing.
- Colour: `(:grey, 0.3)`, line width 0.5

### 1.9 Axis Labels and Camera

- Axis labels: `"Downwind X [m]"`, `"Crosswind Y [m]"`, `"Altitude Z [m]"`
- `aspect = :data`
- Dynamic camera limits: auto-fit to node positions with 40% padding, updated on Reset View
- Azimuth rotation applied to shaft_dir and all geometry when azimuth slider changes
  (visual only — physics always head-to-wind)

---

## 2 — HUD Panel (right column)

### 2.1 Live Telemetry

Updated every frame scrub.

```
── Live Telemetry ─────────────────────
Time          t =   XX.XX s
Wind at hub   V =    X.XX m/s
Output power  P =   XX.XX kW  (XX% rated)
Rotor speed   ω =  X.XXX rad/s  (XX.X rpm)
Tip speed ratio  λ =  X.XX
Elevation     β =  XX.X°
Kite          CL = X.XX  CD = X.XX
```

### 2.2 Structural Loads — Live Frame

```
── Structural Loads (this frame) ──────
Tether tension
  max  XXXX N · FoS  X.X   [colourbar 0 → 3500 N SWL]
  min   XXX N
Ring hoop compression
  max   XXX N · FoS  X.X   [colourbar 0 → 500 N P_crit]
  worst ring utilisation  XX.X %
```

Two horizontal colourbars (blue→red, height 14px):
- Tether: 0 N (blue) → 3500 N SWL (red)
- Ring: 0 N (blue) → P_crit / ring (red, labelled as "buckling limit")

### 2.3 Warning Flags

Displayed in bold, visible only when condition is true:

```
!! TORSIONAL COLLAPSE     (red)    — any line tension < 2 N (effectively slack)
!! BUCKLING RISK          (orange) — any ring utilisation > 80%
!! LINE SLACK: N lines    (yellow) — count of lines with T < 5 N
```

### 2.4 Run Peaks (all frames, updated after each solve)

```
── Run Peaks ──────────────────────────
P_peak     XX.XX kW
ω_peak    X.XXX rad/s  (XX.X rpm)
T_peak     XXXX N · FoS  X.X
C_peak util  XX.X %
V_peak      X.XX m/s
Slack events: N frames with ≥1 slack line
```

### 2.5 Sag Indicators (per segment, compact table)

Below run peaks, a compact readout of mid-segment sag for each of the 15 segments:

```
── Sag (mid-rope node vs straight line) ──
Seg  1:  XX mm    Seg  2:  XX mm   ...
```

Sag = distance from rope sub_idx=2 node to the straight line between ring A and ring B
attachment points for line 1 (representative). Units: mm for small values, cm for large.

---

## 3 — Controls Panel (left column)

### 3.1 Parameter Sliders

```
── Parameters ──────────────────────────
Wind speed V_ref (m/s)   [0 – 25, step 0.5]
k_mppt               [1 – 50, step 1]
Kite CL              [0.5 – 2.5, step 0.05]
Kite CD              [0.01 – 0.5, step 0.01]
Elevation β (deg)    [15 – 70, step 1]
Wind direction φ (deg) [0 – 360, step 1]  ← visual only label
```

Each slider shows current value as a live label beside it.

### 3.2 Scenario Buttons

```
── Scenarios ───────────────────────────
[Run: Steady    ]   (darkgreen)
[Run: Ramp-Down ]   (darkorange)
[Run: Ramp-Up   ]   (steelblue)
[Run: Gust      ]   (firebrick)
[Run: Launch    ]   (mediumpurple)  ← starts from zero wind, ramps to V_ref
[Run: Land      ]   (saddlebrown)   ← ramps from V_ref to cutout wind then zero
```

**Launch scenario:** wind starts at 0 m/s, ramps linearly to V_ref over 30 s,
holds for 30 s. Hub omega seeded at 0. Tests sag-to-taut transition.

**Land scenario:** wind starts at V_ref, ramps linearly down to 3 m/s over 30 s,
then drops to 0 over 10 s. Tests controlled descent, progressive line sag.

### 3.3 Playback

```
── Playback ────────────────────────────
Frame  [slider 1 – N_frames]
[▶ Play]  [|| Pause]   Speed: [0.5× · 1× · 2×]
```

Play button toggles. Speed selector controls frame advance rate (sleep interval).

### 3.4 Actions

```
── Actions ─────────────────────────────
[Export Force CSV    ]   (purple)
[Export Node CSV     ]   (darkslateblue)
[Reset View          ]   (grey40)
[Re-run ODE  🔒]  ← unlock toggle beside it
```

**Export Force CSV** — per-node force residuals at current frame (existing behaviour).

**Export Node CSV** — per-node positions, velocities, line tensions at current frame.
Columns: `node_id, type, x, y, z, vx, vy, vz, tension_N` (tension = 0 for ring nodes).

---

## 4 — Colour Reference Summary

| Element | Colour | Width/Size |
|---|---|---|
| Tether lines — slack | `RGBf(0.6,0.6,0.6)` dashed | 0.8 px |
| Tether lines — tensioned | blue→green→orange→red (tension/SWL) | 1.5 px |
| Ring polygons | blue→orange→red (utilisation) | 1.5 px |
| Rotor ring | `firebrick` | 3.5 px |
| Rotor blades | `steelblue` | 2.5 px |
| Bridle lines | `gold` | 1.2 px |
| Lift line | `gold` | 3.0 px |
| Bearing marker | `gold` scatter | size 12 |
| Lift point marker | `white` scatter | size 10 |
| Ground anchor | `limegreen` scatter | size 20 |
| Wind arrow | `darkorange` | 3.0 px |
| Ground grid | `(:grey, 0.3)` | 0.5 px |

---

## 5 — Operational States the Dashboard Must Clearly Show

The layout and colouring must be legible in all of these states:

| State | Key visual signatures |
|---|---|
| Rated wind, generating | Lines taut, green/orange, rings blue, blades spinning |
| Low wind, barely generating | Lines lighter tension (bluer), slight sag visible |
| Zero wind / ground handling | Multiple lines grey/slack, rings drooped, significant sag |
| Gust peak | Lines spike orange/red briefly, ring compression rises |
| Launch (ramp-up) | Transition from sagged to taut, visible line straightening |
| Land (ramp-down) | Reverse of launch — lines progressively going slack |
| Torsional collapse | Lines go grey (slack) around affected segments, warning fires |
| Buckling risk | Affected ring polygon turns orange/red |

---

## 6 — What Was in Previous Dashboards That Must Not Be Lost

Items from `TRPTKiteTurbineJulia2` that must be preserved or improved upon:

| Feature | Old source | Status in new |
|---|---|---|
| Per-segment tension force colouring | `visualization.jl` line 60–79 | Required — now per individual line |
| Ring compression colouring | `visualization.jl` line 83–96 | Required — now uses ring FoS |
| Tether SWL colorbar | `visualization.jl` line 202–205 | Required |
| Ring SWL colorbar | `visualization.jl` line 212–214 | Required (relabelled as P_crit) |
| Run-wide peaks panel | `visualization.jl` line 217–278 | Required |
| ω in rad/s + RPM | `visualization.jl` line 243 | Required |
| Collapse margin % | `visualization.jl` line 245 | Required (rephrase as "XX% margin to collapse") |
| Elevation β live update during playback | `visualization.jl` line 324–328 | Required |
| Azimuth slider (visual yaw) | `visualization.jl` line 299–316 | Required |
| Play/Pause button | `visualization.jl` line 339–353 | Required |
| Bearing + lift point markers | `visualization.jl` line 162–169 | Required |
| Dynamic camera limits | `interactive_utils.jl` line 14–28 | Required |
| Export Force CSV | `interactive_multibody.jl` line 551–566 | Required |
| Wind vector at hub | `interactive_multibody.jl` line 425–444 | Required |
| Scenario buttons (Steady/Ramp/Gust) | `interactive_multibody.jl` line 317–320 | Required + Launch/Land added |
| Kite CL/CD sliders | `interactive_multibody.jl` line 307–310 | Required |

---

## 7 — Performance Notes

- All `Observable` geometry is pre-allocated at startup. No arrays created per frame.
- Rope node positions are read directly from `sol.u[fi]` — no recalculation.
- Line tensions are computed once per frame in a single pass over `sys.sub_segs`.
- Ring safety indicators (`ring_safety_frame`) computed per frame during `update_frame!`.
- Colourbars are static (limits fixed at SWL / P_crit) — no rescaling during playback.
- Play loop uses `sleep(1/30 / speed_factor)` — non-blocking async task.
