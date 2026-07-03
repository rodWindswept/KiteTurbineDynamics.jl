#!/usr/bin/env julia
#= scripts/dashboard_v2_standalone.jl
Opens the v1 dashboard PLUS supplementary v2 panels (ring health, tension chain).
All panels share the same simulation data.

Run: julia --project=. scripts/dashboard_v2_standalone.jl [config]
     julia --project=. scripts/dashboard_v2_standalone.jl --v10-tight
=#

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, GLMakie, Printf, LinearAlgebra, ArgParse

function parse_cli()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--v10-tight"; action=:store_true
        "--v10"; action=:store_true
        "--wind"; arg_type=Float64; default=11.0
        "--duration"; arg_type=Float64; default=10.0
        "--expansion"; arg_type=Float64; default=0.0
    end
    return ArgParse.parse_args(s)
end

args = parse_cli()

# ── Build system ───────────────────────────────────────────────────────
# Winner-include helper: these builder scripts define p / sys / u0 when present.
# They aren't in the repo yet, so fall back to canonical rather than crashing.
_winner = args["v10-tight"] ? "trpt_opt/v10_tight_winner.jl" :
          args["v10"]       ? "trpt_opt/v10_winner.jl" : ""
if !isempty(_winner) && isfile(joinpath(@__DIR__, _winner))
    include(joinpath(@__DIR__, _winner))
    config_name = args["v10-tight"] ? "V10 Tight" : "V10"
else
    if !isempty(_winner)
        @warn "Winner builder $_winner not found — falling back to canonical 5-line"
    end
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    config_name = "Canonical 5-line"
end

# Override with problem-level args if available
if @isdefined(p) && @isdefined(sys) && @isdefined(u0)
else
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
end

N = sys.n_total; Nr = sys.n_ring
# 1/7-power-law shear wind — matches interactive_dashboard.jl's proven path.
wf = (pos,t) -> begin
    z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1/7)
    [p.v_wind_ref * sh, 0.0, 0.0]
end

println("$config_name: $(p.n_lines) lines, $(sys.n_ring) rings, $(sys.n_total) nodes")

# ── Settle to operational state, then run ───────────────────────────────
# The hand-rolled Euler loop this replaced started from an unsettled u0 with
# no lift device and diverged to NaN. Use the same settle + run_canonical_sim!
# machinery interactive_dashboard.jl uses.
default_lift = rotary_lifter_default()
println("Settling to operational state (ω=9.5)...")
u_start = settle_to_operational_state(sys, u0, p, 9.5; lift_device=default_lift, wind_fn=wf)

println("Simulating $(args["duration"])s...")
DT = 4e-5
LIN_DAMP = 0.05
N_STEPS = round(Int, args["duration"] / DT)
SAVE_EVERY = 200
u = copy(u_start)
frames = Vector{Float64}[]
times  = Float64[]
sim_frames = SimFrame[]
ext_frames = ExtendedSimFrame[]

run_canonical_sim!(u, sys, p, wf, N_STEPS, DT;
    lift_device = default_lift,
    lin_damp = LIN_DAMP,
    callback = (u_curr, t_curr, step) -> begin
        if step % SAVE_EVERY == 0
            push!(frames, copy(u_curr))
            push!(times, t_curr)
            push!(sim_frames, capture_frame(u_curr, sys, p, t_curr, wf, default_lift; brake_engaged=sys.brake_engaged[]))
            push!(ext_frames, capture_extended(u_curr, sys, p, t_curr, wf, default_lift; brake_engaged=sys.brake_engaged[]))
        end
    end)
n_frames = length(frames)
println("$(n_frames) frames simulated")

# ── Open v1 dashboard ──────────────────────────────────────────────────
println("Building v1 dashboard...")
fig_v1, cockpit_v1, _ = build_dashboard(sys, p, frames; times=times, u_settled=u_start, wind_fn=wf, config_name=config_name)
screen_v1 = GLMakie.Screen()
display(screen_v1, fig_v1)
if cockpit_v1 !== nothing
    cp_screen = GLMakie.Screen()
    display(cp_screen, cockpit_v1)
end

# ── Open v2 panels (separate windows) ──────────────────────────────────
println("Opening v2 panels...")

