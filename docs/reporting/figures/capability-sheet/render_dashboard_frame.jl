# render_dashboard_frame.jl — the dashboard frame for Figure 10.
#
# Figure 10 seats one render of the dashboard at HEAD beside seven drawn
# chart classes. This script is that render's generating script: it is
# the tracked home of `scratch/fd_render_head.jl`, which built the frame
# and then sat untracked, so the figure-provenance appendix's `Script
# commit` cell could not be filled.
#
# Run:
#   julia --project=. docs/reporting/figures/capability-sheet/render_dashboard_frame.jl
#
# Output: docs/reporting/figures/capability-sheet/dashboard-frame-full.png
#   Pinned at 2000 x 1188 px. The Figure is the dashboard's default
#   1600 x 950 logical units, saved at px_per_unit = 1.25, which is the
#   scale factor this machine renders at. The factor is passed
#   explicitly rather than inherited from the screen, so the pixel size
#   does not follow the display: an unset factor gave 2500 x 1485 when
#   asked for 2000 x 1188, measured before this script was pinned.
#
# The crop that seats on the sheet (966 x 708 at offset 401, 329) is
# applied by capability-sheet.py, which owns the sheet's geometry and
# records the crop's hash in the kit manifest.
#
# The frame reads the v1 interface. The v2 cockpit is opt-in (`--v2` at
# interactive_dashboard.jl) and is not what this capture shows.

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "..", "..", ".."))

using KiteTurbineDynamics, GLMakie, LinearAlgebra, SHA

const OUT = joinpath(@__DIR__, "dashboard-frame-full.png")
const PX = 1.25          # logical unit to pixel factor, pinned
const WANT = (2000, 1188)

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

println("Building the dashboard...")
fig, config_changed = build_dashboard(
    sys, p, [u_start];
    times = [0.0], u_settled = u_start, wind_fn = wind_fn,
    config_name = "Canonical 5-line",
)

# white background for report integration
fig.scene.backgroundcolor[] = to_color(:white)

println("Saving the frame at px_per_unit = $PX ...")
save(OUT, fig; px_per_unit = PX)
close(fig)

bytes = read(OUT)
println("saved $OUT")
println("bytes ", length(bytes))
println("sha256 ", bytes2hex(sha256(bytes)))
println("expected pixels ", WANT)
