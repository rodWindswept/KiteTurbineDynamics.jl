#!/usr/bin/env julia
# scripts/sweep_damping_rate_dtpaired.jl
# DT-paired damping-rate sensitivity sweep for 12-gon at k=60.
# For each lin_damp, run DT and DT/2.  Valid rate = alive (non-trivial P)
# AND dt-convergent (DT≈DT/2 within 15% on P_max and FoS_min).

using KiteTurbineDynamics, Printf, Statistics, LinearAlgebra

const X12 = [0.075,0.01,1.0,0.5,3.7,2.0,2.5,12.0,0.0,8.0,15.0,5.0,0.5,0.3,log10(60.0)]
const BETZ_KW = 38.0
const LINDAMP_CANDIDATES = [0.5, 0.8, 0.9, 0.95, 0.98, 0.99, 0.995, 0.999]
const K = 60.0

function run_one(lin_damp, dt_factor, p, spoke)
    result = design_from_vector_v10(X12[1:14], PROFILE_ELLIPTICAL, p)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, K)
    V11_DT = KiteTurbineDynamics.V11_DT; dt = V11_DT / dt_factor

    function wf(pos, t) z=max(pos[3],1.0); [11.0*(z/p.h_ref)^(1/7),0.0,0.0] end

    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf)
    orig = sys.k_mppt_ref[]; sys.k_mppt_ref[] = -60.0
    ks = round(Int, 2/dt)
    run_canonical_sim!(u,sys,pc,wf,ks,dt; lin_damp=0.05, spoke=spoke)
    sys.k_mppt_ref[] = orig

    tn = round(Int, 60/dt); se = max(round(Int,0.1/dt),1); dn = round(Int,30/dt)
    N = sys.n_total; Nr = sys.n_ring
    Ps = Float64[]; FoSs = Float64[]

    function cb(uc,tc,s)
        s<dn && return; s%se!=0 && return
        try
            ef = capture_extended(uc, sys, pc, tc, wf, nothing; brake_engaged=sys.brake_engaged[])
            push!(Ps, ef.base.P_kw)
            air = Float64[v for v in ef.ring_fos[2:end] if isfinite(v)&&v>0]
            push!(FoSs, isempty(air) ? Inf : minimum(air))
        catch
        end
    end
    run_canonical_sim!(u,sys,pc,wf,tn,dt; lin_damp=lin_damp, spoke=spoke, callback=cb)

    n = length(Ps)
    n_betz = count(p->p>BETZ_KW, Ps)
    P_mean = isempty(Ps) ? 0.0 : mean(Ps)
    P_max = isempty(Ps) ? 0.0 : maximum(Ps)
    P_range = P_max - (isempty(Ps) ? 0.0 : minimum(Ps))
    fin_fos = Float64[isfinite(f) ? f : NaN for f in FoSs]
    FoS_min = count(isfinite,fin_fos)>0 ? minimum(skipmissing(fin_fos)) : Inf
    FoS_mean = count(isfinite,fin_fos)>0 ? mean(skipmissing(fin_fos)) : NaN
    n_fos_dip = count(f->isfinite(f)&&f<0.15, FoSs)

    dtlabel = dt_factor==1.0 ? "DT" : "DT/$(round(Int,dt_factor))"
    (; lin_damp, dtlabel, dt_factor, dt, n, n_betz, P_mean, P_max, P_range,
      FoS_min, FoS_mean, n_fos_dip)
end

function main()
    p = params_v5_50kw()
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)

    n_rates = length(LINDAMP_CANDIDATES)
    total_runs = n_rates * 2
    println("=== DT-Paired Damping-Rate Sweep ===\n")
    println("k=$K  rates=$n_rates × 2 dt levels = $total_runs runs\n")

    results = []
    t0 = time()
    ri = 0
    for ld in LINDAMP_CANDIDATES
        rate_hz = round(Int, -log(ld) / 4e-5)
        println("── lin_damp=$ld (rate≈$(rate_hz) Hz) ──")
        r1 = run_one(ld, 1.0, p, spoke); ri += 1
        el = time()-t0; eta = el/ri*(total_runs-ri)/60
        @printf("  %s  P=%.1f Pmax=%.0f FoS=%.3f betz=%d dip=%d  ETA:%.0fm\n",
            r1.dtlabel, r1.P_mean, r1.P_max, r1.FoS_min, r1.n_betz, r1.n_fos_dip, eta)
        r2 = run_one(ld, 2.0, p, spoke); ri += 1
        el = time()-t0; eta = el/ri*(total_runs-ri)/60
        @printf("  %s  P=%.1f Pmax=%.0f FoS=%.3f betz=%d dip=%d\n",
            r2.dtlabel, r2.P_mean, r2.P_max, r2.FoS_min, r2.n_betz, r2.n_fos_dip)

        # Convergence check
        alive = r1.P_max > 2.0  # non-trivial power
        pmax_ratio = r1.P_max / max(r2.P_max, 0.01)
        fmin_ratio = isfinite(r1.FoS_min) && isfinite(r2.FoS_min) ?
            r1.FoS_min / max(r2.FoS_min, 0.001) : 99.0
        converged = 0.85 <= pmax_ratio <= 1.15 && 0.85 <= fmin_ratio <= 1.15
        push!(results, (; ld, rate_hz, alive, converged,
            pmax_ratio, fmin_ratio, r1, r2))
        status = alive&&converged ? "VALID" : alive ? "ALIVE_DIVERGENT" : "DEAD"
        @printf("  → %s (alive=%d conv=%d P_ratio=%.2f F_ratio=%.2f)\n\n",
            status, alive, converged, pmax_ratio, fmin_ratio)
    end

    # Summary
    println("═"^60)
    println("SUMMARY")
    println("═"^60)
    valid = filter(r->r.alive&&r.converged, results)
    if !isempty(valid)
        println("\nValid rates (alive + DT-convergent):")
        for r in valid
            @printf("  lin_damp=%.3f rate=%d Hz  P=%.1f/%.0f kW  FoS=%.3f\n",
                r.ld, r.rate_hz, r.r1.P_mean, r.r1.P_max, r.r1.FoS_min)
        end
        println("\n→ Damping rate can be calibrated. These rates need hardware anchors.")
    else
        println("\nNO valid rates found — no rate is both alive and dt-convergent.")
        println("→ This IS a design finding from a clean instrument.")
        println("→ The 12-gon cannot simultaneously produce power AND")
        println("   maintain integrator convergence at any damping rate.")
    end

    out = joinpath(@__DIR__,"results","recampaign","sweep_damp_rate_dtpaired.csv")
    open(out,"w") do io
        println(io,"lin_damp,rate_hz,dt_label,dt,n_samples,P_mean,P_max,P_range,FoS_min,FoS_mean,n_betz,n_fos_dips,alive,converged,pmax_ratio,fmin_ratio")
        for r in results
            for (rlab, rr) in [("DT",r.r1),("DT/2",r.r2)]
                println(io,"$(r.ld),$(r.rate_hz),$rlab,$(rr.dt),$(rr.n),$(rr.P_mean),$(rr.P_max),$(rr.P_range),$(rr.FoS_min),$(rr.FoS_mean),$(rr.n_betz),$(rr.n_fos_dip),$(r.alive),$(r.converged),$(r.pmax_ratio),$(r.fmin_ratio)")
            end
        end
    end
    println("\nSaved: $out")
end

main()
