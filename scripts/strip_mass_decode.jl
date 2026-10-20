#!/usr/bin/env julia
# scripts/strip_mass_decode.jl
#
# Decode-only airborne mass for the seven machine-evolution-strip panels
# (figure map row 9).  No simulation: design decode -> closed-form beam sizing
# -> build_system_from_v10 -> expansion_airborne_mass, once per panel.
#
# Why this exists: island_3/telemetry.csv records no mass column, so the
# per-panel mass the strip's metric cards need cannot be read from the
# extract.  The campaign scored every genome on this same quantity
# (objective_evaluator.jl:1154), so a decode-only pass reproduces it exactly
# rather than estimating it.
#
# Knobs mirror scripts/run_v13_5kw_masslift.jl exactly: era
# post-95c385d_wind-authority, length 18.8, k_mppt 2.24, rotor_count_mode,
# cylinder_cone, power_split 0.6, cone 22 deg, spacing 0.8, 2 mm wall floor.
#
# The second column set is an independent route to the same numbers: the
# recorded fitness is mass plus three analytic penalties, all of whose inputs
# are recorded columns, so mass = fitness - penalties is an upper bound whose
# slack is the stationarity term (P_range is not recorded).  The penalty is
# charged on P_end, the value the score used (objective_evaluator.jl:1153).
#
# Output: docs/reporting/figures/machine-evolution-strip/extract-mass.csv
# Usage:  julia --project=. scripts/strip_mass_decode.jl
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, CSV
include(joinpath(@__DIR__, "compute_seeds.jl"))
const KTD = KiteTurbineDynamics

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const MIN_WALL_M = 2e-3

const ROOT = dirname(@__DIR__)
const KIT = joinpath(ROOT, "docs", "reporting", "figures", "machine-evolution-strip")
const EXTRACT = joinpath(KIT, "extract-best-so-far.csv")
const OUT = joinpath(KIT, "extract-mass.csv")

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

p_base = params_at_length(LENGTH)
cfg = ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED,
    p_floor_kw=5.0, p_ceiling_kw=5.0,
    relax_s=10.0, window_s=40.0,
    fos_target=2.5, fos_hard=2.5,
    power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0, k_mppt=K_MPPT_5KW_HONEST,
    tether_diameter=p_base.tether_diameter,
    rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    min_wall_m=MIN_WALL_M,
)

# ── Provenance ───────────────────────────────────────────────────────────
git_head() = try
    chomp(read(`git -C $(ROOT) rev-parse HEAD`, String))
catch
    "unknown"
end
const DECODE_COMMIT = git_head()

rows = CSV.File(EXTRACT; comment="#")
buf = IOBuffer()
println(buf, "# machine-evolution-strip / extract-mass.csv")
println(buf, "# decoding commit: $(DECODE_COMMIT)")
println(buf, "# era: post-95c385d_wind-authority | dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2 | data commit dd3cc6a | launch a76c5e9")
println(buf, "# extract: extract-best-so-far.csv")
println(buf, "# source: decode-only (design_from_vector_v10 -> size_beams_closed_form -> build_system_from_v10 -> expansion_airborne_mass)")
println(buf, "# mass is the quantity the campaign scored (objective_evaluator.jl:1154); it carries the 5.0 kg lifter (include_lifter default true)")
println(buf, "# residual = (fitness - penalties) - mass = the stationarity term, 10*max(0, P_range/P_mean - 0.2); P_range is not recorded, so it is a bound")
println(buf, "# penalties are charged on P_end, the value the score used (objective_evaluator.jl:1153)")
@printf(buf, "panel,selected_gen,label,objective_kg_eq,mass_kg,mass_kg_nolifter,pen_overpower_kg,pen_twist_kg,pen_utilisation_kg,pen_total_kg,residual_kg\n")
for r in rows
    x = Float64[r.x1, r.x2, r.x3, r.x4, r.x5, r.x6, r.x7, r.x8, r.x9, r.x10]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    res = KTD.design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base;
        power_W=PW, cylinder_cone=true, rotor_count_mode=true,
        power_split=cfg.power_split, cone_slope_deg=cfg.cone_slope_deg,
        rotor_spacing_frac=cfg.rotor_spacing_frac, blocking_factor=cfg.blocking_factor)
    sizing = KTD.size_beams_closed_form(res, p_base, cfg)
    sys, u0, pc = KTD.build_system_from_v10(res, 1.0, cfg.k_mppt;
        tether_diameter=cfg.tether_diameter, base_params=p_base,
        min_wall_m=cfg.min_wall_m, beam_sizing=sizing)
    m = KTD.expansion_airborne_mass(sys, pc)
    m_nolift = KTD.expansion_airborne_mass(sys, pc; include_lifter=false)
    # Decode identity check against the extract's recorded decoded fields.
    @assert pc.n_lines == r.n_lines "n_lines mismatch panel $(r.panel)"
    @assert pc.n_rings == r.rings "n_rings mismatch panel $(r.panel)"
    @assert isapprox(res.design.r_hub, Float64(r.r_hub); atol=5e-4) "r_hub mismatch panel $(r.panel)"
    @assert res.n_active == r.n_active "n_active mismatch panel $(r.panel)"
    fit = Float64(r.fitness); P = Float64(r.P_end); fos = Float64(r.FoS); tr = Float64(r.twist_ratio)
    po = 5.0 * max(P - 5.0, 0.0)^2
    pt = (tr / max(1 - tr, 1e-9))^2
    pu = 20.0 * (2.5 / fos)^2
    @printf(buf, "%d,%d,%s,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n",
        r.panel, r.selected_gen, r.label, fit, m, m_nolift, po, pt, pu, po + pt + pu,
        (fit - po - pt - pu) - m)
end

open(OUT, "w") do io
    write(io, String(take!(buf)))
end
println(read(OUT, String))
