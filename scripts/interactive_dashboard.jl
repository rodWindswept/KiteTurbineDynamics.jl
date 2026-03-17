#!/usr/bin/env julia
# scripts/interactive_dashboard.jl
# Interactive GLMakie dashboard for KiteTurbineDynamics.jl.
# Run:  julia --project=. scripts/interactive_dashboard.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, GLMakie, Printf

p       = params_10kw()
sys, u0 = build_kite_turbine_system(p)
u_start = settle_to_equilibrium(sys, u0, p)

N  = sys.n_total
Nr = sys.n_ring
u_start[6N + Nr + Nr] = 1.0   # seed hub with startup omega = 1 rad/s

wind_fn = (pos, t) -> begin
    z  = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0/7.0)
    [p.v_wind_ref * sh, 0.0, 0.0]
end

# ── Explicit integrator: save a frame every `save_every` steps ──────────────
const SAVE_EVERY    = 5_000     # 0.2 s per frame at dt=4e-5
const N_STEPS_TOTAL = 250_000   # 10 s simulated
const DT            = 4e-5
const LIN_DAMP      = 0.05

n_frames = N_STEPS_TOTAL ÷ SAVE_EVERY
frames   = Vector{Vector{Float64}}(undef, n_frames)

u  = copy(u_start)
du = zeros(Float64, length(u))
t  = 0.0
fi = 1

println("Simulating $(N_STEPS_TOTAL * DT) s  ($N_STEPS_TOTAL steps, $n_frames frames)...")
for step in 1:N_STEPS_TOTAL
    fill!(du, 0.0)
    multibody_ode!(du, u, (sys, p, wind_fn), t)
    t += DT

    @views u[3N+1:6N]        .+= DT .* du[3N+1:6N]
    @views u[1:3N]            .+= DT .* u[3N+1:6N]
    @views u[6N+Nr+1:6N+2Nr] .+= DT .* du[6N+Nr+1:6N+2Nr]
    @views u[6N+1:6N+Nr]     .+= DT .* u[6N+Nr+1:6N+2Nr]

    @views u[3N+1:6N]        .*= LIN_DAMP   # damp rope oscillations
    # angular velocity: no damping so hub can spin freely

    u[1:3]       .= 0.0
    u[3N+1:3N+3] .= 0.0
    u[6N+1]       = 0.0
    u[6N+Nr+1]    = 0.0

    if step % SAVE_EVERY == 0
        frames[fi] = copy(u)
        fi += 1
    end
end

println("Done. Hub ω_final = $(round(u[6N+Nr+Nr], digits=4)) rad/s")
println("Building dashboard...")

fig = build_dashboard(sys, p, frames)
display(fig)
println("Dashboard open. Use the frame slider or ▶ Play to animate. Press Ctrl+C to quit.")
wait(fig.scene)
