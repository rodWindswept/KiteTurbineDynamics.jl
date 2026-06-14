#!/usr/bin/env julia
# scripts/verify_expansion_forces.jl
#
# Standalone expansion rotor force verification.
# Builds a TRPT system with expansion rotors using the SAME blade
# geometry as the generating rotor — identical span and chord, banked
# downward toward the next ring.
#
# Run:  julia --project=. scripts/verify_expansion_forces.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra

function main()
    p = params_10kw()

    # Derive blade geometry from generating rotor
    # blade_span = rotor radius (same blade mould)
    # blade_chord = 0.113 × rotor_radius (solidity-calibrated, ring_forces.jl:157)
    r_rotor_ref = 5.0   # default 10 kW rotor radius
    blade_span  = r_rotor_ref
    blade_chord = 0.113 * r_rotor_ref  # ≈ 0.565 m — real blade

    println("Generating rotor: R=$(r_rotor_ref) m, chord=$(round(blade_chord;digits=3)) m")
    println("Expansion blade: SAME span=$(blade_span) m, SAME chord=$(round(blade_chord;digits=3)) m")
    println()

    # 3 rotors clustered near hub, banked 20° toward next ring
    cfg = ExpansionStackConfig(;
        placement=:clustered,
        n_rings=16,
        n_expansion=3,
        n_blades=p.n_blades,
        blade_span=blade_span,
        blade_chord=blade_chord,
        CL_blade=1.0,
        CD0_blade=0.02,
        k_induced=0.05,
        bank_angle_deg=20.0,
        mass_per_rotor=0.5,
        shaft_coupling=1.0,
    )
    stack = build_expansion_stack(cfg)
    sys, u0 = build_kite_turbine_system(p; expansion_rotors=stack)

    println("System: $(p.n_lines) lines, $(sys.n_ring) rings")
    println("Expansion rotors: $(length(sys.expansion_rotors))")
    for er in sys.expansion_rotors
        println("  Ring $(er.ring_idx): bank=$(er.bank_angle_deg)°, span=$(er.blade_span) m, chord=$(round(er.blade_chord;digits=3)) m")
    end

    # Settle
    wind_fn = (pos, t) -> begin
        z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1/7); [11.0*sh, 0.0, 0.0]
    end
    println("\nSettling...")
    u = settle_to_operational_state(sys, u0, p, 9.5; lift_device=rotary_lifter_default(), wind_fn=wind_fn)

    N = sys.n_total; Nr = sys.n_ring
    hub_gid = sys.ring_ids[Nr]
    rp_hub = u[(3*(hub_gid-1)+1):(3*hub_gid)]
    omega_hub = u[6N + Nr + Nr]

    println("\n═══════════════════════════════════════════════════════")
    println("  SETTLED STATE: ω=$(round(omega_hub;digits=1)) rad/s, wind=$(round(norm(wind_fn(rp_hub,0.0));digits=1)) m/s")
    println("═══════════════════════════════════════════════════════")

    # Per-ring force breakdown
    ring_nodes = [node for node in sys.nodes if node isa RingNode]
    for er in sys.expansion_rotors
        ri = er.ring_idx
        rn = ring_nodes[ri]
        r_nom = rn.radius
        ring_pos = u[(3*(rn.id-1)+1):(3*rn.id)]
        v_wind = norm(wind_fn(ring_pos, 0.0))

        # Effective mean radius: ring + half projected span
        bank_rad = deg2rad(er.bank_angle_deg)
        proj_span = er.blade_span * cos(bank_rad)
        r_mean = r_nom + proj_span / 2.0
        v_rot = omega_hub * r_mean
        v_app = sqrt(v_wind^2 + v_rot^2)
        r_tip = r_nom + proj_span  # projected tip radius

        q = 0.5 * p.rho * v_app^2
        L_blade = q * er.blade_chord * er.blade_span * er.CL_blade
        F_radial = er.n_blades * L_blade * sin(bank_rad)
        F_axial  = er.n_blades * L_blade * cos(bank_rad)

        println("\n  ── Ring $(ri) (r_nom=$(round(r_nom;digits=2)) m) ──")
        println("    Blade span:         $(er.blade_span) m  (same as generating rotor)")
        println("    Blade chord:        $(round(er.blade_chord;digits=3)) m")
        println("    Bank angle:         $(er.bank_angle_deg)°  (tip down toward ring $(ri-1))")
        println("    Proj. span:         $(round(proj_span;digits=2)) m  (span × cos(bank))")
        println("    r_tip (projected):  $(round(r_tip;digits=2)) m")
        println("    r_mean (aero):      $(round(r_mean;digits=2)) m")
        println("    Wind-only:           $(round(v_wind;digits=1)) m/s")
        println("    Rotational (ω·r):    $(round(v_rot;digits=1)) m/s")
        println("    APPARENT WIND:       $(round(v_app;digits=1)) m/s")
        println("    Dynamic pressure:    $(round(q;digits=1)) Pa")
        println("    Blade lift (each):   $(round(L_blade;digits=1)) N")
        println("    × $(er.n_blades) blades:            $(round(er.n_blades*L_blade;digits=1)) N total")
        println("    ─────────────────────────────────────")
        println("    F_radial (OUTWARD):  $(round(F_radial;digits=1)) N  → $(round(F_radial/p.n_lines;digits=1)) N/vertex")
        println("    F_axial  (THRUST):   $(round(F_axial;digits=1)) N")
    end

    # Comparison: generating rotor vs expansion
    println("\n═══════════════════════════════════════════════════════")
    println("  COMPARISON: Generating vs Expansion (per blade)")
    r_mean_gen = 5.0  # generating rotor mean radius
    v_app_gen = sqrt(11.0^2 + (9.5 * r_mean_gen)^2)
    q_gen = 0.5 * p.rho * v_app_gen^2
    L_gen = q_gen * blade_chord * blade_span * 1.0
    println("  Generating rotor: v_app=$(round(v_app_gen;digits=0)) m/s, lift=$(round(L_gen;digits=0)) N/blade")
    println("  Expansion (banked 20°): $(round(L_blade;digits=0)) N/blade → $(round(F_radial;digits=0)) N radial")
    println("  Same blade mould — banking redirects lift outward")
    println("═══════════════════════════════════════════════════════")
end

main()
