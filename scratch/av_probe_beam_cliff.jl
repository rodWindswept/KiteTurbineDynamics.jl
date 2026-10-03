# scratch/av_probe_beam_cliff.jl — aero-validator, 2026-10-02
#
# DECIDES: is the ~2.4 kg structural step between blade λ 0.690 and 0.680 (bank 0)
# a SIZING discontinuity, or does it come from the settle/window?  The whole
# cliff lives in `size_beams_closed_form` (trpt_optimization.jl:278), which is a
# pure function of the decode — no settle, no ODE.  So the step can be located
# here in seconds and either confirmed as a sizing feature or ruled out.
#
# Candidate mechanisms, both visible below:
#   1. the equilibrium-speed solve (trpt_optimization.jl:315-325).  NOTE the
#      coupling: `k_mppt_eff = p_base.k_mppt * blade_scale^2` (:318-320), so the
#      solved ω and hence every ring load moves with λ; ω = 0 on a failed solve.
#   2. the tube floor `min_Do_m = MIN_RING_DO_M = 0.010 m` (:217, applied in the
#      sizing) — rings sitting ON the floor are the tell-tale.
#
# USAGE: scripts/ktd-julia scratch/av_probe_beam_cliff.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const LENGTH = 18.8
const CSV = joinpath(
    ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv"
)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev
    )
    back = BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout
    )
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const p = params_at_length(LENGTH)
const BASE = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
BASE[4] = Float64(round(Int, clamp(BASE[4], 3, 16)))
BASE[6] = Float64(round(Int, clamp(BASE[6], 1, 3)))

cfg = KTD.ObjectiveConfig(;
    power_W=PW, v_rated=11.0, p_floor_kw=KW, fos_target=2.5, fos_hard=2.5,
    min_wall_m=2e-3, t_over_D=0.055, rotor_count_mode=true, power_split=0.6,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
)

println("floors in play: MIN_RING_DO_M = $(KTD.MIN_RING_DO_M) m, min wall = 2e-3 m,",
    " SIZING_FOS_MARGIN = $(KTD.SIZING_FOS_MARGIN), HELIX = $(KTD.HELIX_LOAD_FACTOR)")
@printf("anchor: bank 0, blade scale λ — winner's λ = %.6f\n\n", BASE[9])

# Swept area is bank-independent; A(λ) = π·s·(2·r_ring + 0.4·s), s = 0.75·r_rotor·λ.
function area_at(lam)
    x = copy(BASE); x[7] = 0.0; x[9] = lam
    dec = design_from_vector_v10(
        x, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    rot = dec.rotors[1]
    rr = dec.radii[rot.ring_idx]
    s = rot.blade_tip_radius / 0.7
    return π * ((rr + 0.7 * s)^2 - (rr - 0.3 * s)^2)
end
const A0 = area_at(BASE[9])            # the winner's area at bank 0 (same λ)
const DERATE_TARGET = 1.0 / cosd(BASE[7])^2.65   # bank 0 vs the winner's 10.74°

shown_meta = Ref(true)
@printf("%7s  %8s  %9s  %9s  %8s  %8s  %6s  %6s  %8s  %9s\n",
    "λ", "span", "A/A0", "ring_kg", "blade_kg", "sum_kg", "omega", "FoS", "N_comp", "pred P")
println("-"^88)

for lam in (0.72, 0.71, 0.70, 0.695, 0.690, 0.685, 0.680, 0.675, 0.670,
    0.665, 0.660, 0.650, 0.640, 0.60)
    x = copy(BASE)
    x[7] = 0.0       # bank 0
    x[9] = lam       # blade_scale_top
    dec = design_from_vector_v10(
        x, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    sizing = KTD.size_beams_closed_form(dec, p, cfg)
    if shown_meta[]
        println("sizing fields: ", propertynames(sizing))
        shown_meta[] = false
    end
    sys, u0, pc = KTD.build_system_from_v10(
        dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
        beam_sizing=sizing,
    )
    rot = dec.rotors[1]
    span = rot.blade_tip_radius / 0.7
    m_blade_total = 3 * 0.420 * span^3
    Do = sizing.Do_per_ring
    onfloor = count(d -> d <= KTD.MIN_RING_DO_M + 1e-9, Do)
    ring_kg = sys.ring_mass_total[]
    Arat = area_at(lam) / A0
    pred_P = 5.114485 * Arat * DERATE_TARGET
    @printf("%7.4f  %8.4f  %9.5f  %9.4f  %9.4f  %8.4f  %7.4f  %7.3f  %8.2e  %7.4f kW\n",
        lam, span, Arat, ring_kg, m_blade_total, ring_kg + m_blade_total,
        sizing.omega_eq, minimum(sizing.fos_per_ring), maximum(sizing.N_comp_per_ring), pred_P)
end

println("-"^88)
println("floor column = rings sitting on MIN_RING_DO_M (0.010 m); sum_kg = rings + 3 blades only.")
println("pred P = measured 5.114485 kW scaled by area and the bank derate back to 0°.")
