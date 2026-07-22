#!/usr/bin/env julia
# scripts/diag_integrator_blowup.jl
# Diagnose forward-Euler blowup on k·ω² MPPT torque term.
# 12-gon, k=60 (where FoS dipped hardest in sweep), FULL protocol, 10 Hz.
# Binary questions:
#  1. Are FoS dips simultaneous with P super-Betz spikes?
#  2. Does P_aero ever exceed the Σ-annulus Betz ceiling?

using KiteTurbineDynamics, Printf, Statistics, LinearAlgebra

const X12 = [
    0.075, 0.01, 1.0, 0.5, 3.7, 2.0, 2.5, 12.0, 0.0,
    8.0, 15.0, 5.0, 0.5, 0.3, log10(60.0),
]

const BETZ_CEILING_KW = 0.5 * 1.225 * π * 5.0^2 * 11.0^3 * (16/27) / 1000

function main()
    p = params_v5_50kw()
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)
    k = 60.0

    result = design_from_vector_v10(X12[1:14], PROFILE_ELLIPTICAL, p)
    result.n_active == 0 && error("No rotors")
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, k)
    V11_DT = KiteTurbineDynamics.V11_DT

    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [11.0 * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf)
    orig_k = sys.k_mppt_ref[]
    sys.k_mppt_ref[] = -60.0
    kick_steps = round(Int, 2.0 / V11_DT)
    run_canonical_sim!(u, sys, pc, wf, kick_steps, V11_DT;
        lift_device=nothing, lin_damp=0.05, spoke=spoke)
    sys.k_mppt_ref[] = orig_k

    total_s = 30.0 + 45.0
    total_n = round(Int, total_s / V11_DT)
    sample_every = max(round(Int, 0.1 / V11_DT), 1)  # 10 Hz
    discard_n = round(Int, 30.0 / V11_DT)

    N = sys.n_total; Nr = sys.n_ring
    ts = Float64[]; Ps = Float64[]; Pa = Float64[]; FoSs = Float64[]; ωs = Float64[]

    function cb(uc, tc, s)
        s < discard_n && return
        s % sample_every != 0 && return
        try
            ef = capture_extended(uc, sys, pc, tc, wf, nothing;
                brake_engaged=sys.brake_engaged[])
            push!(ts, tc); push!(Ps, ef.base.P_kw); push!(Pa, ef.base.P_aero_kw)
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

    println("12-gon @ k=60, 10 Hz — diagnosing integrator blowup...")
    try
        run_canonical_sim!(u, sys, pc, wf, total_n, V11_DT;
            lift_device=nothing, lin_damp=0.05, spoke=spoke, callback=cb)
    catch e
        @warn "Sim terminated" exception=e
    end

    n = length(ts)
    println("\n── k=60 diagnostic ($n samples) ──\n")
    @printf("  Betz ceiling:       %.0f kW\n", BETZ_CEILING_KW)

    super_betz = findall(p -> p > BETZ_CEILING_KW, Ps)
    @printf("  Super-Betz samples: %d / %d (%.1f%%)\n", length(super_betz), n,
        100*length(super_betz)/max(n,1))

    fos_low = findall(f -> isfinite(f) && f < 0.15, FoSs)
    @printf("  FoS < 0.15 samples: %d / %d (%.1f%%)\n", length(fos_low), n,
        100*length(fos_low)/max(n,1))

    # Coincidence
    if !isempty(super_betz) && !isempty(fos_low)
        both = intersect(Set(super_betz), Set(fos_low))
        @printf("  Coincident (P>Betz & FoS<0.15): %d / %d super-Betz\n",
            length(both), length(super_betz))
        if !isempty(both)
            println("  → CONFIRMED: FoS dips coincide with integrator blowup.")
        end
    elseif isempty(super_betz) && isempty(fos_low)
        println("  → CLEAN: No spikes, no dips. Integrator stable at this k.")
    elseif isempty(fos_low) && !isempty(super_betz)
        println("  → SPIKES WITHOUT FoS DIPS: spikes too small to stress rings.")
    end

    # Worst spike
    if !isempty(super_betz)
        idx = argmax(Ps)
        println("\n  Worst spike: t=$(round(ts[idx],digits=1))s  P=$(round(Int,Ps[idx]))kW  FoS=$(isfinite(FoSs[idx]) ? round(FoSs[idx],digits=3) : "Inf")  ω=$(round(ωs[idx],digits=1))rad/s")
    end

    # Overall stats
    fin_fos = Float64[isfinite(f) ? f : NaN for f in FoSs]
    n_valid = count(isfinite, fin_fos)
    println("\n  P_mean= $(round(mean(Ps),digits=1))kW  range= $(round(maximum(Ps)-minimum(Ps),digits=1))kW")
    if n_valid > 0
        println("  FoS_mean=$(round(mean(skipmissing(fin_fos)),digits=3))  FoS_min=$(round(minimum(skipmissing(fin_fos)),digits=3))")
    end
    println("  ω_mean= $(round(mean(ωs),digits=2))rad/s")

    # Save
    out = joinpath(@__DIR__, "results", "recampaign", "diag_blowup_k60.csv")
    open(out, "w") do io
        println(io, "t,P_kW,Paero_kW,FoS,omega")
        for (t,P,Pa,fos,ω) in zip(ts, Ps, Pa, FoSs, ωs)
            println(io, "$t,$P,$Pa,$fos,$ω")
        end
    end
    println("  Saved: $out")
end

main()
