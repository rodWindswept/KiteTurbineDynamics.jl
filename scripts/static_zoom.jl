#!/usr/bin/env julia
# static_zoom.jl — static aero at the ODE operating region (150-300 rpm)
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function static_at_omega(sys, p, omega, V_wind)
    N = sys.n_total; Nr = sys.n_ring; elev_deg = rad2deg(p.elevation_angle)
    
    lambda = clamp(omega * sys.rotor.radius / V_wind, 0.0, 12.0)
    cp = cp_at_tsr(lambda)
    P_hub = 0.5 * p.rho * V_wind^3 * π * sys.rotor.radius^2 * cp * cos(p.elevation_angle)^2.65 / 1000
    tau_hub = P_hub * 1000 / max(omega, 0.01)
    
    P_exp = 0.0; tau_exp = 0.0
    for er in sys.expansion_rotors
        ri = er.ring_idx
        ri < 1 || ri > Nr && continue
        rnom = (sys.nodes[sys.ring_ids[ri]]::RingNode).radius
        _, _, tn, _, _ = expansion_rotor_forces(er, p.rho, V_wind, omega, elev_deg, rnom, 1500.0, p.n_lines)
        P_exp += tn * omega / 1000; tau_exp += tn
    end
    return (P_hub, P_exp, P_hub+P_exp, tau_hub+tau_exp)
end

for (label, bs) in [("λ=1.0", 1.0), ("λ=0.54", 0.54)]
    sys, _, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=bs)
    println("\n══════════ $label (rotor_radius=$(round(sys.rotor.radius, digits=1))m) ══════════")
    println("  rpm    rad/s   λ_hub  hub_cp  P_hub  P_exp   P_total  P_gen(k)")
    # Mark ODE operating point
    ode_ω = bs == 1.0 ? 221.7 : 207.0
    for rpm in 100:20:400
        ω = rpm * 2π / 60
        h, e, t, _ = static_at_omega(sys, p, ω, 11.0)
        lambda = ω * sys.rotor.radius / 11.0
        cp = cp_at_tsr(clamp(lambda, 0.0, 12.0))
        kg = bs == 1.0 ? 15.6 : 2.3
        P_gen_kw = kg * ω^3 / 1000
        marker = abs(rpm - ode_ω) < 11 ? " ← ODE" : ""
        @printf("  %4d   %5.2f   %5.2f  %6.3f  %5.1f  %6.1f  %7.1f  %7.1f%s\n", rpm, ω, lambda, cp, h, e, t, P_gen_kw, marker)
    end
    # Efficiency at ODE point
    ω_ode = ode_ω * 2π / 60
    h, e, t, _ = static_at_omega(sys, p, ω_ode, 11.0)
    kg = bs == 1.0 ? 15.6 : 2.3
    Pg = kg * ω_ode^3 / 1000
    eta = t > 0 ? Pg / t * 100 : 0.0
    println("  → Static aero at ODE ω: $(round(t, digits=1)) kW, P_gen=$(round(Pg, digits=1)) kW, shaft η=$(round(eta, digits=0))%")
end
