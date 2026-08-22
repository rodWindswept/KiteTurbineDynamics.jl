#!/usr/bin/env julia
# Which gate rejects k=4.0?  Pure state reads only (no capture_extended):
# per-ring omega, hand-computed P = k·ω_gnd³, hub tip speed vs ceiling.
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

function trace_at(k::Float64)
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
    rows = Tuple{Float64,Float64,Float64,Float64,Float64}[]
    trace_cb = (u, t, step, ctx) -> begin
        sysc = ctx.sys
        Nr = sysc.n_ring; N = sysc.n_total
        w_gnd = u[6N + Nr + 1]
        hub_ri = (sysc.nodes[sysc.rotor.node_id]::RingNode).ring_idx
        w_hub = u[6N + Nr + hub_ri]
        P_hand = sysc.k_mppt_ref[] * w_gnd^3 / 1000.0
        tip_mps = w_hub * sysc.rotor.radius
        if step % 4000 == 0 || length(rows) < 2
            push!(rows, (t, w_gnd, w_hub, P_hand, tip_mps))
        end
    end
    t0 = time()
    r = KiteTurbineDynamics.evaluate_windowed(
        xr, PROFILE_ELLIPTICAL, p_base, cfg;
        start_mode = :cold,
        lift_device = lift_for,
        trace_callback = trace_cb,
        fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.mass_min_fitness(P, F, c, m),
    )
    println("── k=$k  status=$(r.status)  P_mean=$(r.P_mean)  P_end=$(r.P_end)  FoS=$(r.FoS_min)  twist=$(r.twist_crossed)  broken=$(r.line_broken)  ($(round(time()-t0,digits=1))s) ──")
    println("  t(s)   ω_gnd   ω_hub   P_hand(kW)  tip(m/s)")
    for (t, wg, wh, ph, tip) in rows
        @printf("  %5.1f  %6.2f  %6.2f   %6.2f    %7.1f\n", t, wg, wh, ph, tip)
    end
    println("  TIP_SPEED_CEILING = $(KiteTurbineDynamics.TIP_SPEED_CEILING_MPS) m/s")
    flush(stdout)
end

for k in [4.0, 5.39]
    trace_at(k)
end
println("DONE")
