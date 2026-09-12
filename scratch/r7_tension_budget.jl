# scratch/r7_tension_budget.jl — R7 evidence: decompose the ODE TRPT line tension.
# Rod's question: why is the ODE line tension ~2.5x the static thrust estimate?
using KiteTurbineDynamics, Printf
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
x = [0.08, 0.055, 1.0, 1.0, 2.4, 0.5751, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=0.75^(1 / 3))
cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055)
sizing = size_beams_closed_form(dec, p, cfg)

sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
wf = (r, t) -> [11.0, 0.0, 0.0]
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=30_000)
for _ in 1:2
    run_canonical_sim!(u, sys, pc, wf, round(Int, 5.0 / dt), dt; lift_device=lift, lin_damp=0.05)
end
ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 10.0, wf, lift)

n_l = pc.n_lines
ω_hub = u[6 * sys.n_total + sys.n_ring + 1]
v_hub = 11.0 * sys.rotor.wind_factor
λ_t = abs(ω_hub) * sys.rotor.radius / v_hub
ct = KiteTurbineDynamics.ct_at_tsr(λ_t)
A_main = KiteTurbineDynamics.main_rotor_swept_area(sys)
T_main_ode = 0.5 * p.rho * v_hub^2 * A_main * ct * cos(p.elevation_angle)^2
# ODE expansion-rotor axial forces at the settled state
T_exp = Ref(0.0)
for er in sys.expansion_rotors
    r_nom = (sys.nodes[sys.ring_ids[er.ring_idx]]::RingNode).radius
    s = er.ring_idx - 1
    T_est = s >= 1 ? sum(KiteTurbineDynamics.get_segment_tension(u, sys, p, s, j) for j in 1:n_l) / n_l : 100.0
    _, F_ax, _, _, _ = KiteTurbineDynamics.expansion_rotor_forces(
        er, p.rho, 11.0, ω_hub, 30.0, r_nom, T_est, n_l)
    T_exp[] += F_ax
end
@printf("ODE main rotor: v_hub=%.2f  lambda=%.2f  ct=%.3f  A=%.2f m^2  T_main=%.0f N\n",
    v_hub, λ_t, ct, A_main, T_main_ode)
@printf("ODE expansion axial total = %.0f N   =>  total thrust = %.0f N (%.0f N/line)\n",
    T_exp[], T_main_ode + T_exp[], (T_main_ode + T_exp[]) / n_l)
@printf("sizing static T_line[1] = %.0f N/line   lifter T_ref = %.0f N (%.0f N/line)\n",
    sizing.T_line_per_ring[1], lift.T_ref, lift.T_ref / n_l)
@printf("ODE T_line[seg1] = %.0f N/line\n", ef.segment_tension[1])
println()
println("seg | T_ode(N) | T_sizing(N) | thrust_above/n | FEA N_comp")
for s in 1:length(ef.segment_tension)
    # FEA frames are rings 2..end; segment s lower ring = s+1 -> frame index s
    Nc = s <= length(ef.ring_Ncomp) ? ef.ring_Ncomp[s] : NaN
    @printf(" %2d | %8.1f | %11.1f | %14.1f | %10.1f\n",
        s, ef.segment_tension[s],
        s + 1 <= length(sizing.T_line_per_ring) ? sizing.T_line_per_ring[s + 1] : NaN,
        (T_main_ode + T_exp[]) / n_l, Nc)
end
@printf("\nFEA N_comp / ODE T_line: %s\n",
    join([@sprintf("%.3f", ef.ring_Ncomp[k] / ef.segment_tension[k]) for k in 1:min(length(ef.ring_Ncomp), length(ef.segment_tension))], ", "))
