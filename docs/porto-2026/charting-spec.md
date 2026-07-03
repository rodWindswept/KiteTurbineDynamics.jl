# Ramp Trace Charting Spec — AWEC 2026 Porto
#
# Goal: Publication-quality multi-panel figures that tell the full story of the
# soft-ramp k_mppt controller across all 6 test scenarios.  Each figure should be
# self-contained enough to stand alone in a paper appendix, and information-dense
# enough that a reviewer can verify every claim from the chart alone.
#
# Data available per CSV frame:
#   t, k_mppt, P_kw, omega_hub, omega_gnd, delta_omega,
#   min_fos, collapse_margin_deg, twist_deg, T_max_N, state
#
# Derived channels (computed in Python):
#   τ_gen    = k_mppt * ω_gnd²          — generator torque (N·m)
#   P_mech   = τ_gen * ω_gnd / 1000     — mechanical shaft power (kW)
#   ω_rpm    = ω_hub * 60 / (2π)        — hub speed (rpm)
#   Δω_rpm   = (ω_hub - ω_gnd) * 60/(2π) — slip (rpm)
#   FoS_margin = min_fos - 1.5          — distance to hard floor
#   k_sec_proxy = τ_gen / (twist_deg * π/180)  — approximate torsional stiffness (N·m/rad)

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 1 — MASTER DASHBOARD: Canonical 10 kW full-state comparison
# ═══════════════════════════════════════════════════════════════════════════
# 6-panel vertical stack, shared time axis, instant (red) vs soft-ramp (blue)
#
# Panel A: k_mppt — control action
#   - Left axis: k_mppt (N·m·s²/rad²)
#   - Overlay controller state transitions as background bands:
#     IDLE=grey, RAMPING=amber, HOLDING=green
#   - Annotation: "Controller holds at k_min=5 — P_target already met"
#
# Panel B: P_gen + P_mech — power
#   - Left axis: P_gen (kW) — solid lines
#   - Right axis: P_mech (kW) — dotted lines, slightly offset
#   - Dashed line at P_rated (10 kW) labelled "Rated 10 kW"
#   - Dashed line at 0.8*P_rated labelled "80% rated"
#   - Annotation at first crossing: "t_to_rated = 1.6s (soft-ramp)"
#
# Panel C: ω_hub + ω_gnd — speeds
#   - Solid: ω_hub, dotted: ω_gnd
#   - Shows generator slip visually
#   - Horizontal line at ω_idle threshold (5 rpm) labelled "IDLE→RAMP"
#
# Panel D: Δω — torsional slip
#   - Δω (rpm) = ω_hub − ω_gnd
#   - Captures the TRPT wind-up
#   - Annotate peak slip
#
# Panel E: Structural health
#   - min FoS (left axis) + T_max (right axis, kN)
#   - FoS intervention bands: soft-limit 2.5 (amber), hard-floor 1.5 (red)
#   - FoS < 2.5 zone shaded amber, FoS < 1.5 zone shaded red
#
# Panel F: TRPT state
#   - Total twist ΣΔα (°) — left axis
#   - Collapse margin min(δα* − |Δα|) (°) — right axis, green
#   - Dashed line at 5° freeze threshold
#
# Legend: single legend at top, "Instant step (k=11)" vs "Soft-ramp (k_min=5→HOLD)"
# Title: "Canonical 5-line 10 kW — Full-State Controller Comparison"
# Footer: "v_rated=11 m/s (wind shear), T_sim=60s, dt=4×10⁻⁵ s, save every 500 steps"

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 2 — MASTER DASHBOARD: V10 Tight 50 kW (same 6-panel layout)
# ═══════════════════════════════════════════════════════════════════════════
# Same layout as Figure 1 but for V10 Tight.
# Critical annotations:
#   - Panel B: "132 kW — 2.6× rated" with arrow to instant-step plateau
#   - Panel B: "171 kW — 3.4× rated" with arrow to soft-ramp endpoint
#   - Panel E: FoS < 1.0 zone shaded RED with "STRUCTURAL FAILURE" label
#   - Panel E: "FoS < 0.5 at t=10s — ring buckling"
#   - Panel F: Collapse margin stays above 35° — "Tulloch cliff not the limit here;
#     ring buckling (FoS) fails first"
# Title: "V10 Tight 50 kW — Full-State Controller Comparison"
# Footer: "49.2 kg, 3 expansion rotors, n_lines=3, rings=22.  v_rated=11 m/s, T_sim=90s"

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 3 — WIND RAMP TRIPTYCH: 7→14 m/s over 150s
# ═══════════════════════════════════════════════════════════════════════════
# 3-panel horizontal layout (side by side), each with shared wind ramp backdrop
#
# Panel A (left 1/3): Operating trajectory in (ω, P) space
#   - x: ω_hub (rpm), y: P_gen (kW)
#   - Color-coded by time (viridis colormap)
#   - Wind speed isolines at 7, 9, 11, 14 m/s (computed from Cp curve)
#   - Arrow annotations showing direction of time
#   - "Instant k=11 traces upper envelope; soft-ramp k=30 traces lower"
#
# Panel B (middle 1/3): Structural margin vs wind speed
#   - x: wind speed (m/s), y: min FoS
#   - FoS intervention bands as horizontal zones
#   - "Soft-ramp sacrifices power to preserve FoS above 2.5 until v≈11 m/s"
#   - "At v=14 m/s both strategies approach FoS floor"
#
# Panel C (right 1/3): Torsional state
#   - x: wind speed, y-left: total twist (°), y-right: T_max (kN)
#   - Shows TRPT loading builds with wind speed
#   - "Instant k=11: higher ω → more twist → more TRPT load"
#   - "Soft-ramp k=30: lower ω → less twist → structural relief"

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 4 — STRUCTURAL ENVELOPE: FoS vs k_mppt operating map
# ═══════════════════════════════════════════════════════════════════════════
# Scatter/contour plot synthesising all scenarios
#
#   x: k_mppt, y: P_gen / P_rated  (normalised power ratio)
#   Point size: ω_hub (rpm), Point color: min FoS (red=unsafe, green=safe)
#   Horizontal band: "Rated power ±10%" in green
#   Vertical band: "FoS ≥ 1.5" region highlighted
#   Overlap zone: "Safe Operating Region" annotated
#
# Data from both canonical and V10 Tight, distinguishable by marker shape.
# This is the money plot — shows at a glance whether any (k_mppt, P) combo is safe.

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 5 — FREQUENCY DOMAIN: Torsional spectrum
# ═══════════════════════════════════════════════════════════════════════════
# Welch PSD of T_max and twist_deg for each soft-ramp scenario
#
# Panel A: Canonical 10 kW — T_max PSD
# Panel B: V10 Tight 50 kW — T_max PSD
# Panel C: Canonical 10 kW — twist PSD
# Panel D: V10 Tight 50 kW — twist PSD
#
# Log-log axes.  Annotate dominant frequencies.
# Compare: does V10 Tight excite different torsional modes than canonical?
# Are there TRPT natural frequencies visible?

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 6 — CONTROLLER DIAGNOSTIC: State machine trace
# ═══════════════════════════════════════════════════════════════════════════
# Gantt-chart style view of controller state over time
#
# Panel A: Canonical 10 kW soft-ramp
#   - Horizontal coloured bars: IDLE (grey), RAMPING (amber), HOLDING (green)
#   - Overlaid: k_mppt trace, P_gen trace
#   - Annotate state transitions with timestamps
#
# Panel B: V10 Tight soft-ramp
#   - Same layout
#   - Annotate: "RAMPING — never reaches HOLDING (P overshoots)"
#   - Show FoS constraint activation (when struct_mult < 1.0)
#
# Panel C: Wind ramp soft-ramp
#   - Same layout
#   - Annotate: "HOLDING at k_max=30, P > P_target throughout"

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 7 — CROSS-SYSTEM COMPARISON: Bar chart of key metrics
# ═══════════════════════════════════════════════════════════════════════════
# Grouped bar chart, 6 scenarios × 4 metrics:
#   - P_final / P_rated  (normalised, target=1.0)
#   - min FoS / 1.5      (normalised, target ≥1.0)
#   - ω_final / ω_rated  (normalised)
#   - t_to_rated (s)     (absolute)
#
# Colour-code bars: green ≥ target, amber marginal, red < target
# This gives a one-glance health check of every scenario.
