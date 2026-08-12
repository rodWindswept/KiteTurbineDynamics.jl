#!/usr/bin/env julia
using KiteTurbineDynamics, LinearAlgebra

function bem_power(sys, p, w, v_mag)
    r_hub = sys.rotor.radius
    lambda = w * r_hub / v_mag
    P_hub = 0.5 * p.rho * v_mag^3 * π * r_hub^2 * cp_at_tsr(lambda) * cos(p.elevation_angle)^2.65
    P_exp = 0.0
    for er in sys.expansion_rotors
        area = π * (er.blade_tip_radius^2 - er.blade_hub_radius^2)
        lambda_er = clamp(w * er.blade_tip_radius / v_mag, 0.0, 12.0)
        P_exp += 0.5 * p.rho * v_mag^3 * area * cp_at_tsr(lambda_er) * cosd(er.bank_angle_deg)
    end
    return P_hub + P_exp
end

function find_peak(sys, p)
    v_mag = 11.0
    best = (P=0.0, w=0.0)
    for w in range(0.5, 12.0, length=200)
        P = bem_power(sys, p, w, v_mag)
        if P > best.P; best = (P=P, w=w); end
    end
    return best
end

function find_op_point(sys, p, frac)
    v_mag = 11.0
    peak = find_peak(sys, p)
    target = peak.P * frac
    w_op = peak.w
    for w in range(peak.w, 0.3, length=500)
        if bem_power(sys, p, w, v_mag) <= target
            w_op = w; break
        end
    end
    k = target / w_op^3
    return (P_kw=target/1000, w=w_op, k=k)
end

# Build system
sys, u0, p, _, _ = build_v10_tight_no_lowest(r_bottom_scale=1.30, tether_diameter=0.004)
ld = rotary_lifter_default()
wf(pos, t) = (z = max(pos[3], 1.0); [11.0 * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0])
N = sys.n_total; Nr = sys.n_ring; dt = 4e-5

peak = find_peak(sys, p)
println("Peak: P=$(round(peak.P/1000, digits=1)) kW at ω=$(round(peak.w, digits=2)) rad/s")
k_peak = peak.P / peak.w^3
println("k_mppt at peak: $(round(k_peak, digits=2))")

for frac in [0.95, 0.90, 0.85, 0.80]
    op = find_op_point(sys, p, frac)
    println("  $(Int(frac*100))%: P=$(round(op.P_kw, digits=1)) kW  ω=$(round(op.w, digits=2))  k=$(round(op.k, digits=2))")
end

# ODE test
k_test = k_peak
sys.k_mppt_ref[] = k_test
println("\n── ODE test: k_mppt=$(round(k_test, digits=2)) ──")
for t_sim in [10.0, 20.0, 30.0]
    u_s = settle_to_operational_state(sys, u0, p, 12.0; wind_fn=wf, lift_device=ld)
    run_canonical_sim!(u_s, sys, p, wf, round(Int, t_sim/dt), dt; lin_damp=0.05, lift_device=ld)
    P_kw = abs(sum(k_test * u_s[6N+Nr+ri]^3 for ri in 1:Nr)) / 1000
    ω = u_s[6N + Nr + Nr]
    println("  $(Int(t_sim))s: P=$(round(P_kw, digits=1)) kW  ω=$(round(ω, digits=1)) rad/s ($(round(ω*60/(2π),digits=1)) rpm)")
end