# Palette
A1_BG, A1_PANEL = RGBf(0.039,0.047,0.063), RGBf(0.071,0.086,0.114)
A1_EDGE, A1_INK = RGBf(0.133,0.165,0.208), RGBf(0.910,0.933,0.965)
A1_INK_DIM, A1_INK_FAINT = RGBf(0.604,0.655,0.714), RGBf(0.392,0.447,0.518)
A1_ACCENT, A1_GREEN = RGBf(0.224,0.816,0.847), RGBf(0.2,0.8,0.3)
A1_ORANGE, A1_RED = RGBf(0.95,0.55,0.1), RGBf(0.95,0.2,0.2)
pal = DashboardPalette(A1_BG, A1_PANEL, A1_EDGE, A1_INK, A1_INK_DIM, A1_INK_FAINT, A1_ACCENT, A1_GREEN, A1_ORANGE, A1_RED)

ext_obs = Observable(ext_frames)
frame_obs_v2 = Observable(1)
sf_obs = Observable(sim_frames)

# Ring Health window
fig_rh = Figure(size=(350, 700), backgroundcolor=A1_BG)
Label(fig_rh[1,1], "RING HEALTH"; fontsize=12, color=A1_ACCENT, font=:bold, halign=:center)
ring_labels = ["R$i" for i in 1:Nr]
exp_idxs = [er.ring_idx for er in sys.expansion_rotors]
ring_health!(fig_rh[2,1], ext_obs, pal; n_rings=Nr, ring_labels=ring_labels, exp_rings=exp_idxs)
screen_rh = GLMakie.Screen()
display(screen_rh, fig_rh)

# Tension Chain window
fig_tn = Figure(size=(350, 700), backgroundcolor=A1_BG)
Label(fig_tn[1,1], "TENSION CHAIN"; fontsize=12, color=A1_ACCENT, font=:bold, halign=:center)
tension_chain!(fig_tn[2,1], ext_obs, pal; n_segments=Nr-1, swl=15.0)
screen_tn = GLMakie.Screen()
display(screen_tn, fig_tn)

# Cockpit strip window
fig_cp = Figure(size=(900, 80), backgroundcolor=A1_BG)
cp = GridLayout(fig_cp[1,1])
cp_labels = ["POWER kW","ROTOR rpm","FoS","RING %","WIND m/s","ELEV","TIME"]
cp_vals = Observable.(["0.00 kW","0 rpm","∞","0%","0.0 m/s","30°","0.00 s"])
for (i,(vo,lo)) in enumerate(zip(cp_vals, cp_labels))
    Label(cp[2,i], lo; fontsize=8, color=A1_INK_DIM, halign=:left)
    Label(cp[1,i], vo; fontsize=16, font=:bold, color=A1_INK, halign=:left)
end
screen_cp = GLMakie.Screen()
display(screen_cp, fig_cp)

# Wire frame updates for cockpit strip
on(frame_obs_v2) do fi
    (fi < 1 || fi > length(sim_frames)) && return
    sf = sim_frames[fi]
    cp_vals[1][] = @sprintf("%.1f kW", sf.P_kw)
    cp_vals[2][] = @sprintf("%.0f rpm", abs(sf.omega_hub)*60/(2π))
    cp_vals[3][] = fos_str(sf.fos_tether)
    cp_vals[4][] = @sprintf("%.0f%%", sf.ring_max_util*100)
    cp_vals[5][] = @sprintf("%.1f m/s", sf.V_hub)
    cp_vals[7][] = @sprintf("%.1f s", sf.t)
end

# Continuous playback of the pre-computed frames.
println("\n✓ All windows open. V1 dashboard + V2 panels (ring health, tension, telemetry)")
println("  V2 panels loop through the run continuously. Close any window to exit.")
println()

# ring_health!/tension_chain! read efs[end] of ext_obs, so feed a growing
# slice up to the current frame — efs[end] tracks it and the bars animate.
# Loop until a window closes.
fi = 1
while isopen(screen_v1) && isopen(screen_rh) && isopen(screen_tn)
    frame_obs_v2[] = fi
    ext_obs[] = ext_frames[1:fi]
    fi = fi >= n_frames ? 1 : min(fi + 5, n_frames)
    sleep(0.03)
end
