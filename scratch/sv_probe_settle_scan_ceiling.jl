# sv_probe_settle_scan_ceiling.jl — software-validator, 2026-10-02
#
# DECIDES: the settle's equilibrium omega came out IDENTICAL (10.862435 rad/s) for
# the pre-derate winner at bank = 19.9469 deg and at bank = 0 deg, even though
# `settle_aero_power` (initialization.jl:1019-1037) does carry
# `cosd(sys.rotor.bank_angle_deg)^2.65`.  Mechanism under test: the scan
# (initialization.jl:2249-2258) walks DOWN from
#     omega_scan_top = min(omega_rated_max, lambda_peak * v_mag / rotor.radius)
# and breaks on the FIRST w with P_aero - P_par > P_gen.  Neither term in the
# ceiling involves bank, so if the first test passes at the ceiling, omega_eq is
# bank-invariant by construction and the derate never participates.
#
# This probe recomputes the ceiling and the first-test surplus WITHOUT settling.
#
# USAGE: scripts/ktd-julia scratch/sv_probe_settle_scan_ceiling.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const WIND_MS = 11.0

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

p = params_at_length(18.8)
λ_peak = KTD.BEM_TSR[argmax(KTD.BEM_CP)]
@printf("lambda at cp peak = %.6f   (BEM_TSR/BEM_CP)\n", λ_peak)

function scan_probe(label, csv, bank_override=nothing)
    x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    xr = copy(x)
    if length(xr) >= 14
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
        bank_override === nothing || (xr[11] = Float64(bank_override))
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
        xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
        bank_override === nothing || (xr[7] = Float64(bank_override))
    end
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p)

    # Same wind function and same v_mag source as settle_to_operational_state
    # (initialization.jl:2233-2237): u0's hub position, NOT the settled hub.
    wf = let p_ = p
        (pos, t) -> begin
            z = max(pos[3], 1.0)
            [WIND_MS * (z / p_.h_ref)^(1.0 / 7.0), 0.0, 0.0]
        end
    end
    hubpos = u0[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)]
    v_mag = sqrt(sum(abs2, wf(hubpos, 0.0)))
    ω_rated_max = 60.0
    ω_top = min(ω_rated_max, λ_peak * v_mag / sys.rotor.radius)
    k = sys.k_mppt_ref[]

    # First test of the scan, at the ceiling (drag omitted — drag can only LOWER
    # the surplus, so a positive surplus here is not yet conclusive on its own;
    # both bank values are reported so the comparison is like-for-like).
    P_aero_top = KTD.settle_aero_power(sys, p, ω_top, v_mag)
    P_gen_top = k * ω_top^3
    @printf("\n--- %s ---\n", label)
    @printf("  bank=%.4f deg  derate=%.6f  sys.rotor.radius=%.4f m\n",
        sys.rotor.bank_angle_deg, cosd(sys.rotor.bank_angle_deg)^2.65, sys.rotor.radius)
    @printf("  v_mag=%.6f m/s   OMEGA_SCAN_TOP = %.6f rad/s\n", v_mag, ω_top)
    @printf("  at the ceiling: P_aero=%.4f kW  P_gen=k*w^3=%.4f kW  surplus=%+.4f kW\n",
        P_aero_top / 1000, P_gen_top / 1000, (P_aero_top - P_gen_top) / 1000)
    @printf("  -> first scan test %s\n",
        P_aero_top - P_gen_top > 0 ? "PASSES: omega_eq = ceiling (bank-invariant)" :
        "FAILS: scan walks down, ceiling is not the answer")
    return ω_top
end

OLD = joinpath(ROOT, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")
NEW = joinpath(ROOT, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv")

a = scan_probe("PRE-derate winner, bank 19.9469 (as recorded)", OLD)
b = scan_probe("PRE-derate winner, bank forced 0", OLD, 0.0)
c = scan_probe("bank-derate winner, bank 10.7399 (as recorded)", NEW)
d = scan_probe("bank-derate winner, bank forced 0", NEW, 0.0)

println("\n  ceilings identical within a genome: old ", a == b, "   new ", c == d)
@printf("  settle returned omega_eq = 10.862435 for the PRE-derate winner at every bank value.\n")
@printf("  ceiling for that genome computed here = %.6f\n", a)
