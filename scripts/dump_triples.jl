#!/usr/bin/env julia
# dump_triples.jl — (ω, P_aero, P_ground) for all 8 runs + regression data
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const K0 = 15.6
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_full(blade_scale, v_wind)
    k_val = blade_scale == 1.0 ? 15.6 : K0 * blade_scale^2
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=blade_scale)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = begin z = max(pos[3], 1.0); [v_wind*(z/p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    ω_max = v_wind < 9.0 ? 25.0 : 40.0
    u = settle_to_operational_state(sys, copy(u0), p, ω_max; lift_device=lift, wind_fn=wf)
    n = round(Int, 10.0/DT)
    
    Pg_ref = Ref(0.0); ω_ref = Ref(0.0)
    run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=0.05,
        callback=(uc, tc, step) -> begin
            if step == n
                ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
                Pg_ref[] = ef.base.P_kw; ω_ref[] = ef.base.omega_hub
            end
        end)
    
    # Energy balance at converged state
    N = sys.n_total; Nr = sys.n_ring
    omega = abs(u[6N+Nr+1])
    hub_gid = sys.rotor.node_id; hub_ctr = u[(3*(hub_gid-1)+1):(3*hub_gid)]
    v_vec = wf(hub_ctr, 0.0); V_hub = max(sqrt(v_vec[1]^2+v_vec[2]^2), 0.1)
    elev_deg = rad2deg(p.elevation_angle)
    lambda = clamp(omega*sys.rotor.radius/V_hub, 0.0, 12.0)
    P_hub = 0.5*p.rho*V_hub^3*π*sys.rotor.radius^2*cp_at_tsr(lambda)*cos(p.elevation_angle)^2.65/1000
    P_exp = 0.0
    for er in sys.expansion_rotors
        ri = er.ring_idx; ri < 1 || ri > Nr && continue
        rgid = sys.ring_ids[ri]; rpos = u[(3*(rgid-1)+1):(3*rgid)]
        rω = abs(u[6N+Nr+ri]); rnom = (sys.nodes[rgid]::RingNode).radius
        vw2 = wf(rpos, 0.0); vm = max(sqrt(vw2[1]^2+vw2[2]^2), 0.1)
        T_est = ri > 1 ? sum(KiteTurbineDynamics.get_segment_tension(u, sys, p, ri-1, j) for j in 1:p.n_lines)/p.n_lines : 100.0
        _, _, tn, _, _ = expansion_rotor_forces(er, p.rho, vm, rω, elev_deg, rnom, max(T_est, 100.0), p.n_lines)
        P_exp += tn * rω / 1000
    end
    P_aero = P_hub + P_exp
    P_gen = k_val * omega^3 / 1000
    P_g_sim = Pg_ref[]
    loss = P_aero - P_g_sim
    ω_rpm = omega * 60 / (2 * pi)
    
    return (v=v_wind, λ=blade_scale, k=k_val, ω_rad=omega, ω_rpm=ω_rpm, 
            P_hub=P_hub, P_exp=P_exp, P_aero=P_aero, P_gen=P_gen, P_sim=P_g_sim, loss=loss)
end

println("DESIGN  WIND  λ     k_set  ω(rad/s) ω(rpm)  P_hub  P_exp   P_aero  P_gen  P_sim  Loss")
println("─"^95)

all_runs = []
for bs in [1.0, 0.69]
    for v in (bs == 1.0 ? [11.0, 15.0] : [5.0, 7.0, 9.0, 11.0, 13.0, 15.0])
        r = run_full(bs, v)
        push!(all_runs, r)
        label = bs == 1.0 ? "Gate " : "λ0.69"
        @printf("%-7s %4.0f  %4.2f  %5.1f  %7.2f  %6.0f  %5.1f  %6.1f  %6.1f  %6.1f  %6.1f  %5.1f\n",
                label, r.v, r.λ, r.k, r.ω_rad, r.ω_rpm, r.P_hub, r.P_exp, r.P_aero, r.P_gen, r.P_sim, r.loss)
        # Consistency check
        if abs(r.P_sim - r.P_gen) / max(r.P_sim, 1.0) > 0.05
            println("  ⚠ P_sim/P_gen mismatch: $(round(r.P_sim, digits=1)) vs $(round(r.P_gen, digits=1))")
        end
    end
end

# ── Regression ──
println()
println("════════════════════════════════════════════════════════")
println("LOSS REGRESSION")
println("model: loss = c * ω³")
println()
for r in all_runs
    c = r.loss * 1000 / r.ω_rad^3
    loss_frac = r.loss / r.P_aero * 100
    label = r.λ == 1.0 ? "Gate" : "λ=0.69"
    println("  $(label) $(Int(r.v))m/s: c=$(round(c, digits=2)) W/(rad/s)³  loss/Paero=$(round(loss_frac, digits=1))%")
end

c_vals = [r.loss * 1000 / r.ω_rad^3 for r in all_runs]
c_mean = sum(c_vals) / length(c_vals)
println()
println("  Mean c = $(round(c_mean, digits=1)) W/(rad/s)³  (±$(round(100*maximum(abs.(c_vals .- c_mean))/c_mean, digits=0))%)")
println()

println("model: loss = c/(k+c) fraction")
for r in all_runs
    frac_pred = c_mean / (r.k + c_mean) * 100
    frac_actual = r.loss / r.P_aero * 100
    label = r.λ == 1.0 ? "Gate" : "λ=0.69"
    println("  $(label) $(Int(r.v))m/s: predicted=$(round(frac_pred, digits=1))%  actual=$(round(frac_actual, digits=1))%")
end
