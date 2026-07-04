#!/usr/bin/env julia
# damp_test.jl — halve lin_damp, re-run gate. Loss halves → solver artifact. Unchanged → physics.
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const V_WIND = 11.0
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_gate(damp, label)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=1.0)
    sys.k_mppt_ref[] = 15.6
    wf(pos, t) = begin z = max(pos[3], 1.0); [V_WIND*(z/p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), p, 35.0; lift_device=lift, wind_fn=wf)
    n = round(Int, 10.0/DT)
    Pr = Ref(0.0); wr = Ref(0.0)
    run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=damp,
        callback=(uc, tc, step) -> begin
            if step == n
                ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
                Pr[] = ef.base.P_kw; wr[] = ef.base.omega_hub*60/(2pi)
            end
        end)
    
    # Quick aero
    N = sys.n_total; Nr = sys.n_ring; omega = abs(u[6N+Nr+1])
    hub_gid = sys.rotor.node_id; hub_ctr = u[(3*(hub_gid-1)+1):(3*hub_gid)]
    v_vec = wf(hub_ctr, 0.0); V_hub = max(sqrt(v_vec[1]^2+v_vec[2]^2), 0.1)
    elev_deg = rad2deg(p.elevation_angle)
    lambda = clamp(omega*sys.rotor.radius/V_hub, 0.0, 12.0)
    cp = cp_at_tsr(lambda)
    P_hub = 0.5*p.rho*V_hub^3*π*sys.rotor.radius^2*cp*cos(p.elevation_angle)^2.65/1000
    P_exp = 0.0
    for er in sys.expansion_rotors
        ri = er.ring_idx; ri < 1 || ri > Nr && continue
        rgid = sys.ring_ids[ri]; rpos = u[(3*(rgid-1)+1):(3*rgid)]
        rω = abs(u[6N+Nr+ri]); rnom = (sys.nodes[rgid]::RingNode).radius
        vw = wf(rpos, 0.0); vm = max(sqrt(vw[1]^2+vw[2]^2), 0.1)
        T_est = ri > 1 ? sum(KiteTurbineDynamics.get_segment_tension(u, sys, p, ri-1, j) for j in 1:p.n_lines)/p.n_lines : 100.0
        _, _, tn, _, _ = expansion_rotor_forces(er, p.rho, vm, rω, elev_deg, rnom, max(T_est, 100.0), p.n_lines)
        P_exp += tn * rω / 1000
    end
    P_aero = P_hub + P_exp
    P_gen = 15.6 * omega^3 / 1000
    loss = P_aero - P_gen
    
    println("  $label: lin_damp=$damp  P_gen=$(round(Pr[], digits=1)) kW  ω=$(round(wr[], digits=1)) rpm  loss=$(round(loss, digits=1)) kW ($(round(loss/P_aero*100, digits=0))%)  η=$(round(P_gen/P_aero*100, digits=0))%")
    return loss
end

println("DAMPING SENSITIVITY — Gate at 11 m/s, vary lin_damp")
println("─"^60)
l1 = run_gate(0.05, "baseline")
l2 = run_gate(0.025, "half")
l3 = run_gate(0.0, "zero")

println()
if abs(l2 - l1) < 3.0
    println("✓ Loss insensitive to damping → structural/geometric, not solver artifact")
else
    println("✗ Loss scales with damping → efficiency numbers are arbitrary. All η claims need 'unvalidated damping' caveat.")
end
