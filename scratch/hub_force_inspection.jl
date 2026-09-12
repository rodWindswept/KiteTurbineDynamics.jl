# Deep dive into forces acting on the hub ring
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function inspect_hub_forces(beta_deg)
    sys, u0, pc, lift, wf = build_case(nothing, nothing)
    pc = override_params(pc; elevation_angle=deg2rad(beta_deg))
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)

    n_ring = sys.n_ring
    n_seg = n_ring - 1
    T_cyan = KiteTurbineDynamics.design_preload_from_sky_anchor(pc, lift)
    m_rotor = pc.n_blades * pc.m_blade
    F_aero_z = 0.5 * pc.rho * pc.v_wind_ref^2 * π * pc.rotor_radius^2 * 0.8 * cos(pc.elevation_angle)^2 * sin(pc.elevation_angle) + (m_rotor + sys.kite.mass) * (-9.81)
    F_top_guess = max(F_aero_z / sin(pc.elevation_angle) + T_cyan, 20.0)
    g_inc = pc.m_ring * 9.81 / sin(pc.elevation_angle)
    F_profile(top) = [top + (n_seg - i) * g_inc for i in 1:n_seg]

    # Let's settle operational state or settle equilibrium
    u = settle_to_operational_state(sys, u0, pc, 60.0; lift_device=lift, wind_fn=wf, n_op=2_000)
    N = sys.n_total
    hub_gid = sys.rotor.node_id
    bearing_gid = sys.bearing_id
    sky_gid = sys.sky_anchor_id
    sd = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]

    # Inspect the subsegments connected to hub
    println("--- Inspection for beta=$beta_deg deg ---")
    println("Hub node $hub_gid pos = ", u[(3hub_gid-2):3hub_gid])
    println("Bearing node $bearing_gid pos = ", u[(3bearing_gid-2):3bearing_gid])
    println("Sky anchor node $sky_gid pos = ", u[(3sky_gid-2):3sky_gid])

    # Let's see what subsegments touch hub
    bridle_tensions = Float64[]
    trpt_top_tensions = Float64[]
    for (si, ss) in enumerate(sys.sub_segs)
        if ss.end_a.node_id == hub_gid || ss.end_b.node_id == hub_gid
            pa = ss.end_a.node_id == hub_gid ? u[(3hub_gid-2):3hub_gid] : u[(3ss.end_a.node_id-2):3ss.end_a.node_id]
            pb = ss.end_b.node_id == hub_gid ? u[(3hub_gid-2):3hub_gid] : u[(3ss.end_b.node_id-2):3ss.end_b.node_id]
            len = norm(pb - pa)
            T = ss.EA * max(0.0, len - ss.length_0) / ss.length_0
            if ss.end_a.node_id == bearing_gid || ss.end_b.node_id == bearing_gid
                push!(bridle_tensions, T)
            else
                push!(trpt_top_tensions, T)
            end
        end
    end
    println("Bridle tensions (N) count=$(length(bridle_tensions)): sum = $(sum(bridle_tensions))")
    println("TRPT top segment subsegment tensions (N) count=$(length(trpt_top_tensions)): sum = $(sum(trpt_top_tensions))")
end
inspect_hub_forces(30.0)
