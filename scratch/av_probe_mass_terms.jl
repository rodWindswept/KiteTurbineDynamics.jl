# scratch/av_probe_mass_terms.jl — aero-validator, 2026-10-02
#
# DECIDES: which mass the campaign's score actually charges, term by term, on the
# evaluator's OWN build path.  Closes (or names) the 0.76 kg residual software-
# validator could not account for: a reproduced score of 21.6983 decomposes to a
# mass term of 20.2134 kg, against 19.4508 kg measured on the closed-form build.
#
# WHY the terms can differ between two "closed-form" builds: the ONLY mass source
# in `appropriate_mass_fitness` is `m_airborne = expansion_airborne_mass(sys, pc)`
# (objective_evaluator.jl:1082), and that function reads `p.n_blades`, `p.m_blade`,
# `p.tether_length` and `p.tether_diameter` from the PARAMS OBJECT it is handed
# (expansion_analysis.jl:44-77) — not from `sys`.  So a build handed the base
# params `p` and one handed the design-decked `pc` charge DIFFERENT blade/tether
# mass for the same machine.  This probe prints both.
#
# Also: `m_lifter` is a hard-coded 5.0 kg (expansion_analysis.jl:74) and the
# kwarg defaults to `include_lifter=true`, which is what the evaluator gets.
#
# USAGE: scripts/ktd-julia scratch/av_probe_mass_terms.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
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
const bf = BLOCKING_WIND_FACTOR_5KW
xv = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
# 10-field canonical genome ⇒ canonical integer positions.
xv[4] = Float64(round(Int, clamp(xv[4], 3, 16)))
xv[6] = Float64(round(Int, clamp(xv[6], 1, 3)))

dec = design_from_vector_v10(
    xv, PROFILE_ELLIPTICAL, p; power_W=PW,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=bf,
)
cfg = KTD.ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED, p_floor_kw=KW, fos_target=2.5, fos_hard=2.5,
    min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=bf,
)
sizing = KTD.size_beams_closed_form(dec, p, cfg)
sys, u0, pc = KTD.build_system_from_v10(
    dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
    beam_sizing=sizing,
)

println("=== mass terms, evaluator build path ===")
@printf("sys: n_ring=%d n_total=%d  ring_mass_total=%.6f kg  ring_knuckle_mass=%.6f kg\n",
    sys.n_ring, sys.n_total, sys.ring_mass_total[], sys.ring_knuckle_mass[])
@printf("expansion rotors on sys = %d   (sum of their mass = %.6f kg)\n",
    length(sys.expansion_rotors), sum(er -> er.mass, sys.expansion_rotors; init=0.0))
@printf("base  p : n_blades=%d m_blade=%.6f kg  n_lines=%d  tether D=%.6f L=%.3f\n",
    p.n_blades, p.m_blade, p.n_lines, p.tether_diameter, p.tether_length)
@printf("design pc: n_blades=%d m_blade=%.6f kg  n_lines=%d  tether D=%.6f L=%.3f\n",
    pc.n_blades, pc.m_blade, pc.n_lines, pc.tether_diameter, pc.tether_length)

function terms(pobj)
    m_tether = pobj.n_lines * pobj.tether_length *
               (KTD.DYNEEMA_DENSITY * π * (pobj.tether_diameter / 2)^2)
    m_rings = sys.ring_mass_total[] > 0.0 ? sys.ring_mass_total[] :
              (sys.n_ring - 1) * pobj.m_ring
    m_blades = pobj.n_blades * pobj.m_blade
    m_expansion = sum(er -> er.mass, sys.expansion_rotors; init=0.0)
    n_blade_nodes = pobj.n_blades + sum(er -> er.n_blades, sys.expansion_rotors; init=0.0)
    m_knuckles = n_blade_nodes * KTD.OPT_KNUCKLE_MASS_KG + sys.ring_knuckle_mass[]
    m_lifter = 5.0
    return (; m_tether, m_rings, m_blades, m_expansion, m_knuckles, m_lifter)
end

for (label, pobj) in (("base  p", p), ("design pc", pc))
    t = terms(pobj)
    tot_nl = t.m_tether + t.m_rings + t.m_blades + t.m_expansion + t.m_knuckles
    @printf("\n-- %s --\n", label)
    @printf("  m_tether    %10.6f\n  m_rings     %10.6f\n  m_blades    %10.6f  (%d x %.6f)\n",
        t.m_tether, t.m_rings, t.m_blades, pobj.n_blades, pobj.m_blade)
    @printf("  m_expansion %10.6f\n  m_knuckles  %10.6f\n  m_lifter    %10.6f\n",
        t.m_expansion, t.m_knuckles, t.m_lifter)
    @printf("  TOTAL include_lifter=true  %10.6f kg\n  TOTAL include_lifter=false %10.6f kg\n",
        tot_nl + t.m_lifter, tot_nl)
end

@printf("\n-- what the evaluator charges (objective_evaluator.jl:1082, default kwarg) --\n")
@printf("  expansion_airborne_mass(sys, pc)                  = %.6f kg\n",
    KTD.expansion_airborne_mass(sys, pc))
@printf("  expansion_airborne_mass(sys, pc; include_lifter=false) = %.6f kg\n",
    KTD.expansion_airborne_mass(sys, pc; include_lifter=false))
@printf("  expansion_airborne_mass(sys, p)                   = %.6f kg  (base params, for contrast)\n",
    KTD.expansion_airborne_mass(sys, p))
@printf("\nreference: reproduced score 21.6983 - penalties 1.4849 = mass term 20.2134 kg\n")
@printf("           software-validator's closed-form build 19.4508 (with lifter) / 14.4508 (without)\n")
