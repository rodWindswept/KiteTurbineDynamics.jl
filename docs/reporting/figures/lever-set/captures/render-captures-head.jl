# render-captures-head.jl — Figure 11's interface captures at HEAD.
#
# The capability page (Figure 11) seats three interface captures in a strip:
# the Pluto notebook, the v2 cockpit, and the v1 dashboard. This script is
# their generating script. It draws no chart class and reads no campaign
# column; it renders the two Makie interfaces from the 10 kW canonical
# system at the commit this script is run from.
#
# Run:
#   julia --project=. docs/reporting/figures/lever-set/captures/render-captures-head.jl
#
# Outputs, in this directory:
#   dashboard-v1-head.png   2000 x 1188 px   v1 frame, px_per_unit = 1.25
#   dashboard-v2-head.png   1780 x 1180 px   v2 cockpit, px_per_unit = 1.0
#
# The v1 frame repeats the settings pinned by
# docs/reporting/figures/capability-sheet/render_dashboard_frame.jl (same
# V = 11 m/s settle, same px_per_unit) but writes here, so Figure 10's kit
# input keeps its recorded hash. The v2 cockpit takes a 1.0 s canonical run
# from the same settled state, because its panels read a frame series rather
# than a single frame; 50 frames at SAVE_EVERY = 500.
#
# Both are renders of the interface, not dataset reads. No value in the
# report is taken from either.
#
# No close(fig): GLMakie teardown raised inside LibGit2/FileWatching on this
# machine after the PNG was written (recorded in the capability-sheet
# renderer). The process exit releases the window.

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "..", "..", "..", ".."))

using KiteTurbineDynamics, GLMakie, LinearAlgebra, SHA

const OUTDIR = @__DIR__
const V1 = joinpath(OUTDIR, "dashboard-v1-head.png")
const V2 = joinpath(OUTDIR, "dashboard-v2-head.png")

const DT         = 4e-5
const SAVE_EVERY = 500
const LIN_DAMP   = 0.05
const DURATION   = 1.0

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

# ── v1 frame ───────────────────────────────────────────────────────────────
println("Building the v1 dashboard...")
fig1, _cfg = build_dashboard(
    sys, p, [u_start];
    times = [0.0], u_settled = u_start, wind_fn = wind_fn,
    config_name = "Canonical 5-line",
)
fig1.scene.backgroundcolor[] = to_color(:white)

println("Saving v1 at px_per_unit = 1.25 ...")
save(V1, fig1; px_per_unit = 1.25)
b1 = read(V1)
println("v1 $(V1)")
println("v1 bytes  $(length(b1))")
println("v1 sha256 $(bytes2hex(sha256(b1)))")

# ── v2 cockpit ─────────────────────────────────────────────────────────────
println("Running $(DURATION) s canonical sim for the v2 frame series...")
n_steps  = round(Int, DURATION / DT)
n_frames = n_steps ÷ SAVE_EVERY
frames = Vector{Vector{Float64}}(undef, n_frames)
times  = Vector{Float64}(undef, n_frames)
u = copy(u_start)
let fi = 1
    run_canonical_sim!(u, sys, p, wind_fn, n_steps, DT;
        lift_device = ld,
        lin_damp = LIN_DAMP,
        callback = (u_current, t_current, step) -> begin
            if step % SAVE_EVERY == 0 && fi <= n_frames
                frames[fi] = copy(u_current)
                times[fi]  = t_current
                fi += 1
            end
        end,
    )
end
println("frames captured: $(count(!isnothing, frames)) of $(n_frames)")

println("Building the v2 cockpit...")
fig2 = build_dashboard_v2(sys, p, frames; times = times,
                          u_settled = u_start, wind_fn = wind_fn,
                          lift_device = ld,
                          config_name = "Canonical 5-line")

println("Saving v2 at px_per_unit = 1.0 ...")
save(V2, fig2; px_per_unit = 1.0)
b2 = read(V2)
println("v2 $(V2)")
println("v2 bytes  $(length(b2))")
println("v2 sha256 $(bytes2hex(sha256(b2)))")
