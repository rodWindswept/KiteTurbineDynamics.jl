# Trace how compute_rope_forces! actually computes attachment points and bridle tensions
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function trace_ode_forces()
    sys, u0, pc, lift, wf = build_case(nothing, nothing)
    u = settle_to_operational_state(sys, u0, pc, 60.0; lift_device=lift, wind_fn=wf, n_op=2_000)
    
    N = sys.n_total
    Nr = sys.n_ring
    forces = [zeros(3) for _ in 1:N]
    torques = zeros(Nr)
    alpha = @view u[(6N + 1):(6N + Nr)]
    omega = @view u[(6N + Nr + 1):(6N + 2Nr)]
    
    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    pp1_tilt, pp2_tilt = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub_gid, hub_ri)
    
    KiteTurbineDynamics.compute_rope_forces!(forces, torques, u, alpha, sys, pc, wf, 0.0, pp1_tilt, pp2_tilt)
    sd = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    println("Rope forces on hub along shaft = ", dot(forces[hub_gid], sd))
    println("Rope forces on bearing along shaft = ", dot(forces[sys.bearing_id], sd))
    println("Rope forces on sky anchor along shaft = ", dot(forces[sys.sky_anchor_id], sd))
    
    KiteTurbineDynamics.compute_ring_forces!(forces, torques, u, omega, sys, pc, wf, 0.0, lift, nothing)
    println("Total forces on hub along shaft after ring forces = ", dot(forces[hub_gid], sd))
    println("Total forces on bearing along shaft after ring forces = ", dot(forces[sys.bearing_id], sd))
    println("Total forces on sky anchor along shaft after ring forces = ", dot(forces[sys.sky_anchor_id], sd))
end
trace_ode_forces()
