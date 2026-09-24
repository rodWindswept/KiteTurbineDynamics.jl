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

u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=30_000)
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
N = sys.n_total
Nr = sys.n_ring
hub_ri = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
gnd_ri = 1

println("Running 40 s standard gate window...")
for chunk in 1:8
    t_chunk = chunk * 5.0
    run_canonical_sim!(u, sys, pc, wf, round(Int, 5.0 / dt), dt; lift_device=lift, lin_damp=0.05)
    w_hub = u[6N + Nr + hub_ri]
    w_gnd = u[6N + Nr + gnd_ri]
    tau_gen, _ = KiteTurbineDynamics.get_generator_torque(u, sys, pc, t_chunk, wf; brake_engaged=sys.brake_engaged[])
    P_gen = tau_gen * w_gnd / 1000.0
    tw = twist_report(u, sys, N, Nr)
    sa_pos = u[(3*(sys.sky_anchor_id-1)+1):(3*sys.sky_anchor_id)]
    @printf("t = %4.1f s | w_gnd = %5.2f | w_hub = %5.2f | P_gen = %5.2f kW | twist_max = %4.2f | SA = [%.2f, %.2f, %.2f]\n",
        t_chunk, w_gnd, w_hub, P_gen, tw.max_ratio, sa_pos[1], sa_pos[2], sa_pos[3])
end
