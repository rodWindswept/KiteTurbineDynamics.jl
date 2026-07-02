#!/usr/bin/env julia
# scripts/launch_v2.jl — Quick launcher for the v2 cockpit dashboard.
#
# Usage:
#   julia --project=. scripts/launch_v2.jl                     # canonical 5-line 10kW
#   julia --project=. scripts/launch_v2.jl --v10-tight          # V10 Tight 50kW
#   julia --project=. scripts/launch_v2.jl --v10-reinforced     # V10 Reinforced

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, LinearAlgebra, Printf, GLMakie

include("builders_util.jl")

function main()
    v10t = false; v10r = false; dur = 10.0
    for a in ARGS
        if     a == "--v10-tight";       v10t = true
        elseif a == "--v10-reinforced";  v10r = true
        elseif startswith(a, "--duration=")
            dur = parse(Float64, split(a, "=")[2])
        end
    end

    v_wind = 11.0

    if v10r || v10t
        sys, u0, p, config_name = build_v10_tight_no_lowest()
        if v10r; config_name = "V10 Reinforced"; end
    else
        p = params_10kw(); sys, u0 = build_kite_turbine_system(p)
        config_name = "Canonical 5-line"
    end

    wind_fn = (pos, t) -> begin
        z = max(pos[3], 1.0); [v_wind * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end

    lift_device = rotary_lifter_default()
    println("Settling…")
    u_start = settle_to_operational_state(sys, copy(u0), p, 9.5;
        lift_device=lift_device, wind_fn=wind_fn)

    DT = 4e-5; SAVE_EVERY = max(1, round(Int, 0.02 / DT))
    n_steps = round(Int, dur / DT); n_frames = n_steps ÷ SAVE_EVERY
    println("Simulating $(dur)s → $(n_frames) frames…")

    u = copy(u_start); du = zeros(Float64, length(u)); t = 0.0
    frames = Vector{Vector{Float64}}(undef, n_frames)
    times  = Vector{Float64}(undef, n_frames)
    ode_params = (sys, p, wind_fn, lift_device)
    N = sys.n_total; Nr = sys.n_ring

    for fi in 1:n_frames
        for _ in 1:SAVE_EVERY
            fill!(du, 0.0); multibody_ode!(du, u, ode_params, t)
            @views u[(3N+1):6N] .+= DT .* du[(3N+1):6N]
            @views u[1:3N] .+= DT .* u[(3N+1):6N]
            @views u[(6N+Nr+1):(6N+2Nr)] .+= DT .* du[(6N+Nr+1):(6N+2Nr)]
            @views u[(6N+1):(6N+Nr)] .+= DT .* u[(6N+Nr+1):(6N+2Nr)]
            @views u[(3N+1):6N] .*= 0.05
            @views u[(6N+Nr+1):(6N+2Nr)] .*= 0.05
            u[1:3].=0; u[3N+1:3N+3].=0; u[6N+1]=0; u[6N+Nr+1]=0
            update_kite_pos!(sys, u, lift_device, p, DT)
            t += DT
        end
        frames[fi] = copy(u); times[fi] = t
        if fi % 200 == 0
            ω = abs(u[6N+Nr+Nr]) * 60/(2π)
            sf = capture_frame(u, sys, p, t, wind_fn, lift_device; brake_engaged=false)
            @printf("  t=%5.1fs  P=%.1fkW  ω=%.0frpm  FoS=%.2f\n", t, sf.P_kw, ω, sf.fos_ring)
        end
    end

    println("Launching v2 cockpit ($config_name, $(n_frames) frames)…")
    fig = build_dashboard_v2(sys, p, frames;
        times=times, u_settled=u_start, wind_fn=wind_fn,
        lift_device=lift_device, config_name=config_name)
    display(fig)
    wait(fig.scene)
end

main()
