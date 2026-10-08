# av_b2_mass_recon.jl — aero-validator. Reconcile the committed winner-pack mass
# cross-check (bankderate2 island 3) against the Phase 0 audit section 4 physics
# mass. Both claim the same machine and the same charge; this probe rebuilds the
# machine twice, once with the pack's cfg and once with the runner cfg, and
# prints both expansion_airborne_mass readings plus the beam sizings.
# Records-only chain: decode + build + mass, no ODE.
using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const BF = BLOCKING_WIND_FACTOR_5KW

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const P_BASE = params_at_length(LENGTH)

csv = joinpath(dirname(@__DIR__), "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2", "island_3", "best_vector.csv")
x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
xr = copy(x)
xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
println("genome (evaluated) = ", xr)
@printf("P_BASE.v_wind_ref = %.6f  (decode default)  | cfg.v_rated = %.1f\n",
    P_BASE.v_wind_ref, V_RATED)

# ── (a) pack chain: minimal cfg, t_over_D = 0.055, decode WITHOUT v_rated ────
dec_a = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, P_BASE; power_W=PW,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BF)
cfg_pack = KTD.ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED, p_floor_kw=KW, fos_target=2.5, fos_hard=2.5,
    min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=BF,
)
sizing_a = KTD.size_beams_closed_form(dec_a, P_BASE, cfg_pack)
sys_a, u0_a, pc_a = KTD.build_system_from_v10(dec_a, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=P_BASE.tether_diameter, base_params=P_BASE, min_wall_m=2e-3,
    beam_sizing=sizing_a)
m_a = KTD.expansion_airborne_mass(sys_a, pc_a)
@printf("(a) pack cfg    : decode n_lines=%d rings=%d n_active=%d r_hub=%.5f | mass=%.6f kg\n",
    dec_a.design.n_lines, dec_a.n_rings, dec_a.n_active, dec_a.design.r_hub, m_a)
for r in dec_a.rotors
    @printf("    (a) rotor ring=%d r_rotor=%.6f m v_wind=%.6f\n", r.ring_idx, r.r_rotor, r.v_wind)
end

# ── (b) runner chain: the audit mirror cfg, decode WITH v_rated = 11.0 ───────
dec_b = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, P_BASE; power_W=PW,
    v_rated=V_RATED,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BF)
cfg_run = KTD.ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED,
    p_floor_kw=5.0, p_ceiling_kw=5.0,
    relax_s=10.0, window_s=40.0,
    fos_target=2.5, fos_hard=2.5,
    power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0,
    k_mppt=K_MPPT_5KW_HONEST,
    tether_diameter=P_BASE.tether_diameter,
    rotor_count_mode=true,
    power_split=0.6,
    cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
    blocking_factor=BF,
    min_wall_m=2e-3,
)
sizing_b = KTD.size_beams_closed_form(dec_b, P_BASE, cfg_run)
sys_b, u0_b, pc_b = KTD.build_system_from_v10(dec_b, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=P_BASE.tether_diameter, base_params=P_BASE, min_wall_m=2e-3,
    beam_sizing=sizing_b)
m_b = KTD.expansion_airborne_mass(sys_b, pc_b)
@printf("(b) runner cfg  : decode n_lines=%d rings=%d n_active=%d r_hub=%.5f | mass=%.6f kg\n",
    dec_b.design.n_lines, dec_b.n_rings, dec_b.n_active, dec_b.design.r_hub, m_b)
for r in dec_b.rotors
    @printf("    (b) rotor ring=%d r_rotor=%.6f m v_wind=%.6f\n", r.ring_idx, r.r_rotor, r.v_wind)
end
@printf("m_b full = %.16f kg\n", m_b)

@printf("delta (b - a) = %.6f kg\n", m_b - m_a)
@printf("audit target  = 25.69846825623688 kg | pack file target = 25.6701 kg\n")
if hasproperty(cfg_pack, :t_over_D) && hasproperty(cfg_run, :t_over_D)
    @printf("t_over_D: pack=%.4f runner=%.4f\n", cfg_pack.t_over_D, cfg_run.t_over_D)
end
println("AV_MASS_RECON_DONE")
