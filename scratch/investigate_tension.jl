#!/usr/bin/env julia
# scratch/investigate_tension.jl
#
# Investigates the tension paradox: why do the upper tethers go slack when the
# backline is paid out and the top of the turbine rises?
# Prints the exact coordinates, tensions, and forces at t = 0.0s (settled) and t = 18.5s (peak furl).

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using KiteTurbineDynamics: RingNode, attachment_point, _tilted_ring_basis, cp_at_tsr, params_10kw, build_kite_turbine_system, rotary_lifter_default, settle_to_operational_state, multibody_ode!, orbital_damp_rope_velocities!, SystemParams
using LinearAlgebra, Printf

function _modified_params(base::SystemParams; overrides...)
    fnames = fieldnames(SystemParams)
    ftypes = fieldtypes(SystemParams)
    override_dict = Dict{Symbol,Any}(overrides)
    vals = ntuple(length(fnames)) do i
        convert(ftypes[i], get(override_dict, fnames[i], getfield(base, fnames[i])))
    end
    SystemParams(vals...)
end

function main()
    p = params_10kw()
    p_run = _modified_params(p;
        β_rate_max = 1.0, # Mode 1: Active Damping
        β_min      = 25.0
    )
    
    sys, u0 = build_kite_turbine_system(p_run)
    ld = rotary_lifter_default()
    
    vref = 11.0
    wf = (pos, t) -> begin
        z = max(pos[3], 1.0); sh = (z / p_run.h_ref)^(1/7)
        [vref * sh, 0.0, 0.0]
    end
    
    # Settle
    omega_rated = cbrt(p_run.p_rated_w / p_run.k_mppt)
    u_s = settle_to_operational_state(sys, u0, p_run, omega_rated; lift_device=ld, wind_fn=wf)
    
    # Sim timing
    t_total = 20.0
    dt = 4e-5
    n_steps = round(Int, t_total / dt)
    
    u = copy(u_s)
    du = zeros(Float64, length(u))
    t = 0.0
    release_frac = 0.0
    
    N = sys.n_total
    Nr = sys.n_ring
    n_seg = p_run.n_rings + 1
    ea_rope = sys.sub_segs[1].EA
    
    furl_delay    = 0.15 * t_total
    furl_duration = 0.70 * t_total
    payout_base   = p_run.β_min
    geom_scale    = p_run.tether_length / 30.0
    max_payout    = payout_base * geom_scale
    
    println("=== STARTING TENSION INVESTIGATION ===")
    
    # Print function to print state
    function print_state(label::String, current_payout::Float64)
        hub_gid = sys.rotor.node_id
        hub_ri  = (sys.nodes[hub_gid]::RingNode).ring_idx
        bearing_gid = sys.bearing_id
        sky_anchor_gid = sys.sky_anchor_id
        
        hub_pos = u[3*(hub_gid-1)+1 : 3*hub_gid]
        bearing_pos = u[3*(bearing_gid-1)+1 : 3*bearing_gid]
        sky_anchor_pos = u[3*(sky_anchor_gid-1)+1 : 3*sky_anchor_gid]
        
        # Calculate elevation
        elev_hub = rad2deg(atan(hub_pos[3], sqrt(hub_pos[1]^2 + hub_pos[2]^2)))
        elev_sky = rad2deg(atan(sky_anchor_pos[3], sqrt(sky_anchor_pos[1]^2 + sky_anchor_pos[2]^2)))
        
        # Segment 1 (ground) and Segment 15 (hub) tensions
        perp1, perp2 = _tilted_ring_basis(u, sys, hub_gid, hub_ri)
        
        tensions = Float64[]
        for s in 1:n_seg
            t_sum = 0.0
            for j in 1:p_run.n_lines
                seg_nat_len = 4 * sys.sub_segs[(s-1)*p_run.n_lines*4 + 1].length_0
                gid_a = sys.ring_ids[s];      gid_b = sys.ring_ids[s+1]
                na    = sys.nodes[gid_a]::RingNode
                nb    = sys.nodes[gid_b]::RingNode
                ctr_a = u[3*(gid_a-1)+1 : 3*gid_a]
                ctr_b = u[3*(gid_b-1)+1 : 3*gid_b]
                α_a   = u[6N + na.ring_idx]
                α_b   = u[6N + nb.ring_idx]
                pa    = attachment_point(ctr_a, na.radius, α_a, j, p_run.n_lines, perp1, perp2)
                pb    = attachment_point(ctr_b, nb.radius, α_b, j, p_run.n_lines, perp1, perp2)
                T     = max(0.0, ea_rope * (norm(pb .- pa) - seg_nat_len) / seg_nat_len)
                t_sum += T
            end
            push!(tensions, t_sum / p_run.n_lines)
        end
        
        # Find bridle and cyan line tensions
        cyan_tension = 0.0
        bridle_tensions = Float64[]
        for ss in sys.sub_segs
            pa = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
            pb = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
            # Since bearing is a RingNode attachment for bridles, we must resolve it
            # But here let's just compute simple norm
            if ss.end_a.node_id == bearing_gid && ss.end_b.node_id == sky_anchor_gid
                # Cyan line!
                cyan_tension = max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
            elseif ss.end_a.node_id == bearing_gid && ss.end_b.is_ring
                # Bridle line!
                # We can approximate with simple node distance
                bridle_T = max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
                push!(bridle_tensions, bridle_T)
            end
        end
        avg_bridle = isempty(bridle_tensions) ? 0.0 : sum(bridle_tensions)/length(bridle_tensions)
        
        # Lift and backline forces
        v_lift = wf(sky_anchor_pos, t)
        v_hmag = sqrt(v_lift[1]^2 + v_lift[2]^2)
        _, T_lift, elev_lift_deg = lift_force_steady(ld, p_run.rho, v_hmag)
        
        back_ax = p_run.tether_length * cos(p_run.elevation_angle) + p_run.back_anchor_fwd_x
        b_dx   = sqrt((sky_anchor_pos[1] - back_ax)^2 + sky_anchor_pos[2]^2)
        b_dz   = sky_anchor_pos[3]
        b_dist = sqrt(b_dx^2 + b_dz^2)
        L_axis_design = p_run.tether_length + 6.0 + 5.0
        design_sky_anchor_x  = L_axis_design * cos(p_run.elevation_angle)
        design_sky_anchor_z  = L_axis_design * sin(p_run.elevation_angle)
        back_L0_design = sqrt((design_sky_anchor_x - back_ax)^2 + design_sky_anchor_z^2)
        back_L0 = back_L0_design + current_payout
        
        T_back = 0.0
        if b_dist > back_L0 + 1e-6
            w_back = 0.0264 # dyneema weight
            # Catenary force approximation
            T_back = p_run.EA_back_line * (b_dist - back_L0) / back_L0
        end
        
        # Print results
        println("----------------------------------------")
        println("State: ", label)
        println("Time: ", t, " s")
        println("Winch Payout: ", current_payout, " m")
        println("Hub Pos:        ", [@sprintf("%.3f", x) for x in hub_pos], " m  (Elev: ", @sprintf("%.1f°", elev_hub), ")")
        println("Bearing Pos:    ", [@sprintf("%.3f", x) for x in bearing_pos], " m")
        println("Sky Anchor Pos: ", [@sprintf("%.3f", x) for x in sky_anchor_pos], " m  (Elev: ", @sprintf("%.1f°", elev_sky), ")")
        println("Distances:")
        println("  Ground to Hub:        ", @sprintf("%.3f", norm(hub_pos)), " m  (Shaft length)")
        println("  Hub to Bearing:       ", @sprintf("%.3f", norm(bearing_pos .- hub_pos)), " m")
        println("  Bearing to SkyAnchor: ", @sprintf("%.3f", norm(sky_anchor_pos .- bearing_pos)), " m  (Cyan length)")
        println("Tensions:")
        println("  Lifter Kite Pull (T_lift): ", @sprintf("%.1f", T_lift), " N")
        println("  Backline Tension (T_back): ", @sprintf("%.1f", T_back), " N")
        println("  Cyan Line Tension:         ", @sprintf("%.1f", cyan_tension), " N")
        println("  Average Bridle Tension:    ", @sprintf("%.1f", avg_bridle), " N")
        println("  Tension Seg 1 (Ground):    ", @sprintf("%.1f", tensions[1]), " N")
        println("  Tension Seg 7 (Mid):       ", @sprintf("%.1f", tensions[7]), " N")
        println("  Tension Seg 15 (Hub/Top):  ", @sprintf("%.1f", tensions[15]), " N")
        println("----------------------------------------")
    end
    
    # Print initial state
    print_state("Initial Settled (Design point)", 0.0)
    
    ode_p = isnothing(ld) ? (sys, p_run, wf) : (sys, p_run, wf, ld)
    payout = 0.0
    
    # Run simulation
    for step in 1:n_steps
        if step % 500 == 0
            x = clamp((t - furl_delay) / furl_duration, 0.0, 1.0)
            release_frac = 3.0 * x^2 - 2.0 * x^3 # Sigmoid curve
            payout = max_payout * release_frac
            
            p_furl = _modified_params(p_run; backline_payout = payout)
            ode_p = isnothing(ld) ? (sys, p_furl, wf) : (sys, p_furl, wf, ld)
        end
        
        fill!(du, 0.0)
        multibody_ode!(du, u, ode_p, t)
        t += dt
        
        @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
        @views u[1:3N]            .+= dt .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
        @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]
        
        orbital_damp_rope_velocities!(u, sys, p_run, 0.05)
        
        u[1:3] .= 0.0
        u[3N+1:3N+3] .= 0.0
        
        # Print at t = 10.0s (mid furl)
        if abs(t - 10.0) < dt/2
            print_state("Mid Furl", payout)
        end
    end
    
    # Print final state at t = 20.0s
    print_state("Fully Furled", max_payout)
end

main()
