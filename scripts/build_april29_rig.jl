#!/usr/bin/env julia --project=.
#= build_april29_rig.jl — TRPT-5 mast-mount rig (2020-04-29) builder.
Provenance: docs/validation/daisy-anchor-provenance.md (thesis + Rod + logs).
  - 12 rings: PTO (ground) + 10 TRPT + rotor ring; hex 70 cm dia (r=0.35 m)
  - mast 4.3 m, bearing 15 cm → chain near-vertical (85°)
  - 6 lines × 2 mm UHMWPE (E=100 GPa)
  - 6-blade rotor, R_rotor=1.95 m (derived: tip 9.43 m/s at 47 rpm)
  - lift: 12 kg bucket = 118 N constant (StackedLifter T_ref)
  - P ≈ 220 W regulated at 5-8 m/s (measured plateau) =#

using KiteTurbineDynamics

function build_april29_rig()
    elevation_angle = deg2rad(85.0)     # near-vertical mast-mounted chain
    rotor_radius    = 1.95              # R_rotor (derived from tip/rpm logs)
    tether_length   = 4.3               # mast height (m)
    trpt_hub_radius = 0.35              # 70 cm dia hex rings
    trpt_rL_ratio   = 0.895             # near-uniform rings: (0.35+0.35)*11/(2*4.3)
    n_lines         = 6
    n_rings         = 10                # intermediate → 12 rings total
    n_blades        = 6

    tether_diameter = 0.002             # 2 mm (Rod, builder)
    e_modulus       = 100e9             # UHMWPE
    m_ring          = 0.1               # light carbon hex ring
    m_blade         = 0.2

    rho              = 1.225
    v_wind_ref       = 6.5              # mid-band of the measured 4.5-7.7 m/s
    h_ref            = 4.3
    cp               = 0.20             # thesis experimental Cp ~0.20-0.25

    # Control — sized for the measured plateau (~220 W, λ≈4)
    i_pto      = 0.05
    target_p_w = 250.0
    ω_opt      = 4.0 * v_wind_ref / rotor_radius
    k_mppt     = (target_p_w / ω_opt) / ω_opt^2
    p_rated_w  = 300.0

    geo = GeometrySpec(
        elevation_angle, deg2rad(85.0), rotor_radius, tether_length,
        trpt_hub_radius, trpt_rL_ratio, n_lines, n_rings, n_blades,
    )
    mat  = MaterialSpec(tether_diameter, e_modulus, m_ring, m_blade)
    aero = AeroSpec(rho, v_wind_ref, h_ref, cp)
    ctrl = ControlSpec(i_pto, k_mppt, p_rated_w,
        deg2rad(23.0), deg2rad(67.0), deg2rad(1.0), 5e-5)
    back = BackLineSpec(700_000.0, 500.0, 5.0, 0.0)
    pc   = SystemParams(geo, mat, aero, ctrl, back)

    hub_rotor = ExpansionRotorParams(
        n_blades,
        1.60,                     # blade_tip_radius — 1.95-0.35 outboard
        -0.10,                    # blade_hub_radius — 0.10 inboard
        0.20,                     # blade_chord (thesis Config 8 blade)
        1.0,                      # CL_blade
        0.01,                     # CD0_blade
        0.05,                     # k_induced
        0.0,                      # bank_angle_deg — rotor faces the wind at the mast top
        m_blade,
        n_rings + 2,              # ring_idx — hub = last ring
        1.0,                      # shaft_coupling
    )
    sys, u0 = build_kite_turbine_system(pc; expansion_rotors=[hub_rotor])

    # Bucket lift: constant 118 N (12 kg), mast-top pulley (short line)
    lifter = StackedLifterParams(
        118.0, 6.5, 85.0, 1.0, 12.0, 0.0, 700_000.0, 0.3,
    )
    println("April-29 rig: rings=", sys.n_ring, " (12)  blades=", n_blades,
            "  lines=", n_lines, "  R_rotor=", rotor_radius, " m  T_bucket=118 N")
    return sys, u0, pc, lifter
end
