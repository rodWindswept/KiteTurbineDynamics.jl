#!/usr/bin/env julia
# eb_079.jl — energy balance for λ=0.79
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const BS = 0.79; const K_VAL = 15.6 * BS^2
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function energy_balance(blade_scale, k_val, label)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=blade_scale)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = begin z = max(pos[3], 1.0); [11.0*(z/p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), p, 40.0; lift_device=lift, wind_fn=wf)
    n = round(Int, 10.0/DT)
    run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=0.05)
    
    N = sys.n_total; Nr = sys.n_ring
    omega_shaft = abs(u[6N + Nr + 1])
    hub_gid = sys.rotor.node_id
    hub_ctr = u[(3*(hub_gid-1)+1):(3*hub_gid)]
    v_vec = wf(hub_ctr, 0.0); V_hub = max(sqrt(v_vec[1]^2+v_vec[2]^2), 0.1)
    elev_deg = rad2deg(p.elevation_angle)
    
    lambda = clamp(omega_shaft*sys.rotor.radius/V_hub, 0.0, 12.0)
    cp = cp_at_tsr(lambda)
    P_hub = 0.5*p.rho*V_hub^3*π*sys.rotor.radius^2*cp*cos(p.elevation_angle)^2.65/1000
    
    P_exp = 0.0
    for er in sys.expansion_rotors
        ri = er.ring_idx
        ri < 1 || ri > Nr && continue
        rgid = sys.ring_ids[ri]; rpos = u[(3*(rgid-1)+1):(3*rgid)]
        rω = abs(u[6N+Nr+ri]); rnom = (sys.nodes[rgid]::RingNode).radius
        vw = wf(rpos, 0.0); vm = max(sqrt(vw[1]^2+vw[2]^2), 0.1)
        T_est = ri > 1 ? sum(KiteTurbineDynamics.get_segment_tension(u, sys, p, ri-1, j) for j in 1:p.n_lines)/p.n_lines : 100.0
        _, _, tn, _, _ = expansion_rotor_forces(er, p.rho, vm, rω, elev_deg, rnom, max(T_est, 100.0), p.n_lines)
        P_exp += tn * rω / 1000
    end
    
    P_aero = P_hub + P_exp
    P_gen = k_val * omega_shaft^3 / 1000
    
    println()
    println("═══════════════════════════════════════════════")
    println("$label ENERGY BALANCE")
    println("  ω = $(round(omega_shaft*60/(2π), digits=1)) rpm")
    println("  Hub aero:   $(round(P_hub, digits=1)) kW")
    println("  Exp aero:   $(round(P_exp, digits=1)) kW")
    println("  Σ Aero:     $(round(P_aero, digits=1)) kW")
    println("  Generator:  $(round(P_gen, digits=1)) kW  (k=$(round(k_val, digits=1)))")
    println("  Loss:       $(round(P_aero - P_gen, digits=1)) kW  ($(round((P_aero-P_gen)/P_aero*100, digits=0))%)")
    println("  Shaft η:    $(round(P_gen/P_aero*100, digits=0))%")
    
    return (P_aero, P_gen, P_gen/P_aero*100)
end

println("Running gate...")
g = energy_balance(1.0, 15.6, "GATE λ=1.0")
println("Running λ=0.79...")
r = energy_balance(BS, K_VAL, "λ=0.79")
println("Running λ=0.54...")
s = energy_balance(0.54, 2.3, "λ=0.54")

println()
println("═══════════════════════════════════════════════")
println("THREE-POINT SHAFT EFFICIENCY")
println("  Gate λ=1.0: $(round(g[3], digits=0))%")
println("  λ=0.79:     $(round(r[3], digits=0))%")
println("  λ=0.54:     $(round(s[3], digits=0))%")
