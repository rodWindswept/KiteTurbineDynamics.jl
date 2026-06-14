# scripts/dashboard_redesign_prototype.jl
#
# ISOLATED redesign prototype for the interactive dashboard.
# Renders the locked redesign — A1 Instrument theme · B2 cockpit strip ·
# C2 gauges+sparklines · D2 dedicated loads panel · E1 grouped controls —
# using SAMPLE DATA only. Touches nothing in src/; the working
# build_dashboard in src/visualization.jl is untouched.
#
# Purpose: prove the GLMakie layout / gauge / panel look in isolation so we
# can iterate on look-and-feel from screenshots, THEN port the proven layout
# into build_dashboard reusing the existing (working) data wiring.
#
# Run:   julia --project=. scripts/dashboard_redesign_prototype.jl
#        (a GLMakie window opens; press Enter in the REPL/terminal to close)
#
# Status: v0 — NOT yet run/verified by Claude (no Julia execution available
#         this session). Expect to iterate. Report errors/screenshots back.

using GLMakie
using Printf

# ── A1 Instrument palette ───────────────────────────────────────────────────
const BG        = RGBf(0.039, 0.047, 0.063)   # near-black
const PANEL     = RGBf(0.071, 0.086, 0.114)
const PANEL2    = RGBf(0.086, 0.106, 0.141)
const EDGE      = RGBf(0.133, 0.165, 0.208)
const INK       = RGBf(0.910, 0.933, 0.965)
const INK_DIM   = RGBf(0.604, 0.655, 0.714)
const INK_FAINT = RGBf(0.392, 0.447, 0.518)
const ACCENT    = RGBf(0.224, 0.816, 0.847)    # cyan
const OK        = RGBf(0.204, 0.831, 0.600)
const WARN      = RGBf(0.961, 0.718, 0.239)
const ALARM     = RGBf(1.000, 0.302, 0.310)

# ── Helpers ──────────────────────────────────────────────────────────────────

"""Background panel: a Box placed in cell `gp`. Add content into the same cell after."""
function panel!(gp; color=PANEL, strokecolor=EDGE, strokewidth=1.0)
    Box(gp; color=color, strokecolor=strokecolor, strokewidth=strokewidth)
end

"""
Radial gauge in grid cell `gp`. `frac` ∈ [0,1] fills a 270° arc.
Draws a faint full-track arc, a coloured value arc, and centred value/label text.
"""
function gauge!(gp, frac::Real, value_str::AbstractString, label::AbstractString;
                color=ACCENT)
    ax = Axis(gp; aspect=DataAspect(), backgroundcolor=PANEL)
    hidedecorations!(ax); hidespines!(ax)
    limits!(ax, -1.25, 1.25, -1.25, 1.25)

    θ0 = deg2rad(225.0)          # start (lower-left)
    sweep = deg2rad(270.0)       # full sweep clockwise to lower-right
    n = 80
    # full track
    θ_track = range(θ0, θ0 - sweep; length=n)
    lines!(ax, cos.(θ_track), sin.(θ_track); color=EDGE, linewidth=7)
    # value arc
    f = clamp(Float64(frac), 0.0, 1.0)
    θ_val = range(θ0, θ0 - sweep * f; length=max(2, round(Int, n * f)))
    lines!(ax, cos.(θ_val), sin.(θ_val); color=color, linewidth=7)
    # centre text
    text!(ax, 0, 0.12; text=value_str, align=(:center, :center),
          fontsize=24, color=color, font=:bold)
    text!(ax, 0, -0.55; text=label, align=(:center, :center),
          fontsize=10, color=INK_FAINT)
    ax
end

"""Sparkline in grid cell `gp` from a vector of y-values."""
function sparkline!(gp, ys::Vector{<:Real}; color=ACCENT)
    ax = Axis(gp; backgroundcolor=PANEL, height=30)
    hidedecorations!(ax); hidespines!(ax)
    xs = collect(1:length(ys))
    lines!(ax, xs, Float64.(ys); color=color, linewidth=1.5)
    ax
end

"""Left-aligned label that fills its cell width (no jitter)."""
lbl!(gp, txt; kw...) = Label(gp, txt; halign=:left, tellwidth=false,
                             justification=:left, kw...)

# ── Figure ─────────────────────────────────────────────────────────────────
set_theme!(theme_dark())
fig = Figure(size=(1600, 950), backgroundcolor=BG, figure_padding=12)

# Two rows: cockpit strip (fixed height) + body
rowsize!(fig.layout, 1, Fixed(96))

# ════════════════════════════════════════════════════════════════════════════
# ROW 1 — B2 cockpit status strip
# ════════════════════════════════════════════════════════════════════════════
strip = GridLayout(fig[1, 1:3])
panel!(fig[1, 1:3]; color=PANEL2)

