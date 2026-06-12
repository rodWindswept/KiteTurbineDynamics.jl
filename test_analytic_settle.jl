using KiteTurbineDynamics, LinearAlgebra

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
ld = rotary_lifter_default()
ω = cbrt(p.p_rated_w / p.k_mppt)
wf = (pos, t) -> [11.0, 0.0, 0.0]

u_start = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p; lift_device=ld, wind_fn=wf)

N = sys.n_total;
Nr = sys.n_ring
for ri in 1:Nr
    ;
    u_start[6N + Nr + ri] = ω;
end
u_start[6N + 1] = 0.0
β_a = p.elevation_angle
hp = u_start[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)]
sd = norm(hp) > 0.1 ? normalize(hp) : [cos(β_a), 0.0, sin(β_a)]
pp1, pp2 = shaft_perp_basis(sd)

# Skip the exact twist bisection for this quick test, just assume twist is done
# and cumulative shift is 0.145
cumulative_shift = 0.145
u_start[(3 * (sys.bearing_id - 1) + 1):(3 * sys.bearing_id)] .-= cumulative_shift .* sd

# 1. Bearing position
b_pos = u_start[(3 * (sys.bearing_id - 1) + 1):(3 * sys.bearing_id)]

# 2. Compute F_bridles
F_bridles = zeros(3)
for ss in sys.sub_segs
    if !ss.end_a.is_ring && ss.end_a.node_id == sys.bearing_id && ss.end_b.is_ring
        # Bridle
        pb = u_start[(3 * (ss.end_b.node_id - 1) + 1):(3 * ss.end_b.node_id)]
        # Wait, the bridle connects to the attachment point!
        na = sys.nodes[ss.end_b.node_id]::KiteTurbineDynamics.RingNode
        α = u_start[6N + na.ring_idx]
        pb = attachment_point(pb, na.radius, α, ss.end_b.line_idx, p.n_lines, pp1, pp2)

        dir = normalize(pb - b_pos)
        len = norm(pb - b_pos)
        strain = (len - ss.length_0) / ss.length_0
        T = ss.EA * strain
        F_bridles .+= T .* dir
    end
end

W_bearing = [0.0, 0.0, -sys.nodes[sys.bearing_id].mass * 9.81]

# 3. Required cyan force on bearing
F_cyan_req = -(F_bridles + W_bearing)
T_cyan = norm(F_cyan_req)
dir_cyan = normalize(F_cyan_req)

CYAN_L0 = 5.0
CYAN_EA = 500_000.0
L_cyan = CYAN_L0 * (1 + T_cyan / CYAN_EA)

# 4. Compute Sky Anchor position
sky_pos = b_pos + L_cyan .* dir_cyan
u_start[(3 * (sys.sky_anchor_id - 1) + 1):(3 * sys.sky_anchor_id)] .= sky_pos

println("Analytical Sky Anchor: ", sky_pos)
println("T_cyan: ", T_cyan)

# Now what is the required backline force?
W_sky = [0.0, 0.0, -sys.nodes[sys.sky_anchor_id].mass * 9.81]
v_wind = wf(sky_pos, 0.0)
v_mag = norm(v_wind)
_, T_lift, el = KiteTurbineDynamics.lift_force_steady(ld, p.rho, v_mag)
lift_dir = cos(deg2rad(el)) .* [1.0, 0, 0] + sin(deg2rad(el)) .* [0, 0, 1.0]
F_lift = T_lift .* lift_dir

F_backline_req = -(-F_cyan_req + W_sky + F_lift)
println("Required Backline Force: ", F_backline_req)

# Actual backline force from catenary
back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
b_dx = sqrt((sky_pos[1] - back_ax)^2 + sky_pos[2]^2)
b_dz = sky_pos[3]
L_axis_design = p.tether_length + 6.0 + 5.0
des_anc_x = L_axis_design * cos(p.elevation_angle)
des_anc_z = L_axis_design * sin(p.elevation_angle)
back_L0 = sqrt((des_anc_x - back_ax)^2 + des_anc_z^2)

w_back = KiteTurbineDynamics.dyneema_weight_Npm(0.003)
_, _, Fx, Fz, _ = KiteTurbineDynamics.catenary_forces(
    0.0, 0.0, b_dx, b_dz, back_L0, w_back, p.EA_back_line
)
uh_x = (sky_pos[1] - back_ax) / b_dx
uh_y = sky_pos[2] / b_dx
F_backline_act = [Fx * uh_x, Fx * uh_y, Fz]

println("Actual Backline Force:   ", F_backline_act)
println("Imbalance at Sky Anchor: ", F_backline_req - F_backline_act)
