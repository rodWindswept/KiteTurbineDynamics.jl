#!/usr/bin/env julia
# scripts/calibrate_kmppt_v62.jl
# Headless: find k_mppt that gives P≈50kW for V6.2 design
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf

# Build SystemParams with overridden k_mppt
function with_kmppt(p::SystemParams, k::Float64)
    ctrl = ControlSpec(p.i_pto, k, p.p_rated_w, p.β_min, p.β_max, p.β_rate_max, p.kp_elev)
    return SystemParams(p.rho, p.v_wind_ref, p.h_ref, p.e_modulus,
                        p.tether_diameter, p.lifter_elevation,
                        p.rotor_radius, p.tether_length,
                        p.trpt_hub_radius, p.trpt_rL_ratio,
                        p.n_lines, p.n_rings, p.n_blades,
                        p.m_ring, p.m_blade, p.cp,
                        ctrl, p.back)
end

function main()
    println("═══════════════════════════════════════════")
    println("  V6.2 k_mppt Calibration")
    println("═══════════════════════════════════════════")

    # Build V6.2 system
    p = params_v5_50kw()  # n_lines=8, not 12! This is the mass-scaled V5
    # Actually params_v5_50kw() uses n=8. V6.2 is n=12.
    # The dashboard --v6 builds the system from params_v5_50kw() and then
    # adds expansion rotors. The n_lines in the system is 8, not 12.
    println("V5-50kW base: n_lines=$(p.n_lines)  rotor_radius=$(p.rotor_radius)")

    sys, u0 = build_kite_turbine_system(p)

    r_rotor = 10.591991451982997
    cfg = ExpansionStackConfig(;
        placement=:clustered, n_rings=sys.n_ring, n_expansion=1,
        n_blades=p.n_blades,
        blade_tip_radius=0.7 * r_rotor,
        blade_hub_radius=-0.3 * r_rotor,
        blade_chord=0.113 * r_rotor,
        CL_blade=1.0, CD0_blade=0.02, k_induced=0.05,
        bank_angle_deg=45.0, mass_per_rotor=0.5, shaft_coupling=1.0,
    )
    stack = build_expansion_stack(cfg)
    sys, u0 = build_kite_turbine_system(p; expansion_rotors=stack)
    println("V6.2: n_lines=$(sys.n_ring) rings  n_total=$(sys.n_total)")

    v_wind = p.v_wind_ref
    elev_rad = p.elevation_angle
    rotor_R = sys.rotor.radius

    # Sweep k_mppt
    ks = exp10.(range(log10(50), log10(5000); length=40))

    println("\n  k_mppt sweep (hub rotor only, static equilibrium):")
    @printf("  %10s  %8s  %6s  %10s  %10s  %8s\n",
            "k_mppt", "ω_eq", "rpm", "P_aero(kW)", "P_gen(kW)", "Δ%rated")
    println("  " * "-"^60)

    best_k = 0.0
    best_error = Inf

    for k in ks
        # Find equilibrium: scan ω from high down, find first ω where P_aero >= P_gen
        ω_eq = 0.0
        found = false
        for w in range(15.0, 0.1; length=500)
            λ = clamp(w * rotor_R / v_wind, 0.0, 8.0)
            P_aero = 0.5 * p.rho * v_wind^3 * π * rotor_R^2 *
                     cp_at_tsr(λ) * cos(elev_rad)^2.65
            P_gen = k * w^3
            if P_aero > P_gen
                ω_eq = w
                found = true
                break
            end
        end

        if found && ω_eq > 0.1
            λ_eq = clamp(ω_eq * rotor_R / v_wind, 0.0, 8.0)
            P_aero_eq = 0.5 * p.rho * v_wind^3 * π * rotor_R^2 *
                        cp_at_tsr(λ_eq) * cos(elev_rad)^2.65
            P_gen_eq = k * ω_eq^3
            error_pct = abs(P_aero_eq - p.p_rated_w) / p.p_rated_w * 100

            if error_pct < best_error
                best_error = error_pct
                best_k = k
            end

            marker = error_pct < 10.0 ? " ✓" : ""
            @printf("  %10.1f  %8.2f  %6.0f  %10.1f  %10.1f  %7.1f%%%s\n",
                    k, ω_eq, ω_eq*60/(2π), P_aero_eq/1000, P_gen_eq/1000, error_pct, marker)
        end
    end

    if best_k > 0
        @printf("\n  ── Hub rotor only ──\n")
        @printf("  Best k_mppt: %.1f  (%.1f%% P error)\n", best_k, best_error)
        @printf("  Dashboard value: 614.9\n")
        @printf("  Ratio: %.2f×\n", best_k / 614.9)

        # Now check: at best_k, what expansion rotor τ_net adds
        ω_use = 0.0
        for w in range(15.0, 0.1; length=500)
            λ = clamp(w * rotor_R / v_wind, 0.0, 8.0)
            P_aero = 0.5 * p.rho * v_wind^3 * π * rotor_R^2 *
                     cp_at_tsr(λ) * cos(elev_rad)^2.65
            P_gen = best_k * w^3
            if P_aero > P_gen
                ω_use = w
                break
            end
        end

        # Compute expansion τ_net at this ω
        r_nominal = p.trpt_hub_radius  # ~3.58m for V5-50kW
        bank_rad = deg2rad(45.0)
        r_mean_annulus = r_rotor
        r_mean = r_nominal + r_mean_annulus * cos(bank_rad)
        blade_span = r_rotor - 0.25*r_rotor
        v_axial = v_wind * cos(elev_rad)
        v_app = sqrt(v_axial^2 + (ω_use * r_mean)^2)
        q = 0.5 * p.rho * v_app^2
        chord = 0.113 * r_rotor
        L_blade = q * chord * blade_span * 1.0
        D_blade = q * chord * blade_span * (0.02 + 0.05 * 1.0^2)
        phi = atan(v_axial, ω_use * r_mean)
        tau_lift = p.n_blades * L_blade * sin(phi) * cos(bank_rad) * r_mean
        tau_drag = p.n_blades * D_blade * cos(phi) * r_mean
        tau_exp = tau_lift - tau_drag
        P_exp = tau_exp * ω_use / 1000

        @printf("\n  ── Expansion rotor at ω=%.2f rad/s ──\n", ω_use)
        @printf("  v_app: %.0f m/s  (v_wind=%.0f, ωr=%.0f)\n", v_app, v_wind, ω_use*r_mean)
        @printf("  τ_lift: %.0f N·m  τ_drag: %.0f N·m  τ_net: %.0f N·m\n", tau_lift, tau_drag, tau_exp)
        @printf("  P_exp: %.0f kW  (hub P: %.0f kW → total: %.0f kW)\n",
                P_exp, p.p_rated_w/1000, p.p_rated_w/1000 + P_exp)
        @printf("  Total power: %.0f%% rated\n", (p.p_rated_w/1000 + P_exp) / (p.p_rated_w/1000) * 100)
    end
end

main()
