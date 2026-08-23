#!/usr/bin/env julia
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
        mass_est = expansion_blade_mass(rotor.blade_tip_radius - rotor.blade_hub_radius)
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

    # Gravity-settle only — no wind, no operational spin-up
    println("=== GRAVITY SETTLE ONLY (no wind) ===")
    u_grav = settle_to_equilibrium(sys, u0, p_campaign; wind_fn=nothing, n_steps=20000)
    
    N = sys.n_total; Nr = sys.n_ring
    function count_slack_fn(u)
        shaft_dir = normalize(u[(3*(sys.rotor.node_id-1)+1):(3*sys.rotor.node_id)])
        perp1, perp2 = shaft_perp_basis(shaft_dir)
        alpha_loc = u[(6N+1):(6N+Nr)]
        c = 0
        worst = (0.0, 0.0, 0.0, 0.0, "", 0)  # strain, tension, len, rest_len, type, idx
        for (i, ss) in enumerate(sys.sub_segs)
            if ss.end_a.is_ring
                node = sys.nodes[ss.end_a.node_id]::RingNode; ri = node.ring_idx
                R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[ri]
                ctr = u[(3*(ss.end_a.node_id-1)+1):(3*ss.end_a.node_id)]
                pa = attachment_point(ctr, R, alpha_loc[ri], ss.end_a.line_idx, p_campaign.n_lines, perp1, perp2)
            else
                pa = u[(3*(ss.end_a.node_id-1)+1):(3*ss.end_a.node_id)]
            end
            if ss.end_b.is_ring
                node = sys.nodes[ss.end_b.node_id]::RingNode; ri = node.ring_idx
                R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[ri]
                ctr = u[(3*(ss.end_b.node_id-1)+1):(3*ss.end_b.node_id)]
                pb = attachment_point(ctr, R, alpha_loc[ri], ss.end_b.line_idx, p_campaign.n_lines, perp1, perp2)
            else
                pb = u[(3*(ss.end_b.node_id-1)+1):(3*ss.end_b.node_id)]
            end
            curr = norm(pb - pa)
            strain = (curr - ss.length_0) / ss.length_0
            T = max(0.0, ss.EA * strain)  # static — no velocity term
            if T < 0.01
                c += 1
                is_bridle = ss.end_a.node_id == sys.bearing_id
                stype = is_bridle ? "bridle" : "tether"
                if strain < worst[1]
                    worst = (strain, T, curr, ss.length_0, stype, i)
                end
            end
        end
        if c > 0
            s, T, curr, rest, stype, i = worst
            @printf("  %d slack, worst: %s#%d strain=%.4f T=%.1fN len=%.2f rest=%.2f\n", c, stype, i, s, T, curr, rest)
        end
        return c
    end
    
    cg = count_slack_fn(u_grav)

    # Now operational settle
    wind_fn = (pos, t) -> begin
        z = max(pos[3], 1.0)
        [11.0 * (z / p_campaign.h_ref)^(1.0/7.0), 0.0, 0.0]
    end
    default_lift = rotary_lifter_default()
    u_op = settle_to_operational_state(sys, u_grav, p_campaign, 9.5; lift_device=default_lift, wind_fn=wind_fn)
    
    println("\n=== OPERATIONAL SETTLE (wind + lift, ω=9.5) ===")
    co = count_slack_fn(u_op)

    # Check bridle tension vs rotor thrust
    hub_gid = sys.ring_ids[end]
    bearing_gid = sys.bearing_id
    println("\n=== FORCE BALANCE AT HUB ===")
    shaft_dir = normalize(u_op[(3*(sys.rotor.node_id-1)+1):(3*sys.rotor.node_id)])
    perp1, perp2 = shaft_perp_basis(shaft_dir)
    alpha_loc = u_op[(6N+1):(6N+Nr)]
    
    # Total bridle force (sum of all bridle tensions projected along shaft)
    total_bridle_axial = 0.0
    for li in 1:n_lines
        node = sys.nodes[hub_gid]::RingNode; ri = node.ring_idx
        R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[ri]
        ctr = u_op[(3*(hub_gid-1)+1):(3*hub_gid)]
        vtx = attachment_point(ctr, R, alpha_loc[ri], li, p_campaign.n_lines, perp1, perp2)
        bpos = u_op[(3*(bearing_gid-1)+1):(3*bearing_gid)]
        dir_bridle = normalize(vtx - bpos)
        axial = abs(dot(dir_bridle, shaft_dir))
        # Find bridle tension
        for ss in sys.sub_segs
            if ss.end_a.node_id == bearing_gid && ss.end_b.is_ring && ss.end_b.node_id == hub_gid && ss.end_b.line_idx == li
                T = get_subsegment_tension(ss, bpos, vtx,
                    u_op[(3*N+3*(bearing_gid-1)+1):(3*N+3*bearing_gid)],
                    u_op[(3*N+3*(hub_gid-1)+1):(3*N+3*hub_gid)])
                total_bridle_axial += T * axial
                break
            end
        end
    end
    println("Total bridle axial force: $(round(total_bridle_axial/1000,digits=2)) kN")
    println("Rotor thrust estimate: $(round(0.5*1.225*11^2*pi*2.7^2*0.8/1000,digits=2)) kN (from BEM)")
    println("k_mppt: $(round(p_campaign.k_mppt,digits=0))")
end
main()
