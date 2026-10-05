# scratch/av_probe_cp_fix_verify.jl — @aero-validator, 2026-10-05
#
# Post-fix verification + re-derivation evidence for the measured sizing
# surface (branch cp-sizing-measured-surface, from f225e95).  The tree is NOT
# patched: this runs the fixed src/ directly.
#
# Section 1: betz §4 re-derivation — island3 winner decode → build → the values
#            test_betz_ceiling_projection.jl pins (radius, hub, raw annulus,
#            A_zn, the two Betz kW pins) under the corrected sizing.
# Section 2: S2 n-sweep static spans/A_ZY vs the closed-form predictions
#            recorded in docs/validation/2026-10-05-cp-span-structure-and-resize.md
#            (asserted; [expected] lists from that record).
# Section 3: the trpt realisability fixture (SEED_LR20, L/r 2.0) re-derived —
#            the seventh re-baseline's pins, asserted against
#            test_trpt_realisability.jl §A/§A2.
#
# USAGE: scripts/ktd-julia scratch/av_probe_cp_fix_verify.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const ROOT = dirname(@__DIR__)
println("tree: ", chomp(read(`git -C $ROOT rev-parse --short HEAD`, String)))
println("cp_bem(3,4.1) = ", KTD.BEM.cp_bem(3, 4.1), "  (expect 0.295535)")
@assert isapprox(KTD.BEM.cp_bem(3, 4.1), 0.295535; atol = 1e-6)
println("cp_bem(8,4.1) = ", KTD.BEM.cp_bem(8, 4.1), "  (expect 0.260451)")
@assert isapprox(KTD.BEM.cp_bem(8, 4.1), 0.260451; atol = 5e-4)

# ── Section 1: betz §4 pins under the corrected sizing ──────────────────────

const WINNER_CSV = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv")
x = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
d = decode_winner(x; L=18.8, KW=5.0)
println("\n[1] island3 winner: x[4] = ", x[4], "  decoded n_lines = ", d.dec.design.n_lines)
sys, _u0, _pc = KTD.build_system_from_v10(d.dec, 1.0, d.k_mp;
    tether_diameter=d.p.tether_diameter, base_params=d.p)
raw = π * (sys.rotor.radius^2 - sys.rotor.blade_hub_radius^2)
A_bank = KTD.main_rotor_bank_projected_area(sys)
A_zn = KTD.betz_wind_normal_area(sys, d.p)
@printf("radius           = %.15f\n", sys.rotor.radius)
@printf("blade_hub_radius = %.15f\n", sys.rotor.blade_hub_radius)
@printf("bank_angle_deg   = %.10f\n", sys.rotor.bank_angle_deg)
@printf("raw_annulus      = %.15f\n", raw)
@printf("A_bank           = %.15f\n", A_bank)
@printf("A_zn             = %.15f\n", A_zn)
@printf("A_ZY (raw*cos30) = %.15f\n", raw * cos(d.p.elevation_angle))
@printf("betz_raw_kW      = %.15f\n", 0.593 * 0.5 * d.p.rho * raw * 11.0^3 / 1000.0)
@printf("betz_zn_kW       = %.15f\n", 0.593 * 0.5 * d.p.rho * A_zn * 11.0^3 / 1000.0)

# ── Section 2: S2 static n-sweep vs the 2026-10-05 record ───────────────────

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

p_base = params_at_length(LENGTH)
beam_profile = PROFILE_ELLIPTICAL

cfg = KTD.ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED,
    p_floor_kw=5.0, p_ceiling_kw=5.0,
    relax_s=10.0, window_s=40.0,
    fos_target=2.5, fos_hard=2.5,
    power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0,
    k_mppt=K_MPPT_5KW_HONEST,
    tether_diameter=p_base.tether_diameter,
    rotor_count_mode=true,
    power_split=0.6,
    cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
    blocking_factor=BF,
    min_wall_m=2e-3,
)

function s2case(nl::Int)
    xx = copy(x)
    xx[4] = Float64(nl)
    xx[1] = 4.32
    xx[9] = 1.0
    return xx
end

const EXPECTED_SPAN = Dict(3 => 1.4916, 4 => 1.4339, 5 => 1.4382, 6 => 1.4725, 7 => 1.5244, 8 => 1.5889, 9 => 1.6644)
const EXPECTED_AZY = Dict(3 => 36.7885, 4 => 35.2749, 5 => 35.3866, 6 => 36.2831, 7 => 37.6504, 8 => 39.3532, 9 => 41.35)

