# scratch/r7_mode_id.jl — what oscillates with the transmission-ring load?
# Sample N_comp(ring 2) against candidate state variables and correlate.
using KiteTurbineDynamics, Printf, Statistics, LinearAlgebra
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

# ring-center lateral (perp-to-shaft) displacement, measured from the ground axis
shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
perp = [0.0, 1.0, 0.0]
function ring_lat(k)
    gid = sys.ring_ids[k]
    c = u[(3 * (gid - 1) + 1):(3 * gid)]
    z = dot(c, shaft)
    return norm(c .- z .* shaft)
end

rows = Float64[]
for _ in 1:60                       # 60 samples × 0.5 s = 30 s
    run_canonical_sim!(u, sys, pc, wf, round(Int, 0.5 / dt), dt; lift_device=lift, lin_damp=0.05)
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
    tr = KiteTurbineDynamics.twist_collapse_check(u, sys)
    b = sys.bearing_id
    bpos = u[(3 * (b - 1) + 1):(3 * b)]
    kite = sys.kite_pos
    push!(rows, ef.ring_Ncomp[1], tr.max_ratio, ring_lat(2), ring_lat(6), ring_lat(9),
        u[6N + Nr + 1], u[6N + Nr + Nr], norm(bpos), norm(kite .- bpos))
end
M = reshape(rows, 9, :)           # 9 variables × 60 samples
labels = ["N_ring2", "twist_ratio", "ring2_lat", "ring6_lat", "ring9_lat",
          "w_gnd", "w_hub", "bearing_r", "kite_bearing_dist"]
function corr(a, b)
    sa = std(a); sb = std(b)
    (sa < 1e-12 || sb < 1e-12) && return 0.0
    return sum((a .- mean(a)) .* (b .- mean(b))) / ((length(a) - 1) * sa * sb)
end
println("correlation of N_ring2 with:")
for i in 2:9
    @printf("  %-20s  r = %+.3f   (range %.3g .. %.3g)\n", labels[i], corr(M[1, :], M[i, :]),
        minimum(M[i, :]), maximum(M[i, :]))
end
@printf("  N_ring2 range = %.1f .. %.1f\n", minimum(M[1, :]), maximum(M[1, :]))
