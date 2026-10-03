# sv_probe_decode_guard.jl — software-validator, 2026-10-02
#
# DECIDES: is the genome-index clamp in the wobble/escalation probes safe as
# written?  `canonical_v10` (src/objective_v10.jl:142) branches on genome LENGTH:
#   length(x) >= 14  -> canonical = x[5:14]   (LEGACY 14-D: n_lines at 8, rotor at 10)
#   length(x) == 10  -> canonical = x[1:10]   (CANONICAL 10-D: n_lines at 4, rotor at 6)
# The applied fix round-clamps CANONICAL indices unconditionally.  This probe
# decodes the SAME two winner CSVs under each clamp style and prints what came out,
# so the blast radius is visible rather than argued.
#
# USAGE: scripts/ktd-julia scratch/sv_probe_decode_guard.jl

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

const LENGTH = 18.8
p = params_at_length(LENGTH)

const CSVS = [
    "v13_5kw_masslift_len18.8_rotorcount" => "PRE-derate winner (14-field CSV)",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate" => "bank-derate winner (10-field CSV)",
]

function decode(xr)
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    return dec
end

for (dir, label) in CSVS
    csv = joinpath(ROOT, "scripts", "results", dir, "best_vector.csv")
    x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    println("\n", "="^78)
    @printf("%s  —  %d fields\n", label, length(x))
    println("  raw: ", string(round.(x, digits=4)))

    # Style A: the applied fix — canonical indices 4 / 6, unconditional.
    xa = copy(x)
    xa[4] = Float64(round(Int, clamp(xa[4], 3, 16)))
    xa[6] = Float64(round(Int, clamp(xa[6], 1, 3)))
    # Style B: the pre-fix pair — legacy indices 8 / 10, unconditional.
    xb = copy(x)
    xb[8] = Float64(round(Int, clamp(xb[8], 3, 16)))
    xb[10] = Float64(round(Int, clamp(xb[10], 1, 3)))
    # Style C: length-aware (canonical for 10-D, legacy for >=14-D).
    xc = copy(x)
    if length(x) >= 14
        xc[8] = Float64(round(Int, clamp(xc[8], 3, 16)))
        xc[10] = Float64(round(Int, clamp(xc[10], 1, 3)))
    else
        xc[4] = Float64(round(Int, clamp(xc[4], 3, 16)))
        xc[6] = Float64(round(Int, clamp(xc[6], 1, 3)))
    end

    for (style, xr) in (("A fixed (canonical 4/6)", xa),
        ("B pre-fix (legacy 8/10)", xb),
        ("C length-aware", xc))
        d = decode(xr)
        @printf("  %-26s -> n_lines=%2d  r_hub=%.4f  r_bottom=%.4f  n_rings=%d  n_active=%d  bank_top=%.3f  bank_bot=%.3f  blade_top=%.4f  blade_bot=%.4f\n",
            style, d.design.n_lines, d.design.r_hub, d.design.r_bottom,
            d.n_rings, d.n_active,
            d.rotors[1].bank_angle_deg, d.rotors[end].bank_angle_deg,
            d.rotors[1].blade_scale, d.rotors[end].blade_scale)
    end

    # What each style actually wrote into the vector, to name the gene it touched.
    @printf("  style A wrote: x[4]=%.4f x[6]=%.4f  (canonical: n_lines / rotor_count)\n", xa[4], xa[6])
    @printf("  style B wrote: x[8]=%.4f x[10]=%.4f  (canonical: bank_bottom / blade_scale_bottom)\n", xb[8], xb[10])
end
