#!/usr/bin/env julia --project=.
#= build_april29_rig.jl — TRPT-5 mast-mount rig (2020-04-29) builder.
Provenance: docs/validation/daisy-anchor-provenance.md (thesis + Rod + logs).
Geometry per Tulloch PhD (config 9 = TRPT-5, 6 foam blades):
  - TRPT-5 total length 9.5 m (Table 3.1; TRPT-4 10.3 m, "0.8 m longer than TRPT-5")
  - lower sections ring radius 0.35 m (70 cm hex rings); rotor ring 1.52 m
  - rigid wings: span 1.0 m, chord 0.2 m, NACA 4412, no twist; outer tip
    radius 2.22 m (0.3 m of span inboard of the 1.52 m rotor ring); 4° pitch
  - mast rig: chain at ~10° elevation (Rod, video), bank 0° (video),
    mast 4.3 m with pulley; 12 kg bucket = 118 N constant tension, lift line
    from bearing to pulley is the 10° axis extension (lifter_elevation = 10°)
  - 6 lines × 2 mm UHMWPE (Rod, builder; thesis never says 4 mm)
  - P ≈ 220 W regulated plateau at 5-8 m/s (measured)
  - ground wheel 0.63 m dia, chain drive 1:2.14 to 500 W gen (thesis 3.1.4)
=#

using KiteTurbineDynamics

function build_april29_rig()
    elevation_angle = deg2rad(10.0)     # chain ~10° above horizontal (Rod: rotor low, square-on)
    rotor_radius    = 2.22              # R_rotor outer tip (thesis Rigid Wings §3.1.1)
    tether_length   = 9.5               # TRPT-5 total length (thesis Table 3.1, config 9)
    trpt_hub_radius = 1.52              # rotor ring radius (thesis §3.1.1)
    # Canonical taper law: r_bot = 2·L·rL/n_seg − r_top.  For L=9.5, n_seg=11,
    # r_top=1.52, r_bot=0.35 (70 cm hex rings at the PTO end):
    trpt_rL_ratio   = (0.35 + 1.52) * 11 / (2 * 9.5)   # ≈ 1.083
    n_lines         = 6
    n_rings         = 10                # intermediate → 12 rings total
    n_blades        = 6

    tether_diameter = 0.002             # 2 mm (Rod, builder)
    e_modulus       = 100e9             # UHMWPE
    m_ring          = 0.1               # light carbon hex ring
    m_blade         = 0.2               # foam wing + film + spars (estimate)

    rho              = 1.225
    v_wind_ref       = 6.5              # mid-band of the measured 4.5-7.7 m/s
    h_ref            = 1.65             # hub altitude ≈ 9.5·sin10° (rotor low)
    cp               = 0.20             # thesis experimental Cp ~0.20-0.25

    # Control — the compare script uses the MEASURED constant-power load
    # (set_generator_load!(GeneratorLoadMode(:const_power, 225.0, 45.0))),
    # so k_mppt is unused for this rig; kept for reference.
    i_pto      = 0.25                   # 0.63 m wheel + 1:2.14 chain drive + 500 W gen
    target_p_w = 250.0
    ω_opt      = 4.0 * v_wind_ref / rotor_radius
    k_mppt     = (target_p_w / ω_opt) / ω_opt^2
    p_rated_w  = 300.0

    geo = GeometrySpec(
        elevation_angle, deg2rad(10.0), rotor_radius, tether_length,
        trpt_hub_radius, trpt_rL_ratio, n_lines, n_rings, n_blades,
    )
    mat  = MaterialSpec(tether_diameter, e_modulus, m_ring, m_blade)
    aero = AeroSpec(rho, v_wind_ref, h_ref, cp)
    ctrl = ControlSpec(i_pto, k_mppt, p_rated_w,
        deg2rad(23.0), deg2rad(67.0), deg2rad(1.0), 5e-5)
    back = BackLineSpec(700_000.0, 500.0, 5.0, 0.0)
    pc   = SystemParams(geo, mat, aero, ctrl, back)

    # The rotor is represented by the MAIN rotor (cp_at_tsr BEM curve —
    # the thesis's own 6-blade approach: AeroDyn 3-blade + solidity).  NO
    # expansion rotor: its α-model + induction turns the same 10.8 m²
    # annulus into a brake at this rig's operating point (heavy disk
    # loading → induction a→0.5 → CL negative), conflicting with the main
    # rotor and bleeding the machine down (2026-08-16 diag).  The
    # expansion-rotor model stays for the DE stacked-rotor campaigns.
    sys, u0 = build_kite_turbine_system(pc)

    # Bucket lift: constant 118 N (12 kg), mast-top pulley; the bearing→pulley
    # line is the 10° axis extension (lifter_elevation = 10°, Rod 2026-08-16).
    lifter = StackedLifterParams(
        118.0, 6.5, 10.0, 1.0, 12.0, 0.0, 700_000.0, 0.3,
        true,  # const_tension — the 12 kg bucket is a weight, not a kite
    )
    println("April-29 rig: rings=", sys.n_ring, " (12)  blades=", n_blades,
            "  lines=", n_lines, "  R_rotor=", rotor_radius, " m  T_bucket=118 N")
    return sys, u0, pc, lifter
end
