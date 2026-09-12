# scratch/r7_node_shape.jl — do the running rope nodes deviate from the straight
# chord the settle assumes? If so the settle's torsion model is too stiff.
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
                           tether_length=18.8)
end

p = params_5kw_188()
x = seed_genome(5.0)
x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    k_mppt=K_MPPT_5KW_HONEST)
sizing = size_beams_closed_form(dec, p, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=30_000)
N = sys.n_total; Nr = sys.n_ring
shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

function shape(tag)
    # segment 1 (ground→ring2), line 1: interior node gids 2,3,4
    ga = sys.ring_ids[1]; gb = sys.ring_ids[2]
    ca = u[(3*(ga-1)+1):(3*ga)]; cb = u[(3*(gb-1)+1):(3*gb)]
    αa = u[6N + 1]; αb = u[6N + 2]
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, sys.rotor.node_id,
        (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx)
    na = sys.nodes[ga]::RingNode; nb = sys.nodes[gb]::RingNode
    pa = KiteTurbineDynamics.attachment_point(ca, na.radius, αa, 1, p.n_lines, pp1, pp2)
    pb = KiteTurbineDynamics.attachment_point(cb, nb.radius, αb, 1, p.n_lines, pp1, pp2)
    chord = pb .- pa
    devs = Float64[]
    for m in 1:ROPE_NODES_PER_LINE
        gid = 2 + (m - 1)
        pn = u[(3*(gid-1)+1):(3*gid)]
        frac = m / ROPE_SUBSEGS
        straight = pa .+ frac .* chord
        push!(devs, norm(pn .- straight))
    end
    @printf("%-8s ring1 α=%6.2f° ring2 α=%6.2f° δ=%5.2f°  node dev from straight = %s m  |chord|=%.3f\n",
        tag, rad2deg(αa), rad2deg(αb), rad2deg(αb - αa),
        join(round.(devs, digits=4), ","), norm(chord))
end
shape("settle")
for k in 1:4
    run_canonical_sim!(u, sys, pc, wf, round(Int, 5.0 / dt), dt; lift_device=lift, lin_damp=0.05)
    shape("t=$(5k)s")
end
