#!/usr/bin/env julia
using KiteTurbineDynamics, LinearAlgebra

x = [0.06, 0.01, 0.87994, 1.0, 2.8885, 2.6, 2.9879, 13.208, -0.1098,
     18.558, 31.99, 34.999, 1.0, 1.0]
p = params_v5_50kw()
dt = 4e-5
T_SIM = 60.0

function extract_power(u, sys)
    N = sys.n_total; Nr = sys.n_ring
    sum(sys.k_mppt_ref[] * u[6N+Nr+ri]^3 for ri in 1:Nr)
end

# ── Dashboard path ──
sys_d, u0_d, p_d, _, _ = build_v10_tight_no_lowest(r_bottom_scale=1.30, tether_diameter=0.004)
wf(pos, t) = (z = max(pos[3], 1.0); [11.0 * (z / p_d.h_ref)^(1.0 / 7.0), 0.0, 0.0])
u_d = settle_to_operational_state(sys_d, u0_d, p_d, 9.5; wind_fn=wf)
println("Dashboard: running $(T_SIM)s ODE...")
flush(stdout)
run_canonical_sim!(u_d, sys_d, p_d, wf, round(Int, T_SIM/dt), dt; lin_damp=0.05)
P_kw_d = abs(extract_power(u_d, sys_d)) / 1000
ω_d = u_d[6*sys_d.n_total + sys_d.n_ring + sys_d.n_ring]
println("Dashboard $(T_SIM)s: P=$(round(P_kw_d, digits=1)) kW  ω=$(round(ω_d, digits=1)) rad/s ($(round(ω_d*60/(2π),digits=1)) rpm)")

# ── Evaluator path ──
result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=50000.0, v_rated=11.0)
sys_e, u0_e, pc_e = KiteTurbineDynamics.build_system_from_v10(result, 1.0, 614.9186938124421; tether_diameter=0.004)
wf2(pos, t) = (z = max(pos[3], 1.0); [11.0 * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0])
u_e = settle_to_operational_state(sys_e, u0_e, pc_e, 9.5; wind_fn=wf2)
println("Evaluator: running $(T_SIM)s ODE...")
flush(stdout)
run_canonical_sim!(u_e, sys_e, pc_e, wf2, round(Int, T_SIM/dt), dt; lin_damp=0.05)
P_kw_e = abs(extract_power(u_e, sys_e)) / 1000
ω_e = u_e[6*sys_e.n_total + sys_e.n_ring + sys_e.n_ring]
println("Evaluator $(T_SIM)s: P=$(round(P_kw_e, digits=1)) kW  ω=$(round(ω_e, digits=1)) rad/s ($(round(ω_e*60/(2π),digits=1)) rpm)")

println("\nDashboard: n_active=$(length(sys_d.expansion_rotors)) k_mppt=$(sys_d.k_mppt_ref[])")
println("Evaluator: n_active=$(length(sys_e.expansion_rotors)) k_mppt=$(sys_e.k_mppt_ref[])")
