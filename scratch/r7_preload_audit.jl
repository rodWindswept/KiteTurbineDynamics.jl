# scratch/r7_preload_audit.jl — why is the settle's axial preload ~6.5x the run's?
#
# scratch/r7_tension_settle_vs_run.jl measured, on the 5 kW/18.8 m seed:
#   settle  T_seg = 1947,1946,1945,1944,1538,988,740,601 N   Δα_1 = 6.58°
#   run t=20 T_seg =  301, 301, 301, 300, 305,290,237,208 N   Δα_1 = 48.85°
#   τ_seg identical (188,188,188,188,292,596,667,597 vs 188,...)
# so the twist gap is the TENSION ratio, not frame softness (chord 1.187 vs 1.206).
# This script prints the preload the settle *intends* and what it *achieves*.
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
N = sys.n_total
Nr = sys.n_ring
n_seg = Nr - 1

@printf("base params: m_ring=%.4f kg  m_blade=%.4f  n_blades=%d  e_mod=%s  d_tether=%.4f m\n",
    pc.m_ring, pc.m_blade, pc.n_blades, pc.e_modulus, pc.tether_diameter)
@printf("ring node masses (kg): %s\n",
    join(round.([sys.nodes[sys.ring_ids[k]].mass for k in 1:Nr], digits=3), ", "))
@printf("ring radii (m)       : %s\n",
    join(round.([(sys.nodes[sys.ring_ids[k]]::RingNode).radius for k in 1:Nr], digits=4), ", "))
@printf("kite mass = %.2f kg   rotor_radius = %.3f m   L    = %.2f m   elev = %.1f°\n",
    sys.kite.mass, pc.rotor_radius, pc.tether_length, rad2deg(pc.elevation_angle))

# ── exactly what initialisation.jl:966-1008 computes ──────────────────────────
β_r = pc.elevation_angle
T_cyan_des = design_preload_from_sky_anchor(pc, lift)
EA_tot = pc.n_lines * pc.e_modulus * π * (pc.tether_diameter / 2)^2
m_rotor_d = pc.n_blades * pc.m_blade
v_r = pc.v_wind_ref
thrust_r = 0.5 * pc.rho * v_r^2 * π * pc.rotor_radius^2 * 0.8 * cos(β_r)^2
F_aero_z_r = thrust_r * sin(β_r) + (m_rotor_d + sys.kite.mass) * (-9.81)
F_top_ax_r = max(F_aero_z_r / sin(β_r) + T_cyan_des, 20.0)
g_inc = pc.m_ring * 9.81 / sin(β_r)
F_ax = zeros(n_seg)
F_ax[n_seg] = F_top_ax_r
for i in (n_seg - 1):-1:1
    F_ax[i] = F_ax[i + 1] + g_inc
end

@printf("\nT_cyan_des=%.1f N  thrust=%.1f N  F_aero_z=%.1f N  F_top_ax=%.1f N  g_inc=%.2f N\n",
    T_cyan_des, thrust_r, F_aero_z_r, F_top_ax_r, g_inc)
@printf("F_ax intended (total N) : %s\n", join(round.(F_ax, digits=0), ", "))
@printf("F_ax/n_lines (per line) : %s\n", join(round.(F_ax ./ pc.n_lines, digits=0), ", "))

# ── predicted achieved tension from the restore geometry ──────────────────────
EA_rope = pc.e_modulus * π * (pc.tether_diameter / 2)^2
pred = Float64[]
rp = zeros(3)
for k in 1:n_seg
    r_k = (sys.nodes[sys.ring_ids[k]]::RingNode).radius
    r_k1 = (sys.nodes[sys.ring_ids[k + 1]]::RingNode).radius
    chord_3d = ROPE_SUBSEGS * sys.sub_segs[(k - 1) * pc.n_lines * ROPE_SUBSEGS + 1].length_0
    L_seg_k = sqrt(max(chord_3d^2 - (r_k1 - r_k)^2, 0.0))
    k_ax_k = EA_tot / L_seg_k
    stretch = max(0.0, F_ax[k] / k_ax_k)
    chord_new = sqrt((L_seg_k + stretch)^2 + (r_k1 - r_k)^2)
    strain = (chord_new - chord_3d) / chord_3d
    push!(pred, EA_rope * strain)
    @printf("seg %d: L_ax=%.4f  Δr=%.4f  chord0=%.4f  stretch=%.3e m  strain=%.3e  pred T/line=%.1f N\n",
        k, L_seg_k, r_k1 - r_k, chord_3d, stretch, strain, pred[end])
end
@printf("pred T/line             : %s\n", join(round.(pred, digits=0), ", "))

# ── achieved (settle, short relax) ────────────────────────────────────────────
u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
    lift_device=lift, wind_fn=wf, n_op=2_000)
ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
@printf("achieved T/line (n_op=2000): %s\n", join(round.(ef.segment_tension, digits=0), ", "))
@printf("achieved twist (deg)       : %s\n", join(round.(ef.segment_twist_deg, digits=2), ", "))

# ── what tension WOULD give the settle's own target torque at 6.6°? ───────────
@printf("\nFor τ = n·T·r²·sin(Δα)/chord with τ and Δα from the run:\n")
for k in 1:n_seg
    r_a = (sys.nodes[sys.ring_ids[k]]::RingNode).radius
    r_b = (sys.nodes[sys.ring_ids[k + 1]]::RingNode).radius
    r_s = 0.5 * (r_a + r_b)
    for (tag, T, dα) in (("settle", ef.segment_tension[k], deg2rad(ef.segment_twist_deg[k])),)
        chord = sqrt(2.35^2 + 2 * r_s^2 * (1 - cos(dα)))
        τ = pc.n_lines * T * r_s^2 * sin(abs(dα)) / chord
        @printf("  seg %d: r_s=%.3f  T=%.0f  Δα=%.2f°  chord=%.3f  → τ=%.0f N·m\n",
            k, r_s, T, rad2deg(dα), chord, τ)
    end
end
