# scratch/probe_fwdx_experiment.jl
#
# Back-line work item (2026-09-22), decisive end-to-end experiment.
#
# `mass_scale` scales `back_anchor_fwd_x` by √(P_target/P_base), taking the daisy
# base's 11.0 m down to 6.901 m for the 5 kW / 18.8 m build.  `parameters.jl`'s own
# comment on the 11.0 m value records the failure mode that smaller offsets cause:
#
#   "At 5 m the geometry forced T_cyan < 0 (infeasible), so the sky anchor swung up
#    to ~80° elevation and the cyan transmitted no axial preload onto the bearing
#    → TRPT looked slack."
#
# That is the Item 4 island 1 failure signature.  This probe settles a candidate at
# several ground-anchor offsets and reports the back-line regime and the cone state,
# so the choice is made on measurement.
#
# Usage: julia --project=. scratch/probe_fwdx_experiment.jl <island_dir> [fwd_x ...]

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const RESDIR = joinpath(
    @__DIR__, "..", "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_physlift"
)
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
elev(v) = rad2deg(atan(v[3], hypot(v[1], v[2])))

const ISLAND = length(ARGS) >= 1 ? ARGS[1] : "island_1"
const FWDS = length(ARGS) >= 2 ? [parse(Float64, a) for a in ARGS[2:end]] : [6.901, 11.0]

CSV = joinpath(RESDIR, ISLAND, "best_vector.csv")
p0 = params_at_length(params_daisy(), 18.8, 5.0)
bf = BLOCKING_WIND_FACTOR_5KW
xv = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p0; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=bf)
cfg = KiteTurbineDynamics.ObjectiveConfig(;
    power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=bf)
sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p0, cfg)

"""
Cone total tension (N) and per-line values at a state, plus the hub's lateral
offset from the design axis and the bearing's offset from the hub axis.
"""
function state_report(u, sys, p)
    N, Nr = sys.n_total, sys.n_ring
    hub_gid, bear_gid = sys.rotor.node_id, sys.bearing_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub_gid, Nr)
    R = (sys.nodes[hub_gid]::RingNode).radius
    per = zeros(p.n_lines)
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub_gid && nb == bear_gid) || (na == bear_gid && nb == hub_gid)) ||
            continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(pos(u, hub_gid), R, u[6N + Nr], ring_end.line_idx,
            p.n_lines, pp1, pp2)
        L = norm(pos(u, bear_gid) .- pa)
        per[ring_end.line_idx] = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    # back line
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    r_top = isempty(sys.expansion_rotors) ? R : sys.effective_radii[hub_ri]
    bearing_offset = KiteTurbineDynamics.bridle_bearing_offset(r_top)
    back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    L_axis = p.tether_length + bearing_offset + KiteTurbineDynamics.CYAN_L0_DESIGN
    design_sky = [L_axis * cos(p.elevation_angle), 0.0, L_axis * sin(p.elevation_angle)]
    back_L0 = hypot(design_sky[1] - back_ax, design_sky[3])
    sa = pos(u, sys.sky_anchor_id)
    b_dist = norm([sa[1] - back_ax, sa[2], sa[3]])
    T_back = KiteTurbineDynamics.back_line_tension(
        b_dist, back_L0, p.backline_payout, p.EA_back_line
    )
    travel = KiteTurbineDynamics.BACK_LINE_SOFT_TRAVEL_M
    # Regime from the element's OWN tension value (authoritative): the soft branch
    # tops out at T_design, so anything at or above T_design is on the Dyneema.
    T_design = KiteTurbineDynamics.BACK_LINE_T_DESIGN_N
    reg = T_back <= 0.0 ? :SLACK : (T_back < T_design - 1e-9 ? :SOFT : :HARD)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, (r, t) -> [p.v_wind_ref, 0.0, 0.0],
        lift_for(sys, p)), 0.0)
    accs = [norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    st = [g for g in 1:N if sys.nodes[g] isa RingNode]
    hub = pos(u, hub_gid)
    # lateral offset from the shaft axis through the origin
    sh = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    hub_lat = norm(hub .- dot(hub, sh) .* sh)
    bear = pos(u, bear_gid)
    return (; per, T_back, regime=reg,
        hub_lat, acc_struct=maximum(accs[g] for g in st),
        bear_elev=elev((back_ax - sa[1], 0.0, -sa[3])))
end

@printf("═══ %s: ground-anchor offset experiment ═══\n", ISLAND)
@printf("%9s %9s %6s %8s %8s %9s %9s %9s %8s\n",
    "base_fwd", "real_fwd", "regime", "T_back", "T_cyan", "cone_tot", "cone_max",
    "hub_lat", "acc_str")

for fwd in FWDS
    p_ov = KiteTurbineDynamics.override_params(p0; back_anchor_fwd_x=fwd)
    sys, u0, p = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p0.tether_diameter, base_params=p_ov, min_wall_m=2e-3,
        beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = lift_for(sys, p)
    wf = (r, t) -> [p.v_wind_ref, 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=300_000)
    r = state_report(u, sys, p)
    d = KiteTurbineDynamics.lift_chain_design(sys, p, lift, pos(u, sys.rotor.node_id);
        omega_eq=u[6 * sys.n_total + sys.n_ring + 1])
    @printf("%9.3f %9.3f %6s %8.1f %8.1f %9.1f %9.1f %9.3f %8.1f\n",
        fwd, p.back_anchor_fwd_x, String(r.regime), r.T_back, d.T_cyan, sum(r.per),
        maximum(r.per), r.hub_lat, r.acc_struct)
    @printf("         cone per line: %s\n",
        join((@sprintf("%.1f", x) for x in r.per), " / "))
end
println("\n=== done ===")