# state pill
state_gl = GridLayout(strip[1, 1])
panel!(strip[1, 1]; color=RGBf(0.071,0.157,0.118), strokecolor=OK)
lbl!(state_gl[1, 1], "● GENERATING"; color=OK, fontsize=16, font=:bold)

# operating-point metrics
metrics = GridLayout(strip[1, 2])
function strip_metric!(gp, label, value, sub; valcolor=INK)
    g = GridLayout(gp)
    lbl!(g[1, 1], label; color=INK_FAINT, fontsize=10)
    lbl!(g[2, 1], value; color=valcolor, fontsize=20, font=:bold)
    lbl!(g[3, 1], sub;   color=INK_DIM, fontsize=10)
end
strip_metric!(metrics[1, 1], "POWER",      "10.3 kW", "103% of 10.0 rated"; valcolor=WARN)
strip_metric!(metrics[1, 2], "ROTOR / PTO","91.1 rpm","PTO 93.3 rpm")
strip_metric!(metrics[1, 3], "TSR vs OPT", "4.34",    "λ_opt 4.10 · Cp 0.41")
strip_metric!(metrics[1, 4], "WIND",       "12.0 m/s","steady")

# D2 alarm zone (glanceable; full panel on right)
alarm_gl = GridLayout(strip[1, 3])
panel!(strip[1, 3]; color=RGBf(0.165,0.055,0.063), strokecolor=ALARM, strokewidth=1.5)
lbl!(alarm_gl[1, 1], "TETHER OVERLOAD"; color=ALARM, fontsize=10, font=:bold)
lbl!(alarm_gl[2, 1], "FoS 0.5"; color=ALARM, fontsize=24, font=:bold)
lbl!(alarm_gl[3, 1], "6460 N / 3500 N SWL · 90 slack"; color=RGBf(1.0,0.706,0.71), fontsize=10)

colsize!(strip, 1, Fixed(170))
colsize!(strip, 3, Fixed(230))

# ════════════════════════════════════════════════════════════════════════════
# ROW 2 — body: controls | viewport | diagnostics
# ════════════════════════════════════════════════════════════════════════════
body = GridLayout(fig[2, 1:3])
colsize!(body, 1, Fixed(240))
colsize!(body, 3, Fixed(330))

# ── LEFT: E1 grouped controls ────────────────────────────────────────────────
ctrl = GridLayout(body[1, 1])
panel!(body[1, 1])
crow = Ref(0); cnr!() = (crow[] += 1; crow[])

lbl!(ctrl[cnr!(), 1], "CONTROLS"; color=INK_DIM, fontsize=11, font=:bold)

function group_header!(gp, title)
    lbl!(gp, "▾  " * title; color=INK, fontsize=12, font=:bold)
end

group_header!(ctrl[cnr!(), 1], "Configuration")
Menu(ctrl[cnr!(), 1]; options=["Canonical 5-line","v5 octagon","v5-safe"], fontsize=12)

group_header!(ctrl[cnr!(), 1], "Lift device")
lbl!(ctrl[cnr!(), 1], "Area A — 28 m²"; color=INK_FAINT, fontsize=10)
Slider(ctrl[cnr!(), 1]; range=10:1:60, startvalue=28)
lbl!(ctrl[cnr!(), 1], "Aspect ratio B — 6.0"; color=INK_FAINT, fontsize=10)
Slider(ctrl[cnr!(), 1]; range=3:0.5:12, startvalue=6)

group_header!(ctrl[cnr!(), 1], "Control law")
Menu(ctrl[cnr!(), 1]; options=["MPPT (TSR track)","Constant torque"], fontsize=12)
tg = GridLayout(ctrl[cnr!(), 1])
lbl!(tg[1, 1], "Active winch"; color=INK, fontsize=11); Toggle(tg[1, 2]; active=true)
lbl!(tg[2, 1], "MPPT stall gov"; color=INK, fontsize=11); Toggle(tg[2, 2]; active=true)
lbl!(tg[3, 1], "Field IMU damp"; color=INK, fontsize=11); Toggle(tg[3, 2]; active=false)

group_header!(ctrl[cnr!(), 1], "Scenario")
Menu(ctrl[cnr!(), 1]; options=["Steady","Ramp","Gust","Launch","Land","Furl","Pitch depower"], fontsize=12)

group_header!(ctrl[cnr!(), 1], "Run & export")
brow = GridLayout(ctrl[cnr!(), 1])
Button(brow[1, 1]; label="Re-run ODE", buttoncolor=PANEL2)
Button(brow[1, 2]; label="Export", buttoncolor=PANEL2)

