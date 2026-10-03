# sv_probe_bank_threading.jl — software-validator, 2026-10-02
#
# DECIDES: does the bank gene reach `sys.rotor.bank_angle_deg` (and therefore the
# ODE/settle derate) on the path the acceptance tests and the wobble-gate probes
# use — `design_from_vector_v10` -> `build_system_from_v10`?  A prior probe settled
# the pre-derate winner at four bank values and got an identical omega to six
# decimals, which should be impossible if the derate is live.
#
# USAGE: scripts/ktd-julia scratch/sv_probe_bank_threading.jl

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

p = params_at_length(18.8)

function report(label, csv, bank_override=nothing)
    x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    xr = copy(x)
    if length(xr) >= 14
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
        xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    end
    bank_override === nothing || (xr[11] = Float64(bank_override))
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p)
    println("\n--- ", label, " ---")
    @printf("  genome length %d   decoded n_rings %d  n_active %d\n", length(xr), dec.n_rings, dec.n_active)
    for (i, r) in enumerate(dec.rotors)
        @printf("  dec.rotors[%d]: ring_idx=%d  bank=%.4f deg  blade_scale=%.4f\n",
            i, r.ring_idx, r.bank_angle_deg, r.blade_scale)
    end
    @printf("  hub test (ring_idx == n_rings): %s\n",
        any(r -> r.ring_idx == dec.n_rings, dec.rotors) ? "FOUND" : "NOT FOUND")
    @printf("  sys.rotor.bank_angle_deg = %.4f  (derate would be %.6f)\n",
        sys.rotor.bank_angle_deg, cosd(sys.rotor.bank_angle_deg)^2.65)
    @printf("  sys.rotor.radius = %.4f m   sys.rotor.wind_factor = %.4f\n",
        sys.rotor.radius, sys.rotor.wind_factor)
    return sys.rotor.bank_angle_deg
end

report("PRE-derate winner (14-field, bank_top 19.9469)",
    joinpath(ROOT, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv"))
report("PRE-derate winner, bank forced to 0",
    joinpath(ROOT, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv"), 0.0)
report("bank-derate winner (10-field, bank_top 10.7399)",
    joinpath(ROOT, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv"))
