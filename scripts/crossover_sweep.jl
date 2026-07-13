using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

fn = ControlMapHunt.v10_tight_builder(blade_scale=0.69, r_bottom_scale=1.30, tether_diameter=0.004)
sys, u0, p, _ = Base.invokelatest(fn)
sp = SpokeParams(enabled=true)
wind_ms = 11.0
wf(pos, t) = (z = max(pos[3], 1.0); [wind_ms * (z / p.h_ref)^(1 / 7), 0.0, 0.0])
N = sys.n_total; Nr = sys.n_ring
hr = (sys.nodes[sys.rotor.node_id] :: RingNode).ring_idx

function run_sweep()
    println("=== λ=0.69 Reinforced, $(wind_ms) m/s — aero vs parasitic torque ===")
    println("   k     ω(rpm)   ω(rad/s)   P_aero(kW)  P_par(kW)  τ_aero(Nm)  τ_par(Nm)  τ_net(Nm)")
    local prev_tau_net = -Inf
    for k_log in 0.3:0.2:2.3
        k = 10.0^k_log
        sys.k_mppt_ref[] = k
        u = copy(u0)
        KiteTurbineDynamics.run_canonical_sim!(u, sys, p, wf,
            round(Int, 5.0 / ControlMapHunt.DT), ControlMapHunt.DT;
            lift_device=nothing, lin_damp=0.05, spoke=sp)
        w_rads = abs(u[6N + Nr + hr])
        w_rpm = w_rads * 60 / (2π)
        if w_rpm < 1; continue; end
        
        ef = ControlMapHunt.capture_extended(u, sys, p, 5.0, wf, nothing; brake_engaged=false)
        P_aero = sum(ef.rotor_aero_power)
        P_par = sum(ef.rotor_ground_power)
        tau_aero = P_aero * 1000 / max(w_rads, 0.01)
        tau_par = P_par * 1000 / max(w_rads, 0.01)
        tau_net = tau_aero - tau_par
        
        cross = (prev_tau_net < 0 && tau_net > 0) ? "  ← CROSSOVER" : ""
        @printf("%5.0f  %6.0f   %8.2f  %10.2f  %8.2f  %10.0f  %9.0f  %10.0f%s\n",
            k, w_rpm, w_rads, P_aero, P_par, tau_aero, tau_par, tau_net, cross)
        prev_tau_net = tau_net
        if w_rpm > 400; break; end
    end
end

run_sweep()
println("Done")
