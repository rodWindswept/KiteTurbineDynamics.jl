#!/usr/bin/env julia
# scripts/sweep_k_stability.jl
# 7-point k-sweep for 12-gon using FULL protocol (settle → kickstart → window).
# k = [20, 30, 40, 50, 60, 70, 80], 60s window each.

using KiteTurbineDynamics, Printf, Statistics, Dates, LinearAlgebra

const OUT_DIR = joinpath(@__DIR__, "results", "recampaign")
const X12 = [
    0.075, 0.01, 1.0, 0.5, 3.7, 2.0, 2.5, 12.0, 0.0,
    8.0, 15.0, 5.0, 0.5, 0.3, 0.0,
]

const K_VALUES = [20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0]
const WINDOW_S  = 60.0

function evaluate_k(k::Float64, p, spoke)
    x = copy(X12)
    x[15] = log10(k)

    result = design_from_vector_v10(x[1:14], PROFILE_ELLIPTICAL, p)
    result.n_active == 0 && return (; k, P_mean=0.0, P_range=0.0, FoS_min=Inf,
        FoS_mean=NaN, ω_mean=0.0, drift=false, status="no_rotors")

    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, k)
    V11_DT = KiteTurbineDynamics.V11_DT

    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [11.0 * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    # Settle to operational state
    u = nothing
    try
        u = settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf)
    catch e
        return (; k, P_mean=0.0, P_range=0.0, FoS_min=Inf,
            FoS_mean=NaN, ω_mean=0.0, drift=false, status="settle_fail")
    end
    u === nothing && return (; k, P_mean=0.0, P_range=0.0, FoS_min=Inf,
        FoS_mean=NaN, ω_mean=0.0, drift=false, status="settle_nil")

    # Kickstart
    orig_k = sys.k_mppt_ref[]
    try
        sys.k_mppt_ref[] = -60.0
        kick_steps = round(Int, 2.0 / V11_DT)
        run_canonical_sim!(u, sys, pc, wf, kick_steps, V11_DT;
            lift_device=nothing, lin_damp=0.05, spoke=spoke)
    catch e
        sys.k_mppt_ref[] = orig_k
        return (; k, P_mean=0.0, P_range=0.0, FoS_min=Inf,
            FoS_mean=NaN, ω_mean=0.0, drift=false, status="kick_fail")
    end
    sys.k_mppt_ref[] = orig_k

    # Window
    total_s = 30.0 + WINDOW_S
    total_n = round(Int, total_s / V11_DT)
    sample_every = max(round(Int, 1.0 / V11_DT), 1)
    discard_n = round(Int, 30.0 / V11_DT)

    Ps = Float64[]; FoSs = Float64[]; ωs = Float64[]
    N = sys.n_total; Nr = sys.n_ring

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
            push!(ωs, abs(uc[6*N + Nr + 1]))
        catch
        end
    end

    try
        run_canonical_sim!(u, sys, pc, wf, total_n, V11_DT;
            lift_device=nothing, lin_damp=0.05, spoke=spoke, callback=cb)
    catch e
        @warn "k=$k window failed" exception=e
        if isempty(Ps)
            return (; k, P_mean=0.0, P_range=0.0, FoS_min=Inf,
                FoS_mean=NaN, ω_mean=0.0, drift=false, status="window_fail")
        end
    end

    n = length(Ps)
    n < 2 && return (; k, P_mean=isempty(Ps) ? 0.0 : Ps[1], P_range=0.0,
        FoS_min=isempty(FoSs) ? Inf : FoSs[1], FoS_mean=NaN, ω_mean=0.0,
        drift=false, status="too_short")

    P_mean = mean(Ps)
    P_range = maximum(Ps) - minimum(Ps)
    drift_flag = P_mean > 0.01 ? abs(Ps[end] - Ps[1]) / P_mean > 0.15 : false

    fin_fos = Float64[isfinite(f) ? f : NaN for f in FoSs]
    n_fos = count(isfinite, fin_fos)
    FoS_min = n_fos > 0 ? minimum(skipmissing(fin_fos)) : Inf
    FoS_mean_val = n_fos > 0 ? mean(skipmissing(fin_fos)) : NaN
    ω_mean_val = mean(ωs)

    return (; k, P_mean, P_range, FoS_min, FoS_mean=FoS_mean_val,
        ω_mean=ω_mean_val, drift=drift_flag, status="ok")
end

function main()
    mkpath(OUT_DIR)
    p = params_v5_50kw()
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)

    println("=== K-Sweep: 12-gon FULL protocol, $(length(K_VALUES)) points ===\n")
    println("k, P_mean(kW), P_range, FoS_min, FoS_mean, ω(rad/s), drift, status")

    results = []
    t0 = time()
    for (i, k) in enumerate(K_VALUES)
        r = evaluate_k(k, p, spoke)
        push!(results, r)
        elapsed = time() - t0
        eta = elapsed / i * (length(K_VALUES) - i) / 60
        @printf("  [%d/%d] k=%.0f  P=%.1f kW  range=%.1f  FoS=%.3f  ω=%.1f  drift=%d  ETA: %.0f min\n",
            i, length(K_VALUES), k, r.P_mean, r.P_range, r.FoS_min, r.ω_mean, r.drift, eta)
    end

    fname = joinpath(OUT_DIR, "k_sweep_full_$(Dates.format(now(),"yyyymmdd_HHMM")).csv")
    open(fname, "w") do io
        println(io, "k,P_mean_kW,P_range_kW,FoS_min,FoS_mean,omega_rad_s,drift,status")
        for r in results
            println(io, "$(r.k),$(r.P_mean),$(r.P_range),$(r.FoS_min),$(r.FoS_mean),$(r.ω_mean),$(r.drift),$(r.status)")
        end
    end

    println("\n── Best by fitness (-P / fos_penalty) ──")
    by_score = sort(results; by=r -> begin
        fp = r.FoS_min < 1.5 ? 1.5 / max(r.FoS_min, 0.01) : 1.0
        -r.P_mean / fp
    end)
    for r in by_score[1:min(3, end)]
        fp = r.FoS_min < 1.5 ? 1.5 / max(r.FoS_min, 0.01) : 1.0
        @printf("  k=%.0f  P=%.1f kW  FoS=%.3f  ω=%.1f  range=%.1f  settled=%d  score=%.1f\n",
            r.k, r.P_mean, r.FoS_min, r.ω_mean, r.P_range, !r.drift, -r.P_mean/fp)
    end

    println("\n  Saved: $fname")
end

main()
