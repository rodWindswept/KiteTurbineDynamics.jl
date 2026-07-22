#!/usr/bin/env julia
# scripts/diag_lin_damp_refinement.jl
# Decisive experiment: DT-refinement at k=60 with lin_damp=0.
# If divergence vanishes → damping operator is the culprit (dt-unscaled projection).
# If divergence persists → something else (k·ω² chain or other).

using KiteTurbineDynamics, Printf, Statistics, LinearAlgebra

const X12 = [
    0.075, 0.01, 1.0, 0.5, 3.7, 2.0, 2.5, 12.0, 0.0,
    8.0, 15.0, 5.0, 0.5, 0.3, log10(60.0),
]

const BETZ_KW = 0.5 * 1.225 * π * 5.0^2 * 11.0^3 * (16/27) / 1000

function run_at_dt(label, dt_factor, p, spoke, k)
    result = design_from_vector_v10(X12[1:14], PROFILE_ELLIPTICAL, p)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, k)
    V11_DT = KiteTurbineDynamics.V11_DT
    dt_use = V11_DT / dt_factor

    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [11.0 * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf)
    orig_k = sys.k_mppt_ref[]
    sys.k_mppt_ref[] = -60.0
    kick_steps = round(Int, 2.0 / dt_use)
    run_canonical_sim!(u, sys, pc, wf, kick_steps, dt_use;
        lift_device=nothing, lin_damp=0.0, spoke=spoke)  # ← ZERO damping
    sys.k_mppt_ref[] = orig_k

    total_s = 30.0 + 30.0
    total_n = round(Int, total_s / dt_use)
    sample_every = max(round(Int, 0.1 / dt_use), 1)
    discard_n = round(Int, 30.0 / dt_use)

    Ps = Float64[]; FoSs = Float64[]
    function cb(uc, tc, s)
        s < discard_n && return
        s % sample_every != 0 && return
        try
            ef = capture_extended(uc, sys, pc, tc, wf, nothing;
                brake_engaged=sys.brake_engaged[])
            push!(Ps, ef.base.P_kw)
            air = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]
                (!isnan(v) && !isinf(v) && v > 0) && push!(air, v)
            end
            push!(FoSs, isempty(air) ? Inf : minimum(air))
        catch
        end
    end

    try
        run_canonical_sim!(u, sys, pc, wf, total_n, dt_use;
            lift_device=nothing, lin_damp=0.0, spoke=spoke, callback=cb)  # ← ZERO damping
    catch e
        @warn "$label failed" exception=e
    end

    n = length(Ps)
    n_betz = count(p -> p > BETZ_KW, Ps)
    n_fos = count(f -> isfinite(f) && f < 0.15, FoSs)
    P_mean = isempty(Ps) ? 0.0 : mean(Ps)
    P_max = isempty(Ps) ? 0.0 : maximum(Ps)
    fin_fos = Float64[isfinite(f) ? f : NaN for f in FoSs]
    FoS_min = count(isfinite, fin_fos) > 0 ? minimum(skipmissing(fin_fos)) : Inf

    return (; label, dt_factor, dt=dt_use, n, n_betz, n_fos, P_mean, P_max, FoS_min)
end

function main()
    p = params_v5_50kw()
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)
    k = 60.0

    println("=== lin_damp=0 DT-refinement: k=60 ===\n")
    println("Hypothesis: orbital_damp_rope_velocities! applies per-step projection")
    println("without dt scaling. lin_damp=0 removes it → divergence should vanish.\n")
    println("Betz ceiling: $(round(Int, BETZ_KW)) kW\n")

    results = []
    for df in [1.0, 2.0, 4.0]
        label = df == 1.0 ? "DT" : "DT/$(round(Int,df))"
        r = run_at_dt(label, df, p, spoke, k)
        push!(results, r)
        @printf("  %-6s dt=%.1e  n=%d  P_mean=%.1f  P_max=%.0f  FoS_min=%.3f  betz=%d  dip=%d\n",
            r.label, r.dt, r.n, r.P_mean, r.P_max, r.FoS_min, r.n_betz, r.n_fos)
    end

    # Compare with previous (lin_damp=0.05) results
    println("\n── Comparison ──")
    println("  lin_damp=0.05:  DT: P_max=6, betz=0  |  DT/2: P_max=2216, betz=66  |  DT/4: P_max=5224, betz=60 ← DIVERGENT")
    println("  lin_damp=0.00:  DT: P_max=$(round(Int,results[1].P_max)), betz=$(results[1].n_betz)  |  DT/2: P_max=$(round(Int,results[2].P_max)), betz=$(results[2].n_betz)  |  DT/4: P_max=$(round(Int,results[3].P_max)), betz=$(results[3].n_betz)")

    r1, r2, r3 = results
    ratio12 = r2.P_max / max(r1.P_max, 1.0)
    ratio23 = r3.P_max / max(r2.P_max, 1.0)

    if r3.n_betz <= r1.n_betz * 1.5 && ratio23 < 1.5
        println("\n  → CONVERGED: divergence vanished.  Damping operator IS the culprit.")
        println("  → Fix: dt-scale the retention in orbital_damp_rope_velocities! (v_osc * (1-rate·dt))")
    else
        println("\n  → STILL DIVERGENT: something beyond damping.  Both k·ω² chain AND damping.")
    end

    out = joinpath(@__DIR__, "results", "recampaign", "dt_refine_lin_damp0.csv")
    open(out, "w") do io
        println(io, "label,dt_factor,dt,n_samples,n_betz,n_fos_dips,P_mean,P_max,FoS_min")
        for r in results
            println(io, "$(r.label),$(r.dt_factor),$(r.dt),$(r.n),$(r.n_betz),$(r.n_fos),$(r.P_mean),$(r.P_max),$(r.FoS_min)")
        end
    end
    println("  Saved: $out")
end

main()
