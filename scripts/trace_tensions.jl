#!/usr/bin/env julia
# scripts/trace_tensions.jl — final version
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra

function main()
    x_raw = parse.(Float64, split(readline("scripts/results/v10_campaign_50kw/best_vector.csv"), ","))
    x = copy(x_raw); x[8]=Float64(round(Int,clamp(x[8],3,16)))
    x[10]=clamp(x[10],0.0,Float64(N_VALID_MASKS))
    result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw(); max_ground_radius=5.0, power_W=50000.0)
    design = result.design; rotors = result.rotors; n_lines = design.n_lines
    n_rings_int = result.n_rings; sys_total = n_rings_int + 2
    expansion_params = ExpansionRotorParams[]
    for rotor in rotors
        mass_est = (0.3 + 0.1 * rotor.blade_tip_radius) * rotor.blade_scale^3
        sys_ri = rotor.ring_idx == n_rings_int ? sys_total : rotor.ring_idx + 1
        push!(expansion_params, ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius, rotor.blade_chord,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg, mass_est, sys_ri, 1.0))
    end
    p_base = params_v5_50kw()
    geo = GeometrySpec(p_base.elevation_angle, p_base.lifter_elevation, 5.0,
        design.tether_length, design.r_hub, p_base.trpt_rL_ratio, n_lines, n_rings_int, n_lines)
    mat = MaterialSpec(p_base.tether_diameter, p_base.e_modulus, p_base.m_ring, p_base.m_blade)
    aero = AeroSpec(p_base.rho, 11.0, p_base.h_ref, p_base.cp)
    ctrl = ControlSpec(p_base.i_pto, p_base.k_mppt, 50000.0, p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    p_campaign = SystemParams(geo, mat, aero, ctrl, back)
    sys, u0 = build_kite_turbine_system(p_campaign; expansion_rotors=expansion_params)
    wind_fn = (pos, t) -> begin
        z = max(pos[3], 1.0)
        [11.0 * (z / p_campaign.h_ref)^(1.0/7.0), 0.0, 0.0]
    end
    default_lift = rotary_lifter_default()
    u_start = settle_to_operational_state(sys, u0, p_campaign, 9.5; lift_device=default_lift, wind_fn=wind_fn)
    N = sys.n_total; Nr = sys.n_ring

    # Count slack
    function count_slack_fn(u, sys, p)
        shaft_dir = normalize(u[(3*(sys.rotor.node_id-1)+1):(3*sys.rotor.node_id)])
        perp1, perp2 = shaft_perp_basis(shaft_dir)
        alpha_loc = u[(6N+1):(6N+Nr)]
        c = 0
        for ss in sys.sub_segs
            pa = subseg_pos(u, sys, ss.end_a, alpha_loc, perp1, perp2, p.n_lines)
            pb = subseg_pos(u, sys, ss.end_b, alpha_loc, perp1, perp2, p.n_lines)
            va = u[(3N+3*(ss.end_a.node_id-1)+1):(3N+3*ss.end_a.node_id)]
            vb = u[(3N+3*(ss.end_b.node_id-1)+1):(3N+3*ss.end_b.node_id)]
            c += (get_subsegment_tension(ss, pa, pb, va, vb) < 0.01 ? 1 : 0)
        end
        return c
    end

    function subseg_pos(u, sys, se, alpha, perp1, perp2, n_lines_loc)
        if se.is_ring
            node = sys.nodes[se.node_id]::RingNode; ri = node.ring_idx
            R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[ri]
            ctr = u[(3*(se.node_id-1)+1):(3*se.node_id)]
            return attachment_point(ctr, R, alpha[ri], se.line_idx, n_lines_loc, perp1, perp2)
        else
            return u[(3*(se.node_id-1)+1):(3*se.node_id)]
        end
    end

    total = length(sys.sub_segs)
    c_init = count_slack_fn(u_start, sys, p_campaign)
    println("=== INITIAL (after settle) ===")
    println("Rotor on hub? ", any(er.ring_idx == Nr for er in sys.expansion_rotors))
    println("Slack: $c_init / $total ($(round(c_init/total*100,digits=1))%)")

    DT=4e-5; n_steps=round(Int,2.0/DT); u_sim=copy(u_start)
    run_canonical_sim!(u_sim, sys, p_campaign, wind_fn, n_steps, DT; lift_device=default_lift, lin_damp=0.05)
    c_2s = count_slack_fn(u_sim, sys, p_campaign)
    omega_hub = abs(u_sim[(6N+Nr+1):(6N+2Nr)][end])
    P_gen = p_campaign.k_mppt * omega_hub^3
    println("\n=== AFTER 2s SIM ===")
    println("Slack: $c_2s / $total ($(round(c_2s/total*100,digits=1))%)")
    println("Hub omega: $(round(omega_hub*60/(2π),digits=1)) rpm")
    println("P_gen: $(round(P_gen/1000,digits=1)) kW")
end

main()
