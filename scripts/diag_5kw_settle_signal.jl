#!/usr/bin/env julia --project=.
#=
diag_5kw_settle_signal.jl — Test settle ω as DE fitness signal.
Perturbs seed ±20% on each dimension, measures settle ω.
=#

using KiteTurbineDynamics, Printf, Statistics
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0

function settle_omega(x::Vector{Float64})
    p = mass_scale(params_10kw(), 10.0, KW)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW)
    if dec.n_active == 0
        return 0.0
    end
    
    try
        sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
        wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
        lift = rotary_lifter_default()
        u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=20_000)
        N = sys.n_total; Nr = sys.n_ring
        return u[6N + Nr + Nr]  # ω_hub
    catch e
        return 0.0
    end
end

seed = seed_genome(KW)
ω_seed = settle_omega(seed)
println("Seed settle ω = ", round(ω_seed, digits=2), " rad/s  (", round(ω_seed*60/(2π), digits=1), " rpm)")

lo, hi = tight_bounds(seed, KW)
dims = ["Do_top","t/D","aspect","Do_exp","r_hub","r_bot","Lr","n_lines","density","mask","bank_t","bank_b","λ_top","λ_bot"]
println("\nDimension          -20%     -10%     seed    +10%    +20%    range")
for i in 1:14
    vals = Float64[]
    for frac in [-0.2, -0.1, 0.0, 0.1, 0.2]
        xp = copy(seed)
        delta = frac * seed[i]
        if i == 8
            xp[i] = Float64(round(Int, clamp(seed[i] + round(Int, delta), 3, 16)))
        else
            xp[i] = clamp(seed[i] + delta, lo[i], hi[i])
        end
        push!(vals, settle_omega(xp))
    end
    spread = maximum(vals) - minimum(vals)
    @printf("%-12s %7.2f %7.2f %7.2f %7.2f %7.2f  Δ=%.3f\n",
        dims[i], vals[1], vals[2], vals[3], vals[4], vals[5], spread)
end
