# sv_probe_preload_budget.jl — software-validator, 2026-10-02
#
# DECIDES: is the 5.15x spread between the winner's design preload (F_top) and the
# "declared regime" figure (1.5*m_airborne*g/sin70) a DEFECT that needs a gate in
# `sv_probe_escalation.jl`'s verdict branch, or a category difference between two
# different lines?
#
# Method: decompose F_top from `lift_chain_design` (src/initialization.jl:1341)
#     T_top = T_thrust + n_lines*T_bridle*cos(theta) - W_rotor*sin(beta)
# on the real winner, and compare the result against the torque-transmission
# requirement of a TRPT shaft (moment = MTR * looping_radius * shaft_tension,
# MTR ~ 0.05 per CLAUDE.md / TRPTSim).
#
# USAGE: scripts/ktd-julia scratch/sv_probe_preload_budget.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WIND_MS = 11.0

lift_for(sys, p) = KTD.sized_lifter_for(sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

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

const LENGTH = 18.8
const CSV = isempty(ARGS) ? joinpath(ROOT, "scripts", "results",
        "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv") : ARGS[1]

x = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
p = params_at_length(LENGTH)
xr = copy(x)
if length(xr) >= 14          # legacy 14-D (canonical_v10, objective_v10.jl:142)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
else                         # canonical 10-D
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))   # n_lines
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))    # rotor_count
end

dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW)
sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p)

println("=== preload budget — ", CSV, " ===")
lift_dev = lift_for(sys, pc)
wf = let p_ = p
    (pos, t) -> begin
        z = max(pos[3], 1.0)
        [WIND_MS * (z / p_.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end
end

println("  settling…")
u_settled = KTD.settle_to_operational_state(sys, copy(u0), pc, 60.0;
    wind_fn=wf, lift_device=lift_dev)
u_settled === nothing && error("settle returned nothing")
ω_eq = u_settled[6 * sys.n_total + sys.n_ring + 1]
τ_eq = sys.k_mppt_ref[] * ω_eq^2

u_design = copy(u0)
KTD.apply_design_bridle_preload!(sys, u_design, pc, lift_dev; omega_eq=ω_eq)
F_ax = KTD.design_axial_preload(sys, pc, lift_dev, u_design; omega_eq=ω_eq, wind_fn=wf)
placement = KTD.trpt_matched_place(sys, pc, F_ax, τ_eq, ω_eq, wf)
hub = placement.ctrs[sys.n_ring]
F_ax2 = KTD.design_axial_preload(sys, pc, lift_dev, u_design; omega_eq=ω_eq,
    wind_fn=wf, hub_pos=hub)

d = KTD.lift_chain_design(sys, pc, lift_dev, hub; omega_eq=ω_eq)
β = pc.elevation_angle
F_top = max(d.T_top, 20.0)

@printf("\n  omega_eq = %.6f rad/s   tau_eq = %.4f N*m   r_hub = %.4f m\n",
    ω_eq, τ_eq, (sys.nodes[sys.rotor.node_id]::RingNode).radius)
@printf("  F_top (also F_ax[end]) = %.3f N\n", F_top)
@printf("\n  -- decomposition of T_top (initialization.jl:1341) --\n")
@printf("  elevation_angle beta = %.6f rad = %.2f deg (parameters.jl:41 — RADIANS)\n",
    β, rad2deg(β))
@printf("  T_thrust (main rotor disc)          = %+10.3f N   (%.1f%% of F_top)\n",
    d.T_thrust, 100 * d.T_thrust / F_top)
@printf("  n_lines * T_bridle * cos(theta)     = %+10.3f N   (n=%d, T_bridle=%.3f, cos th=%.4f)\n",
    pc.n_lines * d.T_bridle * d.cosθ, pc.n_lines, d.T_bridle, d.cosθ)
@printf("  -W_rotor * sin(beta)                = %+10.3f N   (W_rotor=%.3f, sin b=%.6f)\n",
    -d.W_rotor * sin(β), d.W_rotor, sin(β))
@printf("  ------------------------------------------\n")
@printf("  sum                                 = %+10.3f N   (d.T_top = %.3f, delta %.3e)\n",
    d.T_thrust + pc.n_lines * d.T_bridle * d.cosθ - d.W_rotor * sin(β), d.T_top,
    d.T_thrust + pc.n_lines * d.T_bridle * d.cosθ - d.W_rotor * sin(β) - d.T_top)
@printf("\n  -- the two lines being compared --\n")
@printf("  T_cyan (lift/cyan line tension)     = %10.3f N\n", d.T_cyan)
@printf("  T_back (back line tension)          = %10.3f N   (back_taut=%s)\n",
    d.T_back, d.back_taut)
@printf("  T_cyan_ax (axial on bearing)        = %10.3f N\n", d.T_cyan_ax)
m_air = KTD.expansion_airborne_mass(sys, pc; include_lifter=false)
F_regime = 1.5 * m_air * 9.81 / sind(70.0)
@printf("  F_regime = 1.5*m_air*g/sin70        = %10.3f N   (m_air=%.3f kg)\n",
    F_regime, m_air)

@printf("\n  -- is F_top the shaft tension the torque demands? --\n")
mtr_implied = τ_eq / ((sys.nodes[sys.rotor.node_id]::RingNode).radius * F_top)
@printf("  implied MTR = tau_eq / (r_hub * T_top) = %.6f   (documented TRPT MTR ~ 0.05)\n",
    mtr_implied)
@printf("  T_top / F_regime                       = %.6f\n", F_top / F_regime)
@printf("  T_cyan / F_regime                      = %.6f\n", d.T_cyan / F_regime)
