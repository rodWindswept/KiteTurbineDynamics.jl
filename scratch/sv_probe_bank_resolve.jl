# sv_probe_bank_resolve.jl — software-validator, 2026-10-02
#
# DECIDES: the room's bank arithmetic treats the pre-derate winner's ~4.888 kW as
# 5.76 kW at 0 deg bank (4.888 / cos(19.95 deg)^2.65).  That is a SCALING estimate:
# it holds everything else fixed.  But the machine re-settles — omega is set by the
# balance P_aero(omega) = P_pto(omega) = k_mppt * omega^3 — so dropping the bank
# charge raises omega, and P_pto is NOT simply the old power over the derate.
#
# Method: one settle per bank value on the pre-derate winner's own 14-field genome
# (legacy x[11] = bank_top, the gene the single rotor actually uses), read omega_eq,
# and report P_pto = k_mppt * omega_eq^3.  Compare the measured ratio against
# 1/derate.  No window, no evaluator — this is the settle's own equilibrium, so it
# is a re-solve of the balance, not the campaign's 50 s window statistic.
#
# USAGE: scripts/ktd-julia scratch/sv_probe_bank_resolve.jl

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
const CSV = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")   # 14-FIELD legacy

x = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
@printf("=== bank re-solve — %d-field genome ===\n", length(x))
p = params_at_length(LENGTH)

const BANK_BASE = x[11]             # legacy x[11] = canonical x[7] = bank_top (deg)
const BANKS = [BANK_BASE, 18.5, 7.0, 0.0]

println("bank_deg   omega_eq      P_pto = k*omega^3    ratio vs bank=$(round(BANK_BASE,digits=2))")
res = Dict{Float64,Tuple{Float64,Float64}}()
for b in BANKS
    xr = copy(x)
    if length(xr) >= 14
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
        xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    end
    xr[11] = Float64(b)             # legacy bank_top — the gene the rotor uses
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p)
    lift_dev = lift_for(sys, pc)
    wf = let p_ = p
        (pos, t) -> begin
            z = max(pos[3], 1.0)
            [WIND_MS * (z / p_.h_ref)^(1.0 / 7.0), 0.0, 0.0]
        end
    end
    u = KTD.settle_to_operational_state(sys, copy(u0), pc, 60.0;
        wind_fn=wf, lift_device=lift_dev)
    if u === nothing
        @printf("%6.2f      settle FAILED (infeasible guard)\n", b)
        continue
    end
    ω = u[6 * sys.n_total + sys.n_ring + 1]
    k = sys.k_mppt_ref[]
    P = k * ω^3
    res[b] = (ω, P)
    @printf("%6.2f     %10.6f     %10.3f kW", b, ω, P / 1000)
    if haskey(res, BANK_BASE) && b != BANK_BASE
        rel = res[BANK_BASE][2]
        @printf("   x%.4f   (scaling estimate %.4f)", P / rel,
            1.0 / cosd(BANK_BASE)^2.65)
    end
    println()
end

if haskey(res, BANK_BASE) && haskey(res, 0.0)
    ω0, P0 = res[0.0]
    ωb, Pb = res[BANK_BASE]
    println("\n  bank $(round(BANK_BASE,digits=2)) -> 0 deg:  omega %.6f -> %.6f  (+$(round((ω0/ωb-1)*100,digits=2))%)",
        ωb, ω0)
    @printf("  measured power ratio P0/Pbank   = %.6f\n", P0 / Pb)
    @printf("  scaling estimate 1/cos(bank)^2.65 = %.6f\n", 1.0 / cosd(BANK_BASE)^2.65)
    @printf("  those differ by                = %.4f%%\n", 100 * (P0 / Pb / (1.0 / cosd(BANK_BASE)^2.65) - 1))
    # 2026-10-02: that -15.12% is NOT evidence the derate is missing.  It is the
    # settle being bank-invariant by construction: omega_eq is the scan CEILING
    # `lambda_peak * v_mag / radius` (no bank term, no k_mppt), because the scan's
    # first test passes and the downward walk never runs.  Measured in
    # scratch/sv_probe_settle_scan_ceiling.jl: ceiling 10.862435 rad/s = the
    # omega_eq the settle returns, at bank 19.9469 AND at bank 0.  P_pto = k*omega^3
    # is therefore identical by construction, and this probe CANNOT see a bank
    # effect.  The bank charge lives in the ODE window, not in the settle.
    println("\n  READ THIS AS: the settle is bank-invariant (omega_eq is the scan ceiling).")
    println("  P_pto identical across bank is expected, not a missing derate.")
    println("  At a FIXED omega the charge is exactly multiplicative — aero-power ratio")
    println("  6.6987/5.6858 = 1.1781 vs 1/0.848790 = 1.178148")
    println("  (scratch/sv_probe_settle_scan_ceiling.jl).  Any bank effect on the")
    println("  OPERATING power must be read from the ODE window, not from a settle.")
end
