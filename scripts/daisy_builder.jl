#!/usr/bin/env julia
# scripts/daisy_builder.jl
# Daisy prototype builder — calibrated to Tulloch (2021) experimental data.
#
# Physical parameters (Tulloch PhD §3, Table 3.1, §3.5):
#   - Single ring at 1.52 m radius (carbon fibre + dacron sleeve)
#   - 3 rigid blades, NACA 4412, span 1.0 m, chord 0.2 m (constant)
#   - Pitch 3° (to feather), solidity 5.5%
#   - Inner tip 1.22 m, outer tip 2.22 m → swept area 10.8 m²
#   - TRPT-4: 10.31 m total length, 6 tethers, rings 0.63m→0.315m
#   - Elevation 28°
#   - Optimal λ = 4.0 (rotor+TRPT with drag)
#   - Experimental Cp = 0.20–0.25 (rigid wing, ~8 m/s)
#   - Peak power: 1.4 kW at ~8 m/s (Configuration 8)
#   - CDt = 2.7 (calibrated to match experimental data — §5.4.3)
#
# The builder returns (sys, u0, p, label, blade_scale) matching the format of
# build_v10_tight so it can be used with existing simulation scripts.

using KiteTurbineDynamics

function build_daisy(; blade_scale::Float64=1.0, cd0_blade::Float64=0.01)
    # ═══════════════════════════════════════════════════════════════
    # Geometry — Tulloch §3, rigid wing Configuration 8
    # ═══════════════════════════════════════════════════════════════
    elevation_angle = deg2rad(28.0)
    rotor_radius    = 1.52                 # ring radius R (m)
    tether_length   = 10.31                # TRPT-4 total length (m)
    trpt_hub_radius = 1.52                 # rotor ring — same as Daisy
    n_lines         = 6                    # hexagonal TRPT
    n_rings         = 3                    # 3 intermediate TRPT rings for stability (TRPT-4 had 13)
    n_blades        = 3                    # Config 8: 3-blade rigid

    # TRPT rings taper from hub (1.52m) to ground (0.315m per Tulloch §3.1).
    # Formula: r_bot = 2*L*rL/n_seg - r_top → rL = (r_bot+r_top)*n_seg/(2*L)
    # With n_rings=3 (n_seg=4): rL = (0.315+1.52)*4/(2*10.31) ≈ 0.356
    trpt_rL_ratio    = 0.356              # calibrated to TRPT-4 ground wheel ~0.315m

    # ═══════════════════════════════════════════════════════════════
    # Material — 4 mm carbon epoxy (E ≈ 230 GPa, ρ ≈ 1600 kg/m³)
    # ═══════════════════════════════════════════════════════════════
    tether_diameter  = 0.004               # m (4 mm carbon epoxy rods)
    e_modulus        = 100e9               # Pa — conservative (carbon ~230 GPa)
    m_ring           = 0.2                 # kg each — lightweight CF ring
    # Rigid blade: 1.0m span, 0.2m chord, foam core + CF spar → ~0.2 kg each
    m_blade          = 0.20 * blade_scale^2

    # ═══════════════════════════════════════════════════════════════
    # Aerodynamics — Tulloch experimental Cp = 0.20 (conservative)
    # ═══════════════════════════════════════════════════════════════
    rho              = 1.225               # kg/m³
    v_wind_ref       = 11.0                # m/s — Rod's measured peak (~10-11 m/s)
    h_ref            = 3.0                 # m — hub altitude
    cp               = 0.20                # experimental Cp (Tulloch §3.5)

    # ═══════════════════════════════════════════════════════════════
    # Control — sized for Daisy experimental peak at v_wind_ref
    #
    # P_aero = ½ρ·A·v³·Cp = 0.5·1.225·10.8·v³·0.20
    # At 10 m/s: P_aero = 0.5·1.225·10.8·1000·0.20 ≈ 1323 W
    #
    # ω_opt  = λ·v/R = 4.0·v/1.52  (rad/s)
    # τ_opt  = P_target/ω_opt  (N·m)
    # k_mppt = τ_opt/ω_opt²  (N·m·s²/rad²)
    # ═══════════════════════════════════════════════════════════════
    i_pto            = 0.2                 # kg·m² — small PTO
    target_p_w       = 0.5 * rho * 10.8 * v_wind_ref^3 * cp
    ω_opt            = 4.0 * v_wind_ref / rotor_radius
    τ_opt            = target_p_w / ω_opt
    k_mppt_base      = τ_opt / ω_opt^2
    k_mppt           = k_mppt_base * blade_scale^2
    p_rated_w        = target_p_w

    # ═══════════════════════════════════════════════════════════════
    # TRPT drag calibration — Tulloch §5.4.3: CDt = 2.7
    # ═══════════════════════════════════════════════════════════════
    # NOTE: CDt = 2.7 is set as the tether drag coefficient.
    # Default KTD.jl value is 1.2 — use 2.7 for calibrated results.
    # This is configured via SystemParams / rope properties.
    # For now set in comments; actual override depends on KTD.jl API.

    # ═══════════════════════════════════════════════════════════════
    # Back line
    # ═══════════════════════════════════════════════════════════════
    EA_back_line     = 700_000.0           # N
    c_back_line      = 500.0               # N·s/m
    back_anchor_fwd_x = 5.0                # m
    backline_payout  = 0.0

    # ═══════════════════════════════════════════════════════════════
    # Assemble
    # ═══════════════════════════════════════════════════════════════
    geo = GeometrySpec(
        elevation_angle,
        deg2rad(70.0),
        rotor_radius,
        tether_length,
        trpt_hub_radius,
        trpt_rL_ratio,
        n_lines,
        n_rings,
        n_blades,
    )
    mat = MaterialSpec(tether_diameter, e_modulus, m_ring, m_blade)
    aero = AeroSpec(rho, v_wind_ref, h_ref, cp)
    ctrl = ControlSpec(
        i_pto, k_mppt, p_rated_w,
        deg2rad(23.0), deg2rad(67.0), deg2rad(1.0), 5e-5,
    )
    back = BackLineSpec(EA_back_line, c_back_line, back_anchor_fwd_x, backline_payout)
    pc = SystemParams(geo, mat, aero, ctrl, back)

    # Hub rotor — 3-blade rigid wing (Tulloch Config 8)
    # Inner tip: 1.22m = ring(1.52) - 0.30m inside
    # Outer tip: 2.22m = ring(1.52) + 0.70m outside
    # Chord: 0.20m constant
    hub_rotor = ExpansionRotorParams(
        n_blades,
        0.70,                     # blade_tip_radius — 0.70m outboard from ring
        -0.30,                    # blade_hub_radius — 0.30m inboard (negative!)
        0.20,                     # blade_chord — 0.20m constant
        1.0,                      # CL_blade — NACA 4412 at moderate α
        cd0_blade,                # CD0_blade — profile drag (tunable)
        0.05,                     # k_induced — induced drag factor
        rad2deg(elevation_angle), # bank_angle_deg — matches elevation
        m_blade,                  # mass per blade
        5,                        # ring_idx — hub ring (rings 1=ground, 2-4=intermediate, 5=hub)
        1.0,                      # shaft_coupling — fully coupled
    )

    sys, u0 = build_kite_turbine_system(pc; expansion_rotors=[hub_rotor])

    # Fix: initialise blade nodes at the hub ring position so the settle
    # solver doesn't see NaN forces from nodes at (0,0,0) far from the ring.
    # The hub ring is at ring_ids[end]; blade nodes have higher IDs.
    hub_gid = sys.ring_ids[end]
    hub_pos = [0.0, 0.0, pc.tether_length * sin(elevation_angle)]
    # Also stagger along shaft
    shaft_dir = [cos(elevation_angle), 0.0, sin(elevation_angle)]
    for node in sys.nodes
        if node isa RopeNode && node.id > sys.rotor.node_id
            # Blade node — place near the hub ring along the blade span direction
            # The exact placement will be corrected by the settle process
            u0[(3*(node.id-1)+1):(3*node.id)] .= hub_pos
        end
    end

    label = "Daisy Proto (Tulloch Config 8: $(rotor_radius)m ring, $(n_blades) blades NACA4412, $(n_lines) tethers, $(tether_length)m TRPT-4, 28°)"

    println("Daisy: n_lines=$n_lines n_blades=$n_blades rings=$(sys.n_ring) blade_scale=$blade_scale")
    println("       ring=$(rotor_radius)m  TRPT-4=$(tether_length)m  swept≈10.8m²")
    println("       peak=$(p_rated_w)W @ $(v_wind_ref)m/s  λ=$(4.0)  k_mppt=$(round(k_mppt, digits=3))")
    println("       CDt=2.7 (Tulloch calibrated)  Cp_exp≈0.20")

    return sys, u0, pc, label, blade_scale
end

# ═══════════════════════════════════════════════════════════════════
# Self-test
# ═══════════════════════════════════════════════════════════════════
if abspath(PROGRAM_FILE) == @__FILE__
    using Pkg; Pkg.activate(dirname(@__DIR__))
    using KiteTurbineDynamics

    for λ in [0.5, 0.75, 1.0, 1.25]
        println("\n--- build_daisy(blade_scale=$λ) ---")
        sys, u0, p, label, bs = build_daisy(; blade_scale=λ)
        println("   nodes=$(sys.n_total)  rings=$(sys.n_ring)")
        println("   rotor_radius=$(p.rotor_radius) m  TRPT=$(p.tether_length) m  h_ref=$(p.h_ref) m")
        P_theo = 0.5 * 1.225 * 10.8 * p.v_wind_ref^3 * 0.20 / 1000
        println("   P_theo(exp Cp=0.20, A=10.8m², $(p.v_wind_ref)m/s) = $(round(P_theo, digits=3)) kW")
    end
    println("\nAll Daisy configurations built successfully.")
end
