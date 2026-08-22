#!/usr/bin/env julia
# Trace WHERE the low-k reject happens: run evaluate_windowed at k=0.5 and
# k=5.39 with the trace callback, print result + ω_gnd samples.
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 20.0
const LENGTH = 18.8

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
seed_v = seed_genome(KW)
lo, hi = tight_bounds(seed_v, KW)
xr = clamp.(copy(seed_v), lo, hi)
xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))

function run_at(k::Float64)
    cfg = ObjectiveConfig(;
        power_W = PW, v_rated = V_RATED,
        p_floor_kw = 5.0, p_ceiling_kw = 5.0,
        relax_s = 5.0, window_s = WINDOW_S,
        fos_target = 2.5, fos_hard = 2.5,
        power_stat = :tail5, penalize_ceiling = false,
        kickstart_s = 0.0,
        k_mppt = k,
        tether_diameter = p_base.tether_diameter,
    )
    ω_trace = Float64[]
    trace_cb = (u, t, step, ctx) -> begin
        sysc = ctx.sys
        Nr = sysc.n_ring; N = sysc.n_total
        if length(ω_trace) < 20 || step % 500 == 0
            push!(ω_trace, u[6N + Nr + 1])
        end
    end
    println("── k=$k ──")
    t0 = time()
    r = KiteTurbineDynamics.evaluate_windowed(
        xr, PROFILE_ELLIPTICAL, p_base, cfg;
        start_mode = :cold,
        lift_device = lift_for,
        trace_callback = trace_cb,
        fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.mass_min_fitness(P, F, c, m),
    )
    println("  wall=$(round(time()-t0, digits=1))s  status=$(r.status)  P_mean=$(r.P_mean)  P_end=$(r.P_end)  FoS=$(r.FoS_min)  fitness=$(r.fitness)")
    println("  ω_gnd first: ", [round(w, digits=2) for w in ω_trace[1:min(6, end)]])
    if length(ω_trace) > 6
        println("  ω_gnd last:  ", [round(w, digits=2) for w in ω_trace[max(1, end-5):end]])
        println("  ω_gnd max=$(round(maximum(ω_trace), digits=2))  min=$(round(minimum(ω_trace), digits=2))  n=$(length(ω_trace))")
    end
    flush(stdout)
    return r
end

for k in [0.5, 3.0, 4.0, 5.39]
    run_at(k)
end
println("DONE")
