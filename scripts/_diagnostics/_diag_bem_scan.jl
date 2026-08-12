#!/usr/bin/env julia
# Instrument the BEM scan vs actual ODE aero power at the same ω
using KiteTurbineDynamics, LinearAlgebra

# V10 reinforced genome
x = [0.06, 0.01, 0.87994, 1.0, 2.8885, 2.6, 2.9879, 13.208, -0.1098,
     18.558, 31.99, 34.999, 1.0, 1.0]

# Build dashboard-style system
sys, u0, p, _, _ = build_v10_tight_no_lowest(r_bottom_scale=1.30, tether_diameter=0.004)
ld = rotary_lifter_default()
wf(pos, t) = (z = max(pos[3], 1.0); [11.0 * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0])

N = sys.n_total; Nr = sys.n_ring
k_mppt = sys.k_mppt_ref[]
println("k_mppt = $(round(k_mppt, digits=1))")
println("hub rotor radius = $(round(sys.rotor.radius, digits=3)) m")
for (i, er) in enumerate(sys.expansion_rotors)
    println("  exp rotor $i: tip_radius=$(round(er.blade_tip_radius, digits=3))  bank=$(er.bank_angle_deg)°")
end

# ── Replicate the BEM scan from settle_to_operational_state ──
v_wind_hub = wf(u0[(3*(sys.rotor.node_id-1)+1):(3*sys.rotor.node_id)], 0.0)
v_mag = norm(v_wind_hub)
println("\nv_wind at hub = $(round(v_mag, digits=1)) m/s")

println("\n── BEM scan (ω → P_aero vs P_gen) ──")
println("  ω(rad/s)  rpm    λ_hub   cp_hub  P_aero(kW)  P_gen(kW)  surplus")
ω_rated_max = 9.5
has_exp = !isempty(sys.expansion_rotors)
for w in range(ω_rated_max, 0.1; length=20)
    lambda = w * sys.rotor.radius / v_mag
    cp_h = cp_at_tsr(lambda)
    P_hub = 0.5 * p.rho * v_mag^3 * π * sys.rotor.radius^2 * cp_h * cos(p.elevation_angle)^2.65
    
    P_exp = 0.0
    if has_exp
        for er in sys.expansion_rotors
            r_tip = er.blade_tip_radius
            r_hub_e = er.blade_hub_radius
            area = π * (r_tip^2 - r_hub_e^2)
            lambda_er = clamp(w * r_tip / v_mag, 0.0, 12.0)
            cp_er = cp_at_tsr(lambda_er)
            P_exp += 0.5 * p.rho * v_mag^3 * area * cp_er * cosd(er.bank_angle_deg)
        end
    end
    P_aero = P_hub + P_exp
    P_gen = k_mppt * w^3
    
    surplus_kw = (P_aero - P_gen) / 1000
    marker = surplus_kw > 0 ? " ←" : ""
    println("  $(round(w,digits=2))     $(round(w*60/(2π),digits=1))     $(round(lambda,digits=2))    $(round(cp_h,digits=3))   $(round(P_aero/1000,digits=2))         $(round(P_gen/1000,digits=2))       $(round(surplus_kw,digits=2))$marker")
end

# ── Now run ODE at the scan's chosen ω and measure actual power ──
println("\n── ODE test: pin ω at scan values, measure actual P ──")

for w_test in [v for v in [0.8, 2.0, 4.0, 6.0] if v <= ω_rated_max]
    u_s = settle_to_operational_state(sys, u0, p, w_test; wind_fn=wf, lift_device=ld)
    ω_actual = u_s[6N + Nr + Nr]
    
    # Run ODE without pinning ω
    run_canonical_sim!(u_s, sys, p, wf, round(Int, 20.0 / 4e-5), 4e-5; lin_damp=0.05, lift_device=ld)
    
    ω_final = u_s[6N + Nr + Nr]
    P_actual = abs(sum(k_mppt * u_s[6N+Nr+ri]^3 for ri in 1:Nr)) / 1000
    
    # Also compute aero power from the ODE's multibody forces
    # (This is approximate — capture_extended would give exact values)
    println("  ω_rated_max=$(w_test): settle ω=$(round(ω_actual,digits=3)) → 20s ODE: ω=$(round(ω_final,digits=3)) rad/s  P=$(round(P_actual,digits=2)) kW")
end
