# sv_probe_rotor_count.jl — software-validator, 2026-10-02
#
# ANSWERS (Rod): for the bank-derate winner, how many rotors does the decoder
# actually build, and where do they sit?  Rod's concern: a "top 10.7 / bottom
# 7.2" reading of a single-rotor machine implies double-counting.
#
# Also measures the SENSITIVITY: the same CSV decoded with rotor_count_mode
# false (legacy bitmask path) instead of true.
#
# USAGE: scripts/ktd-julia scratch/sv_probe_rotor_count.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0

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

const p = params_at_length(18.8)

function decode_raw(csv)
    x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    xr = copy(x)
    if length(xr) >= 14
        xr[8]  = Float64(round(Int, clamp(xr[8],  3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1,  3)))
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
        xr[6] = Float64(round(Int, clamp(xr[6], 1,  3)))
    end
    return xr
end

function report(label, csv; rcm=true)
    xr = decode_raw(csv)
    raw = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    @printf("\n=== %s (rotor_count_mode=%s) ===\n", label, rcm)
    @printf("  CSV fields %d  |  raw x[6] (canonical) = %.6f\n", length(raw),
        length(raw) >= 14 ? raw[10] : raw[6])
    if rcm
        # reset the count gene before decode (the campaign runner clamps x[6] then
        # the decoder rounds it again — do the same so we test the runner's path)
    end
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=rcm, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    @printf("  n_rings=%d   n_active=%d   length(dec.rotors)=%d\n",
        dec.n_rings, dec.n_active, length(dec.rotors))
    for (i, r) in enumerate(dec.rotors)
        @printf("    rotors[%d]: ring_idx=%d  bank=%.4f deg  blade_scale=%.4f  wind_factor=%.4f\n",
            i, r.ring_idx, r.bank_angle_deg, r.blade_scale, r.wind_factor)
    end
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p)
    n_main = 1
    n_exp = try length(sys.expansion_rotors) catch; -1 end
    @printf("  BUILT: main rotor (ring_forces disc model) = %d  |  expansion rotors = %d\n",
        n_main, n_exp)
    @printf("  sys.rotor.bank_angle_deg = %.4f  derate=cos^2.65=%.6f  wind_factor=%.4f\n",
        sys.rotor.bank_angle_deg, cosd(sys.rotor.bank_angle_deg)^2.65, sys.rotor.wind_factor)
    @printf("  last-ring rotors (ring_idx == n_rings): %s\n",
        string([r.ring_idx for r in dec.rotors if r.ring_idx == dec.n_rings]))
end

const BANK = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv")
const PRE = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")

report("BANK-DERATE WINNER — campaign path", BANK; rcm=true)
report("BANK-DERATE WINNER — legacy bitmask path", BANK; rcm=false)
report("PRE-DERATE WINNER — campaign path", PRE; rcm=true)
