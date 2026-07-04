#!/usr/bin/env julia
# discriminator.jl — test λ=0.54 at k=4.55 AND k=2.3 to get ω-dependent loss curve
# If loss∝ω, then at 150 rpm loss ≈ 28.4 × 150/207 ≈ 20.6 kW
# If loss is constant, it stays ~28 kW
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function energy_balance(blade_scale, k_val, label)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=blade_scale)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = begin z = max(pos[3], 1.0); [11.0*(z/p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), p, 35.0; lift_device=lift, wind_fn=wf)
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
    ω_rpm = omega_shaft*60/(2π)
    loss = P_aero - P_gen
    η = P_gen / P_aero * 100
    
    println("$(label): ω=$(round(ω_rpm, digits=1)) rpm  P_aero=$(round(P_aero, digits=1)) kW  P_gen=$(round(P_gen, digits=1)) kW  loss=$(round(loss, digits=1)) kW ($(round(loss/P_aero*100, digits=0))%)  η=$(round(η, digits=0))%")
    return (ω=ω_rpm, P_aero=P_aero, P_gen=P_gen, loss=loss, η=η)
end

println("═"^70)
println("DISCRIMINATOR: λ=0.54 at two k values")
println("═"^70)
println()

# Point 1: r_mean-corrected k=2.3 (already known: ω≈207, loss≈28.4)
println("Same blade scale, different k → different ω → test loss∝ω")
r1 = energy_balance(0.54, 2.3, "λ=0.54 k=2.3")

# Point 2: pure λ² k=4.55 (predicted ω≈150, P_gen≈17.9)
r2 = energy_balance(0.54, 4.55, "λ=0.54 k=4.55")

# Point 3: k=9.1 (stronger braking, even lower ω)
r3 = energy_balance(0.54, 9.1, "λ=0.54 k=9.1")

println()
println("═"^70)
println("LOSS vs ω ANALYSIS")
println("═"^70)

# Gate reference point (from earlier run)
gate_ω = 221.2; gate_loss = 27.8

all_ω  = [gate_ω, r1.ω, r2.ω, r3.ω]
all_loss = [gate_loss, r1.loss, r2.loss, r3.loss]

println("  Point        ω(rpm)   Loss(kW)   Loss/P_aero")
println("  " * "─"^50)
for (label, ω, loss) in zip(["Gate λ=1.0 k=15.6", "λ=0.54 k=2.3", "λ=0.54 k=4.55", "λ=0.54 k=9.1"], all_ω, all_loss)
    println("  $(rpad(label, 18)) $(rpad(string(round(ω, digits=1)), 10)) $(string(round(loss, digits=1)))")
end

# Fit: loss = τ_d · ω  (viscous drag torque model)
# τ_d ≈ loss / ω (rad/s)
println()
for (label, ω, loss) in zip(["Gate λ=1.0", "λ=0.54 k=2.3", "λ=0.54 k=4.55", "λ=0.54 k=9.1"], all_ω, all_loss)
    ω_radps = ω * 2π / 60
    τ = loss / ω_radps
    println("  $label: τ_d = $(round(loss, digits=1)) kW / $(round(ω_radps, digits=1)) rad/s = $(round(τ, digits=3)) kN·m")
end
