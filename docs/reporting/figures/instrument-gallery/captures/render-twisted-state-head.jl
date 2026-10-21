# render-twisted-state-head.jl — the Figure 12 bottom-left cell at HEAD.
#
# The capability page's bottom-left cell shows the live dashboard's 3D scene
# in the settled, twisted operating state: operating tension on the tether
# lines and hoop compression on the intermediate ring polygons, both by the
# dashboard's own colour scales. It renders the dashboard's own scene — the
# same code path as the interactive dashboard, nothing re-drawn by hand — with
# the window sized so the 3D viewport carries the cell's 85:59.89 aspect. No
# value is taken from the frame.
#
# Run:
#   julia --project=. docs/reporting/figures/instrument-gallery/captures/render-twisted-state-head.jl
#
# Outputs, in this directory:
#   dashboard-twisted-window-head.png  4074 x 1900 px  the whole dashboard
#                                     window at px_per_unit = 2 (raw render)
#   dashboard-twisted-state-head.png  2696 x 1900 px  the 3D viewport, cut
#                                     by crop-twisted-cell.py at measured
#                                     ink boundaries (613 .. 3308 device px),
#                                     ~806 dpi at the 85 x 59.89 mm cell
#
# State: the canonical 10 kW system settled at V = 11 m/s — the same settle
# as the v1/v2 frames, read from no CSV. The window places the viewport
# column at 1367 x 950: the sliders overflow their fixed 300 px column by
# 6 logical px and the HUD text anchors 23 device px inside its own edge, so
# 1367 is the width that leaves a chrome-free 2696 px span to cut on
# (aspect 1.41895 against the cell's 85/59.89 = 1.41927, 0.02%).
#
# No close(fig): GLMakie teardown raised inside LibGit2/FileWatching on this
# machine after the PNG was written (recorded in the capability-sheet
# renderer). The process exit releases the window.

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "..", "..", "..", ".."))

using KiteTurbineDynamics, GLMakie, LinearAlgebra, SHA

const OUTDIR = @__DIR__
const OUT    = joinpath(OUTDIR, "dashboard-twisted-state-head.png")

# Window geometry: 300 px control column + 3D viewport + 370 px HUD column
# (the dashboard's fixed widths). 950 tall, viewport column 1367 x 950.
# 1367 and not the nominal 1348: the slider tracks overflow the fixed 300 px
# control column by 6 logical px and the HUD text anchors 23 device px inside
# its own column edge, so this is the width that leaves a chrome-free span of
# exactly 2696 device px — the cell — between the two ink boundaries.
const CTRL_W = 300
const HUD_W  = 370
const VW_H   = 950
const VW_W   = CTRL_W + HUD_W + 1367

println("Loading 10 kW system parameters...")
p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
ld = rotary_lifter_default()

println("Settling system to operational state at V=11 m/s...")
wind_fn = (pos, t) -> begin
    z = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0 / 7.0)
    [p.v_wind_ref * sh, 0.0, 0.0]
end
u_start = settle_to_operational_state(sys, u0, p, 9.5; lift_device = ld, wind_fn = wind_fn)

# Receipt numbers: the settled operating state the frame pictures.
sf   = capture_frame(u_start, sys, p, 0.0, wind_fn, nothing)
pk   = capture_peaks([sf])
N    = sys.n_total
Nr   = sys.n_ring
a_hub = u_start[6N + sys.nodes[sys.ring_ids[Nr]].ring_idx]
a_pto = u_start[6N + sys.nodes[sys.ring_ids[1]].ring_idx]
println("state  twist Δα = $(round(rad2deg(a_hub - a_pto), digits=2))° (hub − PTO)")
println("state  T_peak = $(round(pk.T_peak, digits=1)) N (SWL $(Int(TETHER_SWL)) N)")
println("state  ω_hub  = $(round(pk.omega_peak, digits=3)) rad/s")
println("state  P      = $(round(pk.P_peak / 1000, digits=2)) kW")

println("Building the dashboard (window $(VW_W) x $(VW_H))...")
fig, _cfg = build_dashboard(
    sys, p, [u_start];
    times = [0.0], u_settled = u_start, wind_fn = wind_fn,
    config_name = "Canonical 5-line",
    figsize = (VW_W, VW_H),
)

# The 3D viewport is the dashboard's scene; the figure holds exactly one.
ax3ds = [c for c in fig.content if c isa Axis3]
length(ax3ds) == 1 || error("expected one Axis3 in the dashboard figure, found $(length(ax3ds))")
ax3d = ax3ds[1]

println("Saving the dashboard window at px_per_unit = 2 ...")
FULL = joinpath(OUTDIR, "dashboard-twisted-window-head.png")
save(FULL, fig; px_per_unit = 2.0)
b_full = read(FULL)
println("full window $(FULL)")
println("full bytes  $(length(b_full))")
println("full sha256 $(bytes2hex(sha256(b_full)))")

# The cell is cut from the window by crop-twisted-cell.py (tracked beside
# this script): the cut lands on the measured ink boundaries, so every pixel
# the scene draws prints and neither the control nor the readout strip does.
println("Run crop-twisted-cell.py to cut the cell.")