function verify_s2(x, p_base, beam_profile, cfg)
    println("\n[2] S2 static n-sweep under the fixed tree (vs the 2026-10-05 record):")
    ok = true
    for n in 3:9
        xc = s2case(n)
        dec = KTD.design_from_vector_v10(xc, beam_profile, p_base; power_W=PW,
            cylinder_cone=true, rotor_count_mode=true,
            power_split=cfg.power_split, cone_slope_deg=cfg.cone_slope_deg,
            rotor_spacing_frac=cfg.rotor_spacing_frac, blocking_factor=cfg.blocking_factor)
        sizing = KTD.size_beams_closed_form(dec, p_base, cfg)
        sysn, _u, _pcx = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
            tether_diameter=p_base.tether_diameter, base_params=p_base, min_wall_m=2e-3,
            beam_sizing=sizing)
        span = sysn.rotor.radius - sysn.rotor.blade_hub_radius
        azy = KTD.betz_wind_normal_area(sysn, p_base)
        ds = span - EXPECTED_SPAN[n]
        da = azy - EXPECTED_AZY[n]
        good = abs(ds) < 5e-3 && abs(da) < 3e-2
        ok &= good
        @printf("n=%d  span=%.4f (exp %.4f, d=%+.4f)  A_ZY=%.3f (exp %.2f, d=%+.2f)  %s\n",
            n, span, EXPECTED_SPAN[n], ds, azy, EXPECTED_AZY[n], da, good ? "OK" : "MISMATCH")
    end
    return ok
end

ok_s2 = verify_s2(x, p_base, beam_profile, cfg)
println(ok_s2 ? "\nALL SECTION-2 ROWS MATCH THE RECORD" : "\nSECTION-2 MISMATCH — investigate")

# ── Section 3: the trpt realisability fixture re-derived (seventh re-baseline) ──

include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const SEED_LR20 = [2.4, 0.5751086854, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
const OMEGA_SEED = 12.983466

p_fixture = override_params(params_5kw_188(); back_anchor_fwd_x=6.901)
sys3, u03, pc3, lift3, wf3 = build_case(nothing, nothing; genome=SEED_LR20, p=p_fixture)
F_ax3 = KTD.design_axial_preload(
    sys3, pc3, lift3, u03; omega_eq=OMEGA_SEED, realisability_margin=1.0
)
τ3 = sys3.k_mppt_ref[] * OMEGA_SEED^2
r3 = KTD.trpt_matched_place(sys3, pc3, F_ax3, τ3, OMEGA_SEED, wf3; raise_on_unrealisable=false)
cross3 = KTD.max_segment_cross_ratio(r3, sys3)

@printf("\n[3] trpt realisability fixture (SEED_LR20, L/r 2.0, FIXTURE_FWD_X=6.901):\n")
@printf("demand[1]=%.10f  demand[4]=%.10f\n", r3.demand[1], r3.demand[4])
@printf("demand[7]=%.10f  demand[8]=%.10f\n", r3.demand[7], r3.demand[8])
@printf("tau_carry[7]=%.6f  tau_carry[8]=%.6f\n", r3.τ_carry[7], r3.τ_carry[8])
@printf("F_ax[end]=%.6f  cross_bare=%.10f\n", F_ax3[end], cross3)

ok3 = true
ok3 &= isapprox(r3.demand[1], 1.5462831958604204; atol = 1e-6)
ok3 &= isapprox(r3.demand[4], 1.5712494508286716; atol = 1e-6)
ok3 &= isapprox(r3.demand[7], 0.4041356455734239; atol = 1e-6)
ok3 &= isapprox(r3.demand[8], 0.4048006637680152; atol = 1e-6)
ok3 &= isapprox(r3.τ_carry[7], 352.40563995344206; atol = 1e-4)
ok3 &= isapprox(r3.τ_carry[8], 308.97242241697535; atol = 1e-4)
ok3 &= isapprox(F_ax3[end], 636.1231817421598; atol = 1e-4)
ok3 &= isapprox(cross3, 2.2397326085630174; atol = 1e-6)
println(ok3 ? "[3] trpt fixture re-derived — matches the re-baselined pins" :
              "[3] MISMATCH — investigate")

println("\ndone.")
