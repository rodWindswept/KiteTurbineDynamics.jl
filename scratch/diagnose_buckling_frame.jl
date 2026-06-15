# scratch/diagnose_buckling_frame.jl
using KiteTurbineDynamics
using LinearAlgebra
using Printf

println("Starting corrected Sequence 3 headless diagnostic run...")
p = params_10kw()
ld = rotary_lifter_default()

# 11.5 m/s wind profile matching the dashboard
vref = 11.5
wind_fn = (pos, t) -> begin
    z  = max(pos[3], 1.0)
    [vref * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
end

sys, u0 = build_kite_turbine_system(p)

println("Settling to operational state...")
u_start = settle_to_operational_state(sys, u0, p, 9.5; lift_device=ld, wind_fn=wind_fn)

# Simulate up to t = 22.38s
dt = 4e-5
n_steps = Int(round(22.38 / dt))

println("Running Pitch Depower simulation (Seq 3) for $(n_steps) steps...")
u = copy(u_start)
sys.brake_engaged[] = false
res = run_pitch_depower!(u, sys, p, wind_fn, n_steps, dt;
    lift_device = ld,
    depower_sequence = 3, # Option 3: Lift -> Stall (Stall gov after lift)
    use_field_imu = true, # Field IMU ON
    use_mppt_stall = true,
    save_every = 5000 # save output infrequently to save memory
)

# Mutated state vector u contains the final state!
u_final = u
t_final = n_steps * dt

println("\n--- DIAGNOSTIC RESULTS AT t = $(round(t_final, digits=2))s ---")

N = sys.n_total
Nr = sys.n_ring
alpha_vec = u_final[6N+1 : 6N+Nr]

rea_results = ring_element_analysis(u_final, collect(alpha_vec), sys, p, t_final, wind_fn)

# Calculate tether sags/slack lines to double check
sf = capture_frame(u_final, sys, p, t_final, wind_fn, ld)
println(@sprintf("T_max: %5.0f N  |  Slack lines: %d", sf.T_max, sf.n_slack))

for (k, frame) in enumerate(rea_results)
    ring_gid = sys.ring_ids[k+1]
    node = sys.nodes[ring_gid]
    R = node.radius
    
    # Inspect active vertices
    active_mask = zeros(Bool, p.n_lines)
    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    perp1, perp2 = KiteTurbineDynamics._tilted_ring_basis(u_final, sys, hub_gid, hub_ri)
    
    F_global = KiteTurbineDynamics.extract_vertex_forces(u_final, sys, ring_gid, collect(alpha_vec), p, perp1, perp2, t_final, wind_fn, active_mask)
    n_active = sum(active_mask)
    
    # Worst beam on this ring
    worst_beam_idx = argmax([b.utilisation for b in frame.beams])
    b = frame.beams[worst_beam_idx]
    
    N_term = max(b.N, 0.0) / b.N_crit
    M_ip_term = b.M_ip / b.M_el
    M_oop_term = b.M_oop / b.M_el
    
    @printf("Ring %2d (R=%4.2fm): active=%d | util=%5.1f%% | N/N_crit=%5.1f%% | M_ip/M_el=%5.1f%% | M_oop/M_el=%5.1f%%\n",
            k, R, n_active, b.utilisation*100, N_term*100, M_ip_term*100, M_oop_term*100)
end