# ── CENTRE: viewport placeholder (real dashboard keeps the live Axis3) ────────
vp = GridLayout(body[1, 2])
panel!(body[1, 2])
ax = Axis(vp[1, 1]; backgroundcolor=PANEL, title="TRPT Kite Turbine — live 3D viewport",
          titlecolor=INK_DIM, titlesize=13)
hidedecorations!(ax); hidespines!(ax)
lbl!(vp[2, 1], "tension  0 → SWL → fail   (colour ramp legend here)";
     color=INK_FAINT, fontsize=10)
Colorbar(vp[3, 1]; colormap=cgrad([RGBf(0.231,0.510,0.965), OK, WARN, ALARM]),
         limits=(0, 3500), vertical=false, height=12, label="tether tension (N)",
         labelsize=9, ticklabelsize=8)

# ── RIGHT: C2 diagnostics (gauges + sparklines) + D2 loads ────────────────────
diag = GridLayout(body[1, 3])
drow = Ref(0); dnr!() = (drow[] += 1; drow[])

# Flight card
lbl!(diag[dnr!(), 1], "FLIGHT"; color=INK_DIM, fontsize=11, font=:bold)
flight = GridLayout(diag[dnr!(), 1])
panel!(diag[drow[], 1])
gauge!(flight[1, 1], 1.03, "103%", "power vs rated"; color=WARN)
fmeta = GridLayout(flight[1, 2])
lbl!(fmeta[1, 1], "10.3 / 10.0 kW"; color=INK_DIM, fontsize=11)
lbl!(fmeta[2, 1], "TSR 4.34  (opt 4.10)"; color=INK, fontsize=11)
lbl!(fmeta[3, 1], "twist 80.3°"; color=INK, fontsize=11)
sparkline!(diag[dnr!(), 1],
           [6,7,8,7.5,9,9.5,9,10,9.8,10.3,10.1,10.3]; color=ACCENT)

# D2 Loads card — FoS gauge + colourbars
lbl!(diag[dnr!(), 1], "STRUCTURAL LOADS   ⚠ FoS 0.5"; color=ALARM, fontsize=11, font=:bold)
loads = GridLayout(diag[dnr!(), 1])
panel!(diag[drow[], 1])
gauge!(loads[1, 1], 0.25, "0.5", "tether FoS"; color=ALARM)   # 0.5/2.0 design = 0.25 fill
lmeta = GridLayout(loads[1, 2])
lbl!(lmeta[1, 1], "tension 6460 N"; color=ALARM, fontsize=12, font=:bold)
lbl!(lmeta[2, 1], "ring buckling 0.1%"; color=OK, fontsize=11)
lbl!(lmeta[3, 1], "sag 3.4 mm"; color=INK, fontsize=11)
# tension colourbar with over-SWL marker
Colorbar(diag[dnr!(), 1]; colormap=cgrad([RGBf(0.231,0.510,0.965), OK, WARN, ALARM]),
         limits=(0, 3500), vertical=false, height=10,
         label="0 → SWL 3500 → fail (now 6460 N, over SWL)",
         labelsize=9, ticklabelsize=8)
lbl!(diag[dnr!(), 1], "FLAGS: slack 90 lines · tether > SWL · no torsional collapse";
     color=INK_DIM, fontsize=10)

# Expansion card — FORCE-FIRST readout (per Rod: radial force, not spread distance)
lbl!(diag[dnr!(), 1], "EXPANSION ROTOR"; color=INK_DIM, fontsize=11, font=:bold)
exp_card = GridLayout(diag[dnr!(), 1])
panel!(diag[drow[], 1])
lbl!(exp_card[1, 1], "F_radial (spreading)"; color=INK_FAINT, fontsize=10)
lbl!(exp_card[1, 2], "41.2 N"; color=ACCENT, fontsize=16, font=:bold, halign=:right)
lbl!(exp_card[2, 1], "F_axial (thrust)"; color=INK_FAINT, fontsize=10)
lbl!(exp_card[2, 2], "153 N"; color=INK, fontsize=13, halign=:right)
lbl!(exp_card[3, 1], "τ_drag"; color=INK_FAINT, fontsize=10)
lbl!(exp_card[3, 2], "2.1 N·m"; color=INK, fontsize=13, halign=:right)

# Run peaks card
lbl!(diag[dnr!(), 1], "RUN PEAKS  (500 frames)"; color=INK_DIM, fontsize=11, font=:bold)
peaks = GridLayout(diag[dnr!(), 1])
panel!(diag[drow[], 1])
lbl!(peaks[1, 1], "P peak 13.53 kW"; color=INK, fontsize=12)
lbl!(peaks[1, 2], "T peak 6460 N (FoS 0.5)"; color=ALARM, fontsize=12, halign=:right)
lbl!(peaks[2, 1], "slack events 500/500 (100%)"; color=ALARM, fontsize=12)

display(fig)
println("Redesign prototype window open. Press Enter to close.")
readline()
