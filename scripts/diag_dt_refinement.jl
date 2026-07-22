#!/usr/bin/env julia
# scripts/diag_dt_refinement.jl
# DT-refinement test: 12-gon at k=60, FULL protocol, 10 Hz.
# Run at DT, DT/2, DT/4.  If super-Betz spikes and FoS dips shrink
# with dt → 100% numerical.  If they persist → genuine dynamics.

using KiteTurbineDynamics, Printf, Statistics, LinearAlgebra

const X12 = [
    0.075, 0.01, 1.0, 0.5, 3.7, 2.0, 2.5, 12.0, 0.0,
    8.0, 15.0, 5.0, 0.5, 0.3, log10(60.0),
]

const BETZ_KW = 0.5 * 1.225 * π * 5.0^2 * 11.0^3 * (16/27) / 1000
const WINDOW_S = 30.0
const DISCARD_S = 30.0

function run_at_dt(label, dt_factor, p, spoke, k)
    result = design_from_vector_v10(X12[1:14], PROFILE_ELLIPTICAL, p)
    result.n_active == 0 && error("No rotors")
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
        lift_device=nothing, lin_damp=0.05, spoke=spoke)
    sys.k_mppt_ref[] = orig_k

    total_s = DISCARD_S + WINDOW_S
    total_n = round(Int, total_s / dt_use)
    sample_every = max(round(Int, 0.1 / dt_use), 1)
    discard_n = round(Int, DISCARD_S / dt_use)

    N = sys.n_total; Nr = sys.n_ring
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
            lift_device=nothing, lin_damp=0.05, spoke=spoke, callback=cb)
    catch e
        @warn "$label failed" exception=e
    end

    n = length(Ps)
    n_betz = count(p -> p > BETZ_KW, Ps)
    n_fos = count(f -> isfinite(f) && f < 0.15, FoSs)
    P_mean = isempty(Ps) ? 0.0 : mean(Ps)
    P_max = isempty(Ps) ? 0.0 : maximum(Ps)
    FoS_min = count(f -> isfinite(f), FoSs) > 0 ?
        minimum(Float64[isfinite(f) ? f : NaN for f in FoSs]) : Inf

    return (; label, dt_factor, dt=dt_use, n, n_betz, n_fos, P_mean, P_max, FoS_min)
end

function main()
    p = params_v5_50kw()
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)
    k = 60.0

    println("=== DT-refinement: k=60, DT, DT/2, DT/4 ===\n")
    println("Betz ceiling: $(round(Int, BETZ_KW)) kW\n")

    results = []
    for df in [1.0, 2.0, 4.0]
        label = df == 1.0 ? "DT" : "DT/$(round(Int,df))"
        r = run_at_dt(label, df, p, spoke, k)
        push!(results, r)
        @printf("  %-6s dt=%.1e  n=%d  P_mean=%.1f  P_max=%.0f  FoS_min=%.3f  betz=%d  dip=%d\n",
            r.label, r.dt, r.n, r.P_mean, r.P_max, r.FoS_min, r.n_betz, r.n_fos)
    end

    println("\n── Convergence ──")
    if length(results) >= 2
        r1, r2, r3 = results[1], results[2], results[3]
        @printf("  Super-Betz:  %d → %d → %d  (ratio: %.2f → %.2f)\n",
            r1.n_betz, r2.n_betz, r3.n_betz,
            r2.n_betz/max(r1.n_betz,1), r3.n_betz/max(r2.n_betz,1))
        @printf("  FoS dips:    %d → %d → %d  (ratio: %.2f → %.2f)\n",
            r1.n_fos, r2.n_fos, r3.n_fos,
            r2.n_fos/max(r1.n_fos,1), r3.n_fos/max(r2.n_fos,1))
        @printf("  P_max:       %.0f → %.0f → %.0f kW  (ratio: %.2f → %.2f)\n",
            r1.P_max, r2.P_max, r3.P_max,
            r2.P_max/max(r1.P_max,1), r3.P_max/max(r2.P_max,1))

        if r3.n_betz < r1.n_betz / 2 && r3.n_fos < r1.n_fos / 2
            println("\n  → CONVERGING: spikes and dips shrink with dt — 100% numerical.")
        elseif r3.n_betz ≈ r1.n_betz && r3.n_fos ≈ r1.n_fos
            println("\n  → PERSISTENT: spikes and dips unchanged — genuine dynamics.")
        else
            println("\n  → MIXED: partial convergence — some numerics, some dynamics.")
        end
    end

    # Save
    out = joinpath(@__DIR__, "results", "recampaign", "dt_refine_k60.csv")
    open(out, "w") do io
        println(io, "label,dt_factor,dt,n_samples,n_betz,n_fos_dips,P_mean,P_max,FoS_min")
        for r in results
            println(io, "$(r.label),$(r.dt_factor),$(r.dt),$(r.n),$(r.n_betz),$(r.n_fos),$(r.P_mean),$(r.P_max),$(r.FoS_min)")
        end
    end
    println("\n  Saved: $out")
end

main()
