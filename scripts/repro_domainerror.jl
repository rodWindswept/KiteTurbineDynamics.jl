#!/usr/bin/env julia
# repro_domainerror.jl — reproduce the settle DomainError (negative value under
# a fractional exponent) seen ~5x/930 evals in both 5 kW campaigns.
#
# Loops over random genomes drawn from the campaign's tight bounds, decodes +
# builds + settles each (NO try/catch), and prints the FULL backtrace on the
# first DomainError.  The settle is ~1-2 s/genome, so ~200 genomes ≈ 7 min.
#
# Usage: julia --project=. scripts/repro_domainerror.jl [max_tries]
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const MAX_TRIES = length(ARGS) > 0 ? parse(Int, ARGS[1]) : 300

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

p_base = params_at_length(18.8)
seed_v = seed_genome(KW)
lo, hi = tight_bounds(seed_v, KW)

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function wf(pos, t)
    z = max(pos[3], 1.0)
    return [V_RATED * (z / p_base.h_ref)^(1.0 / 7.0), 0.0, 0.0]
end

using Random
Random.seed!(20260824)

for trial in 1:MAX_TRIES
    x = lo .+ rand(length(lo)) .* (hi .- lo)
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))
    result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p_base; power_W=PW, v_rated=V_RATED)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        result, 1.0, K_MPPT_5KW_HONEST; base_params=p_base)
    lift_dev = lift_for(sys, pc)
    try
        u = KiteTurbineDynamics.settle_to_operational_state(
            sys, copy(u0), pc, 60.0; wind_fn=wf, lift_device=lift_dev)
    catch e
        if e isa DomainError
            println("=== DomainError reproduced at trial $trial ===")
            println("genome: ", join(round.(x, digits=4), ","))
            println("msg: ", sprint(showerror, e))
            println("--- backtrace ---")
            for (i, fr) in enumerate(stacktrace(catch_backtrace()))
                i > 20 && break
                println("  ", fr)
            end
            exit(0)
        end
        # ignore other exception types; keep sampling
    end
    trial % 50 == 0 && println("  ... $trial tries, no DomainError yet")
end
println("No DomainError in $MAX_TRIES random genomes.")
