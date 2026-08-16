#!/usr/bin/env julia --project=.
#= anchor_april29_compare.jl — model-vs-measured for the TRPT-5 mast rig.
Sweeps wind 3.25:0.5:8.75 m/s, settles the rig with the 118 N bucket lift,
runs a 30 s window, records P_gen at the ground (PTO). Measured bins come
from scripts/results/april29_anchor.csv (wind-binned plateau ~220 W).
Writes scripts/results/april29_model_curve.csv. =#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "build_april29_rig.jl"))

function run_one(v::Float64; window_s::Float64=30.0)
    sys, u0, pc, lifter = build_april29_rig()
    wind_fn(r, t) = [v, 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
        lift_device=lifter, wind_fn=wind_fn, n_op=30_000)
    sys.k_mppt_ref[] = pc.k_mppt
    N = sys.n_total
    Nr = sys.n_ring
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
    Ps = Float64[]
    for chunk in 1:round(Int, window_s / 5.0)
        run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0 / 4e-5), 4e-5;
            lift_device=lifter, lin_damp=0.05)
        t = chunk * 5.0
        w_gnd = u[6N + Nr + gnd_ri]
        tau_gen, _ = get_generator_torque(u, sys, pc, t, wind_fn;
            brake_engaged=sys.brake_engaged[])
        push!(Ps, tau_gen * max(w_gnd, 0.0))
        sys.any_broken[] && break
    end
    return mean(Ps[max(1, end - 4):end]), u[6N + Nr + gnd_ri]
end

function main()
    out = joinpath(@__DIR__, "results", "april29_model_curve.csv")
    open(out, "w") do io
        write(io, "wind_ms,P_model_W,w_gnd_rads\n")
        for v in 3.25:0.5:8.75
            P, wg = run_one(v)
            @printf("  v=%4.2f  P_model=%7.1f W  w_gnd=%5.2f rad/s\n", v, P, wg)
            write(io, "$(v),$(P),$(wg)\n")
            flush(io)
        end
    end
    println("wrote ", out)
end
main()
