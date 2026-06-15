using KiteTurbineDynamics
using LinearAlgebra
using Statistics

p   = params_10kw()
sys, u0 = build_kite_turbine_system(p)

v_target = 1.0
wind_fn = (pos, t) -> begin
    z  = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0/7.0)
    [v_target * sh, 0.0, 0.0]
end
lift_device = rotary_lifter_default()
ω_rated     = 0.0

u_start = settle_to_operational_state(sys, u0, p, ω_rated;
                                       lift_device = lift_device,
                                       wind_fn     = wind_fn)

N       = sys.n_total
hub_gid = sys.rotor.node_id
bgid    = sys.bearing_id

hub_pos     = u_start[3*(hub_gid-1)+1 : 3*hub_gid]
bearing_pos = u_start[3*(bgid-1)+1   : 3*bgid]

hub_norm  = norm(hub_pos)
shaft_dir = hub_pos ./ hub_norm
perp1, perp2 = shaft_perp_basis(shaft_dir)

hub_ring_idx = (sys.nodes[hub_gid]::RingNode).ring_idx
α_hub        = u_start[6N + hub_ring_idx]
R_hub        = (sys.nodes[hub_gid]::RingNode).radius

println("Hub Pos: ", hub_pos)
println("Bearing Pos: ", bearing_pos)
println("Shaft Dir: ", shaft_dir)

bridle_data = []
for ss in sys.sub_segs
    ss.end_a.is_ring && continue
    ss.end_a.node_id == bgid || continue
    ss.end_b.is_ring || continue
    ss.end_b.node_id == hub_gid || continue

    attach = attachment_point(hub_pos, R_hub, α_hub,
                               ss.end_b.line_idx, p.n_lines, perp1, perp2)
    geom_len = norm(bearing_pos .- attach)
    strain = (geom_len - ss.length_0) / ss.length_0
    tension = max(0.0, ss.EA * strain)
    
    push!(bridle_data, (line_idx=ss.end_b.line_idx, attach_z=attach[3], Pos=attach, geom_len=geom_len, length_0=ss.length_0, strain=strain, tension=tension))
end

sort!(bridle_data, by = x -> x.attach_z)

for (i, b) in enumerate(bridle_data)
    println("Bridle $i: line_idx=$(b.line_idx), Z=$(b.attach_z), geom_len=$(b.geom_len), length_0=$(b.length_0), strain=$(b.strain), Tension=$(b.tension) N")
end
