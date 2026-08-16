#!/usr/bin/env julia --project=.
#= diag_q1_lindamp.jl — Q1 fling verdict: does the orbital-damping operator
(lin_damp) contribute to the light-ring fling / line break of the void 18 m
winner? Two cases: lin_damp=0.05 (default) vs lin_damp=0.0. If the machine
breaks at ~the same point in both, the 58 g ring is doomed on its own and
companion fix (c) is OUT. If lin_damp=0 materially changes the outcome,
the operator contributes and (c) is IN. =#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))
include(joinpath(@__DIR__, "ode_gate_v13.jl"))

function build_void_winner()
    path = joinpath(@__DIR__, "results", "void_v13_pre-fix_len18.0", "best_vector.csv")
    x = [parse(Float64, s) for s in split(strip(read(path, String)), ",")]
    p = KiteTurbineDynamics.params_10kw()
    pl = params_at_length(p, 18.0, 5.0)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, pl; power_W=5000.0)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, pl.k_mppt; tether_diameter=pl.tether_diameter)
    return sys, u0, pc, pl
end

function run_case(ld::Float64)
    sys, u0, pc, p = build_void_winner()
    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
    lift = rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
    N = sys.n_total; Nr = sys.n_ring
    sys.k_mppt_ref[] = p.k_mppt
    broke_at = 0.0
    wmax = 0.0
    Tmax = 0.0
    for chunk in 1:12
        run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0 / 4e-5), 4e-5; lift_device=lift, lin_damp=ld)
        t = chunk * 5.0
        wmax = max(wmax, maximum(abs, @view u[(6N + Nr + 1):(6N + 2Nr)]))
        Tmax = max(Tmax, get_max_rope_tension(u, sys, pc)[1])
        if sys.any_broken[]
            broke_at = t
            break
        end
    end
    return broke_at, wmax, Tmax
end

function main()
    println("Q1: void 18 m winner, 60 s post-settle MPPT, two damping settings")
    for ld in [0.05, 0.0]
        b, w, T = run_case(ld)
        @printf("  lin_damp=%.2f  broke_at=%5.1f s  max|w|=%.4g  maxT=%.4g N\n", ld, b, w, T)
    end
end
main()
