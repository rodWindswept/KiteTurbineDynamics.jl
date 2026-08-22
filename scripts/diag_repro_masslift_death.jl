#!/usr/bin/env julia
# Reproduce the death of the 21:15 run: replicate run_v13_5kw_masslift.jl's
# island-1 population exactly (same seed, same RNG stream), and evaluate
# population[2] (the first random genome) with full stderr visible.
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, Random
include(joinpath(@__DIR__, "compute_seeds.jl"))

const LENGTH = 18.8
const KW = 5.0
const PW = KW * 1000.0
const ELEV = π / 6
const V_RATED = 11.0
const WINDOW_S = 20.0

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
end

p_base = params_at_length(LENGTH)
beam_profile = PROFILE_ELLIPTICAL
seed_v = seed_genome(KW)
lo, hi = tight_bounds(seed_v, KW)
dim = length(lo)

cfg = ObjectiveConfig(;
    power_W = PW, v_rated = V_RATED,
    p_floor_kw = 5.0, p_ceiling_kw = 5.0,
    relax_s = 5.0, window_s = WINDOW_S,
    fos_target = 2.5, fos_hard = 2.5,
    power_stat = :tail5, penalize_ceiling = false,
    kickstart_s = 0.0,
    k_mppt = 5.39,
    tether_diameter = p_base.tether_diameter,
)

# Exact island-1 population construction from the runner
Random.seed!(42 + 1 - 1)
popsize = 10
population = Vector{Vector{Float64}}(undef, popsize)
population[1] = clamp.(copy(seed_v), lo, hi)
population[1][8] = Float64(round(Int, clamp(population[1][8], 3, 16)))
for k in 2:popsize
    population[k] = lo .+ rand(Float64, dim) .* (hi .- lo)
end

println("== Seed eval (population[1]) ==")
flush(stdout)
for k in 1:2
    x = population[k]
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    println("== Eval #$k of population; x = ", round.(xr, digits=4), " ==")
    flush(stdout)
    t0 = time()
    r = KiteTurbineDynamics.evaluate_windowed(
        xr, beam_profile, p_base, cfg;
        start_mode = :cold,
        lift_device = lift_for,
        fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.mass_min_fitness(P, F, c, m),
    )
    println("== Eval #$k DONE in $(round(time()-t0, digits=1))s: status=$(r.status) fitness=$(r.fitness) P_mean=$(r.P_mean) FoS=$(r.FoS_min) ==")
    flush(stdout)
end
println("ALL EVALS COMPLETED — process alive")
