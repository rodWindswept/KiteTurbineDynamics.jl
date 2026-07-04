#!/usr/bin/env julia
# diag_forces.jl — call expansion_rotor_forces directly to find what fails
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const BS = 0.54; const V_WIND = 11.0
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=BS)
sys.k_mppt_ref[] = 2.3
wf(pos, t) = begin z = max(pos[3], 1.0); [V_WIND*(z/p.h_ref)^(1/7), 0.0, 0.0] end
lift = KiteTurbineDynamics.rotary_lifter_default()

# Settle quickly
u = settle_to_operational_state(sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf)

N = sys.n_total; Nr = sys.n_ring
omega_shaft = abs(u[6N + Nr + 1])
hub_gid = sys.rotor.node_id
hub_ctr = u[(3*(hub_gid-1)+1):(3*hub_gid)]
v_vec = wf(hub_ctr, 0.0); V_hub = max(sqrt(v_vec[1]^2+v_vec[2]^2), 0.1)
elev_deg = rad2deg(p.elevation_angle)

println("System state after settle:")
println("  omega_shaft = $(round(omega_shaft, digits=2)) rad/s = $(round(omega_shaft*60/(2pi), digits=1)) rpm")
println("  V_hub = $(round(V_hub, digits=1)) m/s")
println()

for (i, er) in enumerate(sys.expansion_rotors)
    println("Rotor $i: ring=$(er.ring_idx)  tip=$(round(er.blade_tip_radius, digits=3))m  hub=$(round(er.blade_hub_radius, digits=3))m  chord=$(round(er.blade_chord, digits=3))m  bank=$(er.bank_angle_deg)°")
    ri = er.ring_idx
    if ri < 1 || ri > Nr
        println("  SKIP: ring_idx $ri out of range [1, $Nr]")
        continue
    end
    rgid = sys.ring_ids[ri]
    rpos = u[(3*(rgid-1)+1):(3*rgid)]
    rω = abs(u[6N+Nr+ri])
    rnom = (sys.nodes[rgid]::RingNode).radius
    vw = wf(rpos, 0.0); vm = max(sqrt(vw[1]^2+vw[2]^2), 0.1)
    T_est = ri > 1 ? sum(KiteTurbineDynamics.get_segment_tension(u, sys, p, ri-1, j) for j in 1:p.n_lines)/p.n_lines : 100.0
    T_est = max(T_est, 100.0)
    
    println("  ri=$ri  rnom=$(round(rnom, digits=3))m  rω=$(round(rω, digits=2)) rad/s  vm=$(round(vm, digits=1)) m/s  T_est=$(round(T_est, digits=1)) N")
    
    try
        fr, fa, tn, re, orot = KiteTurbineDynamics.expansion_rotor_forces(er, p.rho, vm, rω, elev_deg, rnom, T_est, p.n_lines)
        println("  → F_radial=$(round(fr, digits=1)) N  F_axial=$(round(fa, digits=1)) N  τ_net=$(round(tn, digits=2)) N·m  P=$(round(tn*rω/1000, digits=2)) kW")
    catch e
        println("  ✗ ERROR: $(typeof(e)): $(e)")
        for (exc, bt) in current_exceptions()
            println("    $(bt)")
        end
    end
end
