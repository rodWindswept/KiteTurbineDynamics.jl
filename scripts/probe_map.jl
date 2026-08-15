#!/usr/bin/env julia --project=.
# probe_map.jl — verify sub_seg_trpt_seg classification on the seed build (v4 check)
using KiteTurbineDynamics
include(joinpath(@__DIR__, "compute_seeds.jl"))
include(joinpath(@__DIR__, "ode_gate_v13.jl"))

function probe()
    x = [parse(Float64, s) for s in split(strip(read(joinpath(@__DIR__, "results", "seed_5kw.csv"), String)), ",")]
    p = KiteTurbineDynamics.params_10kw()
    KW = 5.0
    pl = params_at_length(p, 21.2, KW)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, pl; power_W=5000.0)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, pl.k_mppt; tether_diameter=pl.tether_diameter)
    m = sys.sub_seg_trpt_seg
    println("sub_segs=", length(sys.sub_segs), " n_ring=", sys.n_ring, " map_len=", length(m))
    counts = zeros(Int, max(sys.n_ring - 1, 0))
    for v in m
        v > 0 && v <= length(counts) && (counts[v] += 1)
    end
    println("TRPT-chain sub-segs per segment: ", counts)
    println("non-TRPT sub-segs: ", sum(m .== 0))
    ok = length(m) == length(sys.sub_segs) && all(counts .> 0) &&
         (sys.n_ring > 1 ? maximum(m) == sys.n_ring - 1 : true)
    println(ok ? "MAP OK" : "MAP BAD")
end
probe()
