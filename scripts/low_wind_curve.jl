#!/usr/bin/env julia
# low_wind_curve.jl — P(v) at 5/7/9/11 m/s for λ=0.69 + loss vs ω test
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const K0 = 15.6; const BS = 0.69
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_point(v_wind, ω_max)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=BS)
    sys.k_mppt_ref[] = K0 * BS^2
    wf(pos, t) = begin z = max(pos[3], 1.0); [v_wind * (z / p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), p, ω_max; lift_device=lift, wind_fn=wf)
    n = round(Int, 10.0 / DT)
    Pr = Ref(0.0); wr = Ref(0.0); fr = Ref(Inf)
    run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=0.05,
        callback=(uc, tc, step) -> begin
            if step == n
                ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
                Pr[] = ef.base.P_kw; wr[] = ef.base.omega_hub * 60 / (2 * pi)
                fv = Float64[]
                for i in 2:length(ef.ring_fos)
                    val = ef.ring_fos[i]
                    if !isnan(val) && !isinf(val) && val > 0; push!(fv, val); end
                end
                fr[] = isempty(fv) ? Inf : minimum(fv)
            end
        end)
    
    # Energy balance at converged state
    N = sys.n_total; Nr = sys.n_ring
    omega = abs(u[6N + Nr + 1])
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
    loss = P_aero - Pr[]
    
    return (P=Pr[], ω=wr[], FoS=fr[], loss=loss, P_aero=P_aero)
end

println("λ=0.69 LOW-WIND CURVE + LOSS vs ω")
println("Wind   P(kW)   ω(rpm)  FoS    ΣAero   Loss   v³-ratio")
println("─"^65)
results = []
for v in [5.0, 7.0, 9.0, 11.0]
    ω_max = v < 9.0 ? 25.0 : 40.0
    r = run_point(v, ω_max)
    push!(results, (v=v, r...))
    v3_ratio = (v / 11.0)^3
    p_pred = 62.1 * v3_ratio  # using 11 m/s baseline with m_blade fix
    println("$(Int(v)) m/s  $(round(r.P, digits=1))    $(round(r.ω, digits=1))     $(round(r.FoS, digits=2))   $(round(r.P_aero, digits=1))   $(round(r.loss, digits=1))   $(round(v3_ratio, digits=3)) (expect $(round(p_pred, digits=1)))")
end

# Also run λ=1.0 gate at 11 and 15 m/s for loss-vs-ω comparison
println()
println("LOSS vs ω COMPARISON")
for (label, bs, k, v) in [("Gate 11", 1.0, 15.6, 11.0), ("Gate 15", 1.0, 15.6, 15.0), ("λ=0.69 11", 0.69, K0*0.69^2, 11.0), ("λ=0.69 15", 0.69, K0*0.69^2, 15.0)]
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=bs)
    sys.k_mppt_ref[] = k
    wf(pos, t) = begin z = max(pos[3], 1.0); [v*(z/p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), p, 40.0; lift_device=lift, wind_fn=wf)
    n = round(Int, 10.0/DT); Pr = Ref(0.0)
    run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=0.05,
        callback=(uc, tc, step) -> begin
            if step == n; ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[]); Pr[] = ef.base.P_kw; end
        end)
    N = sys.n_total; Nr = sys.n_ring; omega = abs(u[6N+Nr+1])
    hub_ctr = u[(3*(sys.rotor.node_id-1)+1):(3*sys.rotor.node_id)]
    vw = wf(hub_ctr, 0.0); V_hub = max(sqrt(vw[1]^2+vw[2]^2), 0.1)
    lambda = clamp(omega*sys.rotor.radius/V_hub, 0.0, 12.0)
    P_hub = 0.5*p.rho*V_hub^3*π*sys.rotor.radius^2*cp_at_tsr(lambda)*cos(p.elevation_angle)^2.65/1000
    P_exp = 0.0
    elev_deg = rad2deg(p.elevation_angle)
    for er in sys.expansion_rotors
        ri = er.ring_idx; ri < 1 || ri > Nr && continue
        rgid = sys.ring_ids[ri]; rpos = u[(3*(rgid-1)+1):(3*rgid)]
        rω = abs(u[6N+Nr+ri]); rnom = (sys.nodes[rgid]::RingNode).radius
        vw2 = wf(rpos, 0.0); vm = max(sqrt(vw2[1]^2+vw2[2]^2), 0.1)
        T_est = ri > 1 ? sum(KiteTurbineDynamics.get_segment_tension(u, sys, p, ri-1, j) for j in 1:p.n_lines)/p.n_lines : 100.0
        _, _, tn, _, _ = expansion_rotor_forces(er, p.rho, vm, rω, elev_deg, rnom, max(T_est, 100.0), p.n_lines)
        P_exp += tn * rω / 1000
    end
    loss = P_hub + P_exp - Pr[]
    rpm = omega * 60 / (2 * pi)
    const_tau_pred = 28.0 * omega / 23.2  # loss ∝ ω if constant torque
    println("  $label: ω=$(round(rpm, digits=0)) rpm  loss=$(round(loss, digits=1)) kW  const-τ pred=$(round(const_tau_pred, digits=1)) kW")
end
