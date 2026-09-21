using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf

include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const WINNER_CSV = joinpath(
    @__DIR__,
    "..",
    "scripts",
    "results",
    "v13_5kw_masslift_len18.8_rotorcount",
    "best_vector.csv",
)

p = params_at_length(params_daisy(), 18.8, 5.0)
bf = BLOCKING_WIND_FACTOR_5KW
xv = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
dec = design_from_vector_v10(
    xv,
    PROFILE_ELLIPTICAL,
    p;
    power_W=5000.0,
    cylinder_cone=true,
    rotor_count_mode=true,
    power_split=0.6,
    cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
    blocking_factor=bf,
)
cfg = KiteTurbineDynamics.ObjectiveConfig(;
    power_W=5000.0,
    v_rated=11.0,
    p_floor_kw=5.0,
    fos_target=2.5,
    fos_hard=2.5,
    min_wall_m=2e-3,
    t_over_D=0.055,
    rotor_count_mode=true,
    power_split=0.6,
    blocking_factor=bf,
)
sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
    dec,
    1.0,
    K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter,
    base_params=p,
    min_wall_m=2e-3,
    beam_sizing=sizing,
)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = lift_for(sys, pc)
wf = (r, t) -> [p.v_wind_ref, 0.0, 0.0]

u = settle_to_operational_state(
    sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=200_000
)
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
println(@sprintf("Settled. dt = %.6e s", dt))

sa_gid = sys.sky_anchor_id
hub_gid = sys.rotor.node_id
N = sys.n_total
Nr = sys.n_ring

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]
shaft = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
lat_of(v) = norm(v .- dot(v, shaft) .* shaft)

SIM_TOTAL_S = 120.0
CHUNK_S = 10.0
n_chunks = round(Int, SIM_TOTAL_S / CHUNK_S)
chunk_steps = round(Int, CHUNK_S / dt)

println("-"^80)
@printf(
    "%-6s | %-10s %-10s %-10s %-10s | %-10s %-10s\n",
    "Time",
    "HubLat(m)",
    "SALat(m)",
    "SA Y(m)",
    "T_cyan(N)",
    "Kite X(m)",
    "Kite Z(m)"
)
println("-"^80)

for i in 1:n_chunks
    t_sim = i * CHUNK_S
    run_canonical_sim!(u, sys, pc, wf, chunk_steps, dt; lift_device=lift, lin_damp=0.05)

    h_lat = lat_of(pos(u, hub_gid))
    sa_p = pos(u, sa_gid)
    sa_lat = lat_of(sa_p)

    # Cyan tension
    ss = sys.sub_segs[end]
    pa = pos(u, ss.end_a.node_id)
    pb = pos(u, ss.end_b.node_id)
    t_cyan = ss.EA * max(0.0, (norm(pb - pa) - ss.length_0) / ss.length_0)

    @printf(
        "%5.1f s | %-10.4f %-10.4f %-10.4f %-10.1f | %-10.3f %-10.3f\n",
        t_sim,
        h_lat,
        sa_lat,
        sa_p[2],
        t_cyan,
        sys.kite_pos[1],
        sys.kite_pos[3]
    )
    flush(stdout)
end
println("="^80)
