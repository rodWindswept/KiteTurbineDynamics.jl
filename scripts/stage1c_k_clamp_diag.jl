#!/usr/bin/env julia
# Stage 1c: k=1000 clamp diagnosis — trace P_gen, ω, FoS through window
using KiteTurbineDynamics, Printf, Statistics, LinearAlgebra

const TARGET = "0d61db093a2c"
const BETZ = 38.0

function trace_window(k_mppt)
    rows = eachline(joinpath(@__DIR__, "results", "recampaign", "anchors.csv"))
    x = nothing
    for (i, line) in enumerate(rows)
        i == 1 && continue
        cols = split(line, ',')
        cols[1] == TARGET || continue
        x = [parse(Float64, s) for s in cols[4:18]]
        break
    end
    x === nothing && error("not found")
    x[15] = log10(k_mppt)

    p = KiteTurbineDynamics.params_v5_50kw()
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)
    result = KiteTurbineDynamics.design_from_vector_v10(x[1:14], KiteTurbineDynamics.PROFILE_ELLIPTICAL, p; power_W=50000.0, v_rated=11.0)
    if result.n_active == 0
        return nothing
    end
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, k_mppt)
    wf(pos,t) = (z=max(pos[3],1.0);[11*(z/p.h_ref)^(1/7),0,0])
    u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, pc; wind_fn=wf)
    N = sys.n_total; Nr = sys.n_ring
    ω_eq_guess = 60.0
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        pos = u[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]; tang ./= norm(tang)
            u[(6N+Nr+ri)] = ω_eq_guess
            vx_idx = 3N + 3*(gid-1) + 1
            u[vx_idx:(vx_idx+2)] .= (ω_eq_guess * r) .* tang
        end
    end
    total_n = round(Int, 40.0 / KiteTurbineDynamics.V11_DT)
    se = round(Int, 1.0 / KiteTurbineDynamics.V11_DT)
    dn = round(Int, 10.0 / KiteTurbineDynamics.V11_DT)

    Pgens = Float64[]; Omegas = Float64[]; FoSs = Float64[]
    function cb(uc, tc, s)
        s < dn && return; s % se != 0 && return
        ω_gnd = uc[6N+Nr+1]
        push!(Omegas, ω_gnd)
        push!(Pgens, k_mppt * ω_gnd^2 / 1000.0)
        ef = KiteTurbineDynamics.capture_extended(uc, sys, pc, tc, wf, nothing; brake_engaged=false)
        air = Float64[v for v in ef.ring_fos[2:end] if isfinite(v)&&v>0]
        push!(FoSs, isempty(air) ? Inf : minimum(air))
    end
    try
        KiteTurbineDynamics.run_canonical_sim!(u, sys, pc, wf, total_n, KiteTurbineDynamics.V11_DT;
            lin_damp=0.05, spoke=spoke, callback=cb)
    catch e
        @warn "sim failed" k=k_mppt exception=e
        return nothing
    end

    n = length(Pgens)
    n < 3 && return nothing
    Pg_m = mean(Pgens); ω_m = mean(Omegas)
    F_m = count(isfinite,FoSs)>0 ? minimum(FoSs[isfinite.(FoSs)]) : Inf
    Pg_r = maximum(Pgens) - minimum(Pgens)
    # P_aero = total power from capture_extended at mid-point
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 40.0, wf, nothing; brake_engaged=false)
    Paero = max(ef.base.P_kw - Pgens[end], 0.0)

    mid = n ÷ 2
    P1 = mean(Pgens[1:mid]); P2 = mean(Pgens[mid+1:end])
    ω1 = mean(Omegas[1:mid]); ω2 = mean(Omegas[mid+1:end])
    stationary = n >= 8 && abs(P1-P2)/max(P1,0.01) < 0.10

    (; k_mppt, Pg_m, Paero, ω_m, F_m, Pg_r, stationary, P1, P2, ω1, ω2)
end

println("=== Stage 1c: k=1000 clamp diagnosis on $TARGET ===\n")
for k in [600.0, 800.0, 1000.0]
    r = trace_window(k)
    r === nothing && continue
    @printf("k=%.0f  P_gen=%.1f kW  P_aero=%.1f kW  ω=%.0f rpm  FoS=%.3f  P_range=%.0f  st=%d\n",
        r.k_mppt, r.Pg_m, r.Paero, r.ω_m*60/(2π), r.F_m, r.Pg_r, r.stationary)
    @printf("  half1: P=%.1f ω=%.0f | half2: P=%.1f ω=%.0f  (drift=%.0f%%)\n\n",
        r.P1, r.ω1*60/(2π), r.P2, r.ω2*60/(2π), abs(r.P1-r.P2)/max(r.P1,0.01)*100)
end
