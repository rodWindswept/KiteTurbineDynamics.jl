#!/usr/bin/env julia
# energy_balance.jl — compute ΣP_aero (hub + 3 expansion) at the converged operating point
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function energy_balance(label, blade_scale, k_val, ω_max)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=blade_scale)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = begin z = max(pos[3], 1.0); [11.0*(z/p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), p, ω_max; lift_device=lift, wind_fn=wf)
    n = round(Int, 10.0 / 4e-5)
    
    # Run sim to convergence
    run_canonical_sim!(u, sys, p, wf, n, 4e-5; lift_device=lift, lin_damp=0.05)
    
    # Now compute aero powers at the converged state
    N = sys.n_total; Nr = sys.n_ring
    omega_shaft = abs(u[6N + Nr + 1])
    hub_gid = sys.rotor.node_id
    hub_ctr = u[(3*(hub_gid-1)+1):(3*hub_gid)]
    v_vec = wf(hub_ctr, 0.0); V_hub = max(sqrt(v_vec[1]^2+v_vec[2]^2), 0.1)
    elev_deg = rad2deg(p.elevation_angle)
    
    # Hub aero power (cp_at_tsr)
    lambda = clamp(omega_shaft * sys.rotor.radius / V_hub, 0.0, 12.0)
    cp = cp_at_tsr(lambda)
    P_hub_aero = 0.5 * p.rho * V_hub^3 * π * sys.rotor.radius^2 * cp * cos(p.elevation_angle)^2.65
    
    # Expansion rotor powers
    P_exp_aero = 0.0
    P_exp_detail = Float64[]
    for er in sys.expansion_rotors
        ri = er.ring_idx
        ri < 1 || ri > Nr && continue
        rgid = sys.ring_ids[ri]
        rpos = u[(3*(rgid-1)+1):(3*rgid)]
        rω = abs(u[6N+Nr+ri])
        rnom = (sys.nodes[rgid]::RingNode).radius
        vw = wf(rpos, 0.0); vm = max(sqrt(vw[1]^2+vw[2]^2), 0.1)
        T_est = ri > 1 ? sum(KiteTurbineDynamics.get_segment_tension(u, sys, p, ri-1, j) for j in 1:p.n_lines)/p.n_lines : 100.0
        T_est = max(T_est, 100.0)
        _, _, tn, _, _ = expansion_rotor_forces(er, p.rho, vm, rω, elev_deg, rnom, T_est, p.n_lines)
        push!(P_exp_detail, tn * rω / 1000)
        P_exp_aero += tn * rω / 1000
    end
    
    P_aero_total = P_hub_aero/1000 + P_exp_aero
    P_gen = omega_shaft^3 * k_val / 1000  # k·ω³
    P_loss = P_aero_total - P_gen
    
    println("═"^60)
    println("$label")
    println("  ω = $(round(omega_shaft*60/(2π), digits=1)) rpm ($(round(omega_shaft, digits=2)) rad/s)")
    println("  λ_hub = $(round(lambda, digits=2)), cp_hub = $(round(cp, digits=3))")
    println("  Hub aero:     $(round(P_hub_aero/1000, digits=2)) kW")
    for (i, pk) in enumerate(P_exp_detail)
        println("  Exp R$(sys.expansion_rotors[i].ring_idx): $(round(pk, digits=2)) kW")
    end
    println("  Exp total:    $(round(P_exp_aero, digits=1)) kW")
    println("  Σ Aero total: $(round(P_aero_total, digits=1)) kW")
    println("  Generator:    $(round(P_gen, digits=1)) kW  (k=$(k_val))")
    println("  Transmission loss: $(round(P_loss, digits=1)) kW  ($(round(P_loss/P_aero_total*100, digits=0))%)")
    println("  Shaft efficiency: $(round(P_gen/P_aero_total*100, digits=0))%")
    
    # Per-segment twist check
    n_seg = Nr - 1
    alpha_vec = @view u[(6N + 1):(6N + Nr)]
    max_twist = 0.0
    for s in 1:n_seg
        dα = abs(rad2deg(mod(alpha_vec[s+1]-alpha_vec[s]+π, 2π)-π))
        max_twist = max(max_twist, dα)
    end
    println("  Max segment twist: $(round(max_twist, digits=1))°")
    
    return (P_aero_total, P_gen, P_loss, max_twist)
end

# Gate (λ=1.0)
g = energy_balance("GATE λ=1.0, k=15.6", 1.0, 15.6, 35.0)
println()

# λ=0.54, k=2.3
r = energy_balance("λ=0.54, k=2.3", 0.54, 2.3, 60.0)
