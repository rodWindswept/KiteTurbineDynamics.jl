# scratch/aw_k_static_2026-11-01.jl — aero-worker, 2026-11-01
#
# The static half of the two-point k re-eval. The measured n=3 fine-lambda
# curve gives lambda at each k (probe aw_k_bracket_2026-11-01.py). The archive
# point anchors the scale: P = P_arc * Cp/Cp_arc, omega = omega_arc * lam/lam_arc.
# structural_pass_v10 takes each measured speed and returns the ungated
# torsional FoS plus the per-ring Do. Per-ring blade chord c and rho print too.
#
# USAGE: DISPLAY=:1 scripts/ktd-julia scratch/aw_k_static_2026-11-01.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const MIN_WALL_M = 2.0e-3
const VEC = joinpath(
    @__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2", "best_vector.csv")

# anchor: the recorded campaign point and the measured curve at it
const OMEGA_ARC = 13.3852      # hub speed, av_bow_probe extension series
const P_ARC = 5.310           # kW, NR-016 recorded P_end
const LAM_ARC = 6.8415         # RF-14 flown tip-speed ratio
# the measured n=3 points (probe aw_k_bracket_2026-11-01.py)
const POINTS = [
    (k=8.4, lam=4.8319, cp=0.31292),
    (k=8.9, lam=4.7379, cp=0.31256),
]
const CP_ARC = 0.23686

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades,
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

function cfg_for(k::Float64, p)
    return KTD.ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED,
        p_floor_kw=5.0, p_ceiling_kw=5.0,
        relax_s=10.0, window_s=40.0,
        fos_target=2.5, fos_hard=2.5,
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0, k_mppt=k,
        tether_diameter=p.tether_diameter,
        rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
        rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        min_wall_m=MIN_WALL_M,
    )
end

function main()
    git = strip(read(`git rev-parse --short HEAD`, String))
    println("=== aw_k_static_2026-11-01.jl   git=", git, " ===")
    p = params_at_length(LENGTH)
    x = [parse(Float64, s) for s in split(strip(read(VEC, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))

    dec0 = KTD.design_from_vector_v10(
        KTD.canonical_v10(xr), PROFILE_ELLIPTICAL, p;
        power_W=PW, v_rated=V_RATED, cylinder_cone=true,
        rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
        rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    radii = KTD.ring_radii(dec0.design)
    Lseg = KTD.segment_axial_lengths(dec0.design)
    println("  n_lines ", dec0.design.n_lines, "  rings ", dec0.n_rings,
        "  r_hub ", dec0.design.r_hub, "  Do_top ", dec0.design.Do_top,
        "  t/D ", dec0.design.t_over_D, "  rho ", p.rho)
    println("  radii = ", [round(r, digits=4) for r in radii])
    println("  L_seg = ", [round(l, digits=4) for l in Lseg])
    println("  rotor chord c = ", dec0.rotors[1].blade_chord,
        "  blade_tip offset = ", dec0.rotors[1].blade_tip_radius,
        "  r_outer = ", dec0.design.r_hub + dec0.rotors[1].blade_tip_radius)

    # per-ring bending-rotation coupling c = 6 E I / L^2 (the ring element term)
    for (i, r) in enumerate(radii)
        spec = KTD.beam_spec_at_ring(dec0.design, r)
        A, Imin, J = KTD.beam_section_properties(spec)
        Lb = i <= length(Lseg) ? Lseg[i] : Lseg[end]
        cb = 6 * KTD.OPT_E_CFRP * Imin / Lb^2
        @printf("  ring %d r %.4f Do %.5f  c_bend %.4e N m  (I %.4e m4, A %.4e m2)\n",
            i, r, spec.Do, cb, Imin, A)
    end

    println("\n  k     lam      Cp       P_kW     omega    tau_Nm    min_tors_FoS  Do_per_ring")
    for pt in POINTS
        P = P_ARC * pt.cp / CP_ARC
        w = OMEGA_ARC * pt.lam / LAM_ARC
        tau = P * 1000.0 / w
        cfg = cfg_for(pt.k, p)
        sp = KTD.structural_pass_v10(xr, PROFILE_ELLIPTICAL, p, cfg;
            omega_rotor=w, P_rated=P * 1000.0)
        @printf("  %4.1f  %7.4f  %7.5f  %8.4f  %8.4f  %8.2f  %12.6f  %s\n",
            pt.k, pt.lam, pt.cp, P, w, tau, sp.min_torsional_fos,
            join([@sprintf("%.5f", d) for d in sp.Do_per_ring], ","))
        @printf("        fos_per_ring = %s\n",
            join([@sprintf("%.4f", f) for f in sp.fos_per_ring], ","))
        @printf("        valid=%s reason=%s ungated=%s\n",
            sp.valid, sp.reason, sp.torsion_ungated)
    end

    # the archive-point static read, for the ratio
    cfg0 = cfg_for(K_MPPT_5KW_HONEST, p)
    sp0 = KTD.structural_pass_v10(xr, PROFILE_ELLIPTICAL, p, cfg0;
        omega_rotor=OMEGA_ARC, P_rated=P_ARC * 1000.0)
    @printf("\n  archive point k %.2f: omega %.4f  P %.3f kW  tau %.2f  min_tors_FoS %.6f\n",
        K_MPPT_5KW_HONEST, OMEGA_ARC, P_ARC, P_ARC * 1000.0 / OMEGA_ARC, sp0.min_torsional_fos)
end

main()
