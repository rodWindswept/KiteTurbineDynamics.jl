using KiteTurbineDynamics, LinearAlgebra, Printf

include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const WINNER_CSV = joinpath(@__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")

p = params_at_length(params_daisy(), 18.8, 5.0)
bf = BLOCKING_WIND_FACTOR_5KW
xv = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=bf)
cfg = KiteTurbineDynamics.ObjectiveConfig(;
    power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=bf)
sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
    beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = lift_for(sys, pc)
wf = (r, t) -> [p.v_wind_ref, 0.0, 0.0]

u_settled = settle_to_operational_state(sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=200_000)
sa_gid = sys.sky_anchor_id
sa0 = u_settled[(3*(sa_gid-1)+1):(3*sa_gid)]
println("Settled SA: ", sa0)
theta = p.lifter_elevation
lift_dir = [cos(theta), 0.0, sin(theta)]
kite_pos = sa0 .+ lift.line_length .* lift_dir
println("Kite pos:   ", kite_pos)
println("Lift dir:   ", lift_dir)
println("Line dist:  ", norm(kite_pos .- sa0))

# What is back line length and tension?
r_top = isempty(sys.expansion_rotors) ? (sys.nodes[sys.rotor.node_id]::RingNode).radius : sys.effective_radii[(sys.nodes[sys.rotor.node_id]::RingNode).ring_idx]
bearing_offset = KiteTurbineDynamics.bridle_bearing_offset(r_top)
cyan_L0 = KiteTurbineDynamics.CYAN_L0_DESIGN
L_axis_design = p.tether_length + bearing_offset + cyan_L0
design_sa_x = L_axis_design * cos(p.elevation_angle)
design_sa_z = L_axis_design * sin(p.elevation_angle)
back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
back_L0_design = sqrt((design_sa_x - back_ax)^2 + design_sa_z^2)
b_dx = sqrt((sa0[1] - back_ax)^2 + sa0[2]^2)
b_dz = sa0[3]
b_dist = sqrt(b_dx^2 + b_dz^2)
T_back = KiteTurbineDynamics.back_line_tension(b_dist, back_L0_design, p.backline_payout, p.EA_back_line)
println("Back line dist: ", b_dist, " L0_design: ", back_L0_design, " T_back: ", T_back)
