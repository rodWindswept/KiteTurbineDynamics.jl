#!/usr/bin/env julia
# static_sweep.jl — Static aero P(ω) for λ=0.54 and λ=1.0, hub + expansion
# No ODE, seconds runtime. Reveals model's true P_max and ω_opt.
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function static_power(sys, p, omega_shaft, V_wind)
    N = sys.n_total; Nr = sys.n_ring
    elev_deg = rad2deg(p.elevation_angle)
    V_axial = V_wind * cos(p.elevation_angle)
    
    # Hub rotor power (cp_at_tsr model, same as settle scan)
    lambda = clamp(omega_shaft * sys.rotor.radius / V_wind, 0.0, 12.0)
    cp = cp_at_tsr(lambda)
    P_hub = 0.5 * p.rho * V_wind^3 * π * sys.rotor.radius^2 * cp * cos(p.elevation_angle)^2.65
    
    # Hub torque at ground shaft
    tau_hub = cp > 0 ? P_hub / max(omega_shaft, 0.01) : 0.0
    
    # Expansion rotors — use ring nominal radii from sys
    P_exp_total = 0.0
    tau_exp_total = 0.0
    for er in sys.expansion_rotors
        ri = er.ring_idx
        ri < 1 || ri > Nr && continue
        rnom = (sys.nodes[sys.ring_ids[ri]]::RingNode).radius
        # Estimate tension — same order as gate for comparison
        T_est = 1500.0  # representative value
        
        try
            _, _, tn, _, _ = expansion_rotor_forces(er, p.rho, V_wind, omega_shaft, elev_deg, rnom, T_est, p.n_lines)
            tau_exp_total += tn
            P_exp_total += tn * omega_shaft
        catch e
            # silent — some ω may be out of range
        end
    end
    
    tau_net = tau_hub + tau_exp_total
    P_aero_total = P_hub + P_exp_total
    P_gen = p.k_mppt * omega_shaft^3  # generator load (but we're sweeping ω, not solving equilibrium)
    
    return (omega_shaft=omega_shaft, P_hub_kw=P_hub/1000, P_exp_kw=P_exp_total/1000, 
            P_aero_kw=P_aero_total/1000, P_gen_kw=P_gen/1000, tau_hub=tau_hub, tau_exp=tau_exp_total,
            lambda_hub=lambda)
end

function sweep_one(label, blade_scale, v_wind, omega_range)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=blade_scale)
    
    println("\n══════════════════════════════════════════════")
    println("$label (blade_scale=$blade_scale, V=$v_wind m/s)")
    println("  rotor_radius=$(round(sys.rotor.radius, digits=2))m  hub_area=$(round(π*sys.rotor.radius^2, digits=1))m²")
    println("  expansion rotors: $(length(sys.expansion_rotors))")
    for er in sys.expansion_rotors
        area = π * (er.blade_tip_radius^2 - er.blade_hub_radius^2)
        println("    R$(er.ring_idx): tip=$(round(er.blade_tip_radius, digits=3))m hub=$(round(er.blade_hub_radius, digits=3))m area=$(round(area, digits=2))m² bank=$(er.bank_angle_deg)°")
    end
    println()
    println("  ω(rpm)  ω(rad/s)  λ_hub  P_hub(kW)  P_exp(kW)  P_aero(kW)  P_gen(kW)  τ_net(Nm)")
    println("  " * "─"^80)
    
    best_P = 0.0; best_ω = 0.0; best_τ = 0.0
    for omega in omega_range
        r = static_power(sys, p, omega, v_wind)
        @printf("  %6.0f   %7.2f   %5.2f   %7.1f    %7.1f    %7.1f    %7.1f    %8.1f\n",
                omega*60/(2π), omega, r.lambda_hub, r.P_hub_kw, r.P_exp_kw, r.P_aero_kw, r.P_gen_kw, r.tau_hub+r.tau_exp)
        if r.P_exp_kw > best_P
            best_P = r.P_exp_kw; best_ω = omega; best_τ = r.tau_exp
        end
    end
    
    println("\n  → Peak expansion aero: $(round(best_P, digits=1)) kW at ω=$(round(best_ω*60/(2π), digits=0)) rpm ($(round(best_ω, digits=1)) rad/s)")
    return best_P, best_ω
end

# Sweep from 50 to 400 rpm
omega_range = range(5.0, 45.0, length=41)  # 5 to 45 rad/s, 48-430 rpm

# ── λ = 1.0 (gate reference) ──
P1, ω1 = sweep_one("λ=1.0 (V10 Tight gate)", 1.0, 11.0, omega_range)

# ── λ = 0.54 ──
P2, ω2 = sweep_one("λ=0.54", 0.54, 11.0, omega_range)

println("\n══════════════════════════════════════════════")
println("COMPARISON:")
println("  λ=1.0: P_exp_max = $(round(P1, digits=1)) kW at ω=$(round(ω1*60/(2π), digits=0)) rpm")
println("  λ=0.54: P_exp_max = $(round(P2, digits=1)) kW at ω=$(round(ω2*60/(2π), digits=0)) rpm")
println("  Ratio (P): $(round(P2/P1, digits=3))   λ² = $(round(0.54^2, digits=3))")
println("  Ratio (ω): $(round(ω2/ω1, digits=3))")
