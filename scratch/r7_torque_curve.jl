# scratch/r7_torque_curve.jl — settle's torque-vs-twist function vs the ODE's own
# rope-force torque on ring 1, over a twist sweep. Decides whether the settle
# function is mis-scaled or non-monotone (wrong root picked).
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
@printf("tau_gen = k*w^2 = %.1f N*m   (k=%.2f, w=%.3f)\n",
    sys.k_mppt_ref[] * u[6N + Nr + 1]^2, sys.k_mppt_ref[], u[6N + Nr + 1])

# settle's tau_fn_a for segment 1 (ground -> ring 2), line 1 only for speed? No —
# sum over all lines, exactly as the settle does.
EA_rope = p.e_modulus * π * (p.tether_diameter / 2)^2
L_seg_s = ROPE_SUBSEGS * sys.sub_segs[1].length_0
gid_a = sys.ring_ids[1]; gid_b = sys.ring_ids[2]
na = sys.nodes[gid_a]::RingNode; nb = sys.nodes[gid_b]::RingNode
ca = u[(3*(gid_a-1)+1):(3*gid_a)]; cb = u[(3*(gid_b-1)+1):(3*gid_b)]
α1 = u[6N + 1]
pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, sys.rotor.node_id,
    (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx)
sd = normalize(cb .- ca)
function settle_tau(δ)
    τ = 0.0
    for j in 1:p.n_lines
        pa = KiteTurbineDynamics.attachment_point(ca, na.radius, α1, j, p.n_lines, pp1, pp2)
        pb = KiteTurbineDynamics.attachment_point(cb, nb.radius, α1 + δ, j, p.n_lines, pp1, pp2)
        ch = norm(pb .- pa); ch < 1e-9 && continue
        T = EA_rope * max(0.0, (ch - L_seg_s) / L_seg_s)
        d = (pb .- pa) ./ ch
        τ += T * dot(cross(pa .- ca, d), sd)
    end
    return τ
end
# ODE's rope-force torque on ring 1 for the same trial twist.
forces = [zeros(3) for _ in 1:N]; torques = zeros(Nr)
function ode_tau(δ)
    uu = copy(u); uu[6N + 2] = uu[6N + 1] + δ
    for j in 1:p.n_lines, m in 1:ROPE_NODES_PER_LINE
        gid = 2 + (j - 1) * ROPE_NODES_PER_LINE + (m - 1)
        pa = KiteTurbineDynamics.attachment_point(ca, na.radius, uu[6N+1], j, p.n_lines, pp1, pp2)
        pb = KiteTurbineDynamics.attachment_point(cb, nb.radius, uu[6N+2], j, p.n_lines, pp1, pp2)
        uu[(3*(gid-1)+1):3*gid] .= pa .+ (m / ROPE_SUBSEGS) .* (pb .- pa)
    end
    for f in forces; fill!(f, 0.0); end
    fill!(torques, 0.0)
    KiteTurbineDynamics.compute_rope_forces!(forces, torques, uu, @view(uu[(6N+1):(6N+Nr)]),
        sys, p, wf, 0.0, pp1, pp2)
    return torques[1]
end

println("  δ(deg) | settle τ_fn | ODE rope τ (ring1)")
for δdeg in (0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80)
    δ = deg2rad(δdeg)
    @printf("  %5d  | %10.1f  | %10.1f\n", δdeg, settle_tau(δ), ode_tau(δ))
end
