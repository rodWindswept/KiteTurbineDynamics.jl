#!/usr/bin/env julia
# scripts/long_trace_v11.jl
# Compare warm-start vs full protocol on 12-gon, same design, same k.
# Uses the ACTUAL objective_v11 and objective_v11_warmstart functions
# to guarantee correct initialization.  Wraps callbacks to log FoS+P+ω at 1 Hz.

using KiteTurbineDynamics, Printf, Statistics, Dates, LinearAlgebra

const OUT_DIR = joinpath(@__DIR__, "results", "recampaign")
const X12 = [
    0.075, 0.01, 1.0, 0.5, 3.7, 2.0, 2.5, 12.0, 0.0,
    8.0, 15.0, 5.0, 0.5, 0.3, log10(100.0),
]

const RUN_S     = 120.0
const WINDOW_S  = 30
const EPSILON   = 0.10

# ── Stationarity ────────────────────────────────────────────────────────────

function is_stationary(data::Vector{Float64}, window_W::Int, ε::Float64)
    n = length(data)
    n < 2 * window_W && return false
    w1 = mean(data[(n - 2*window_W + 1):(n - window_W)])
    w2 = mean(data[(n - window_W + 1):n])
    diff = abs(w1 - w2) / max(abs(w1), abs(w2), 0.01)
    return diff < ε
end

# ── Report ──────────────────────────────────────────────────────────────────

function report(name, ts::Vector, Ps::Vector, FoSs::Vector, ωs::Vector, elapsed)
    n = length(ts)
    n == 0 && (println("  No data"); return nothing)

    @printf("\n── %s ──\n", name)
    @printf("  Duration:  %.0f s (%d samples, %.0f wall-s)\n", ts[end], n, elapsed)

    # Stationarity (last 60s of FoS if available)
    W = WINDOW_S
    valid_FoS = Float64[isfinite(f) ? f : NaN for f in FoSs]
    all_conv = [is_stationary(Ps, W, EPSILON),
                count(isfinite, valid_FoS) > 2*W ? is_stationary(Float64[isfinite(f) ? f : 0.0 for f in FoSs], W, EPSILON) : false,
                is_stationary(ωs, W, EPSILON)]
    @printf("  Stationary: P=%-5s  FoS=%-5s  ω=%-5s\n",
            all_conv[1] ? "yes" : "NO", all_conv[2] ? "yes" : "NO", all_conv[3] ? "yes" : "NO")

    win_start = max(1, n - W)
    win_P, win_FoS, win_ω = Ps[win_start:end], FoSs[win_start:end], ωs[win_start:end]

    @printf("  Final window (%.0f–%.0f s):\n", ts[win_start], ts[end])
    @printf("    P_mean:   %8.1f kW   (±%.1f)\n", mean(win_P), std(win_P))
    @printf("    P_min/max:%8.1f / %.1f kW\n", minimum(win_P), maximum(win_P))

    n_fos = count(isfinite, win_FoS)
    if n_fos > 0
        fin = Float64[isfinite(f) ? f : NaN for f in win_FoS]
        @printf("    FoS_mean: %8.3f   (±%.3f)  (n=%d)\n", mean(skipmissing(fin)), std(skipmissing(fin)), n_fos)
        @printf("    FoS_min:  %8.3f\n", minimum(skipmissing(fin)))
    else
        @printf("    FoS:      all Inf/NaN\n")
    end
    @printf("    ω_mean:   %8.2f rad/s\n", mean(win_ω))

    P_betz = 0.5 * 1.225 * π * 5.0^2 * 11.0^3 * (16/27) / 1000  # ~38 kW
    @printf("    Betz ceiling: %.0f kW\n", P_betz)
    @printf("    Above Betz:   %s\n", mean(win_P) > P_betz * 1.1 ? "YES ⚠" : "no")

    fos_min = n_fos > 0 ? minimum(skipmissing(Float64[isfinite(f) ? f : NaN for f in win_FoS])) : Inf
    return (; P_mean=mean(win_P), FoS_min=fos_min, ω_mean=mean(win_ω), stationary=all(all_conv))
end

# ══════════════════════════════════════════════════════════════════════════════
# Wrappers that call the real objective functions with logging callbacks
# ══════════════════════════════════════════════════════════════════════════════

function trace_full_protocol(x, p, spoke)
    # Build everything the same way objective_v11 does, but with logging callback
    result = design_from_vector_v10(x[1:14], PROFILE_ELLIPTICAL, p)
    result.n_active == 0 && error("No active rotors")
    k_mppt = clamp(10.0^x[15], 0.01, 1000.0)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, k_mppt)

    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [11.0 * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    # Settle (same as objective_v11)
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf)

    # Kickstart (same as objective_v11)
    orig_k = sys.k_mppt_ref[]
    try
        sys.k_mppt_ref[] = -60.0
        kick_steps = round(Int, 2.0 / KiteTurbineDynamics.V11_DT)
        run_canonical_sim!(u, sys, pc, wf, kick_steps, KiteTurbineDynamics.V11_DT;
            lift_device=nothing, lin_damp=0.05, spoke=spoke)
    catch e
        @warn "Kickstart failed" exception=e
    end
    sys.k_mppt_ref[] = orig_k

    # Run window with logging callback
    V11_DT = KiteTurbineDynamics.V11_DT
    total_s = 30.0 + RUN_S  # DISCARD_S + window
    total_n = round(Int, total_s / V11_DT)
    sample_every = max(round(Int, 1.0 / V11_DT), 1)
    discard_n = round(Int, 30.0 / V11_DT)

    ts   = Float64[]; Ps = Float64[]; FoSs = Float64[]; ωs = Float64[]
    N = sys.n_total; Nr = sys.n_ring

    function cb(uc, tc, s)
        s < discard_n && return
        s % sample_every != 0 && return
        try
            ef = capture_extended(uc, sys, pc, tc, wf, nothing;
                brake_engaged=sys.brake_engaged[])
            push!(ts, tc)
            push!(Ps, ef.base.P_kw)
            air = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]
                (!isnan(v) && !isinf(v) && v > 0) && push!(air, v)
            end
            push!(FoSs, isempty(air) ? Inf : minimum(air))
            push!(ωs, abs(uc[6*N + Nr + 1]))
        catch e
            @warn "callback fail at t=$tc" exception=e
        end
    end

    t0 = time()
    try
        run_canonical_sim!(u, sys, pc, wf, total_n, V11_DT;
            lift_device=nothing, lin_damp=0.05, spoke=spoke, callback=cb)
    catch e
        @warn "Full protocol error" exception=e
    end
    elapsed = time() - t0
    @printf("FULL: %d samples in %.0f s\n", length(ts), elapsed)
    return (; ts, Ps, FoSs, ωs, elapsed)
end

function trace_warmstart_protocol(x, p, spoke)
    result = design_from_vector_v10(x[1:14], PROFILE_ELLIPTICAL, p)
    result.n_active == 0 && error("No active rotors")
    (; design, rotors, n_rings, zs) = result
    n_lines = design.n_lines
    k_mppt = clamp(10.0^x[15], 0.01, 1000.0)
    elev_angle = π/6

    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, k_mppt)

    # Equilibrium (same as objective_v11_warmstart)
    expansion_params = KiteTurbineDynamics.ExpansionRotorParams[]
    for rotor in rotors
        er = KiteTurbineDynamics.ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius,
            rotor.blade_chord, KiteTurbineDynamics.EXP_CL_DESIGN,
            KiteTurbineDynamics.EXP_CD0_DESIGN, KiteTurbineDynamics.EXP_K_INDUCED,
            rotor.bank_angle_deg,
            KiteTurbineDynamics.expansion_blade_mass(rotor.blade_tip_radius, rotor.blade_scale),
            rotor.ring_idx, 1.0,
        )
        push!(expansion_params, er)
    end
    _, radii, _ = ring_spacing_v4(design.r_hub, design.r_bottom,
        design.tether_length, design.target_Lr; density_profile=design.density_profile)
    λ_eff = rotors[1].blade_scale
    k_eff = p.k_mppt * λ_eff^2
    p_scaled = override_params(p; k_mppt=k_eff)
    ω_eq, r_ref = KiteTurbineDynamics.solve_equilibrium_self_consistent(
        design, expansion_params, p_scaled, n_lines, radii, zs;
        P_per_rotor=50000.0 / max(result.n_active, 1), v_wind=11.0, elev_rad=elev_angle)

    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [11.0 * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    # Settle + init (WITH orbital-velocity fix)
    u = settle_to_equilibrium(sys, u0, pc; wind_fn=wf)
    N = sys.n_total; Nr = sys.n_ring
    u[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        pos = u[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]; tang ./= norm(tang)
            vx_idx = 3*N + 3*(gid-1) + 1
            u[vx_idx:(vx_idx+2)] .= (ω_eq * r) .* tang
        end
    end
    sys.k_mppt_ref[] = k_mppt

    # Run with logging
    V11_DT = KiteTurbineDynamics.V11_DT
    total_s = 10.0 + RUN_S
    total_n = round(Int, total_s / V11_DT)
    sample_every = max(round(Int, 1.0 / V11_DT), 1)

    ts = Float64[]; Ps = Float64[]; FoSs = Float64[]; ωs = Float64[]

    function cb(uc, tc, s)
        s % sample_every != 0 && return
        try
            ef = capture_extended(uc, sys, pc, tc, wf, nothing;
                brake_engaged=sys.brake_engaged[])
            push!(ts, tc)
            push!(Ps, ef.base.P_kw)
            air = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]
                (!isnan(v) && !isinf(v) && v > 0) && push!(air, v)
            end
            push!(FoSs, isempty(air) ? Inf : minimum(air))
            push!(ωs, abs(uc[6*N + Nr + 1]))
        catch e
            @warn "callback fail at t=$tc" exception=e
        end
    end

    t0 = time()
    try
        run_canonical_sim!(u, sys, pc, wf, total_n, V11_DT;
            lift_device=nothing, lin_damp=0.05, spoke=spoke, callback=cb)
    catch e
        @warn "Warm-start error" exception=e
    end
    elapsed = time() - t0
    @printf("WARM: %d samples in %.0f s\n", length(ts), elapsed)
    return (; ts, Ps, FoSs, ωs, elapsed)
end

# ══════════════════════════════════════════════════════════════════════════════

function main()
    mkpath(OUT_DIR)
    p = params_v5_50kw()
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)

    println("=== FULL protocol (settle → kickstart → $RUN_S s window) ===")
    tr_full = trace_full_protocol(X12, p, spoke)
    rep_full = report("FULL protocol", tr_full.ts, tr_full.Ps, tr_full.FoSs, tr_full.ωs, tr_full.elapsed)

    println("\n\n=== WARM-START protocol (settle → ω-v init → $RUN_S s window) ===")
    tr_ws = trace_warmstart_protocol(X12, p, spoke)
    rep_ws = report("WARM-START protocol", tr_ws.ts, tr_ws.Ps, tr_ws.FoSs, tr_ws.ωs, tr_ws.elapsed)

    if !isnothing(rep_full) && !isnothing(rep_ws)
        println("\n\n=== COMPARISON ===")
        δP = abs(rep_full.P_mean - rep_ws.P_mean) / max(abs(rep_full.P_mean), 0.01)
        @printf("  P ratio:     %.3f  (%s)\n", δP, δP < 0.15 ? "AGREE" : "DIVERGE")
        @printf("  FoS full:    %.3f\n", rep_full.FoS_min)
        @printf("  FoS warm:    %.3f\n", rep_ws.FoS_min)

        fname = joinpath(OUT_DIR, "long_trace_$(Dates.format(now(),"yyyymmdd_HHMM")).csv")
        open(fname, "w") do io
            println(io, "protocol,ts,P_kW,FoS,omega")
            for (ts,P,FoS,ω) in zip(tr_full.ts, tr_full.Ps, tr_full.FoSs, tr_full.ωs)
                println(io, "full,$ts,$P,$FoS,$ω")
            end
            for (ts,P,FoS,ω) in zip(tr_ws.ts, tr_ws.Ps, tr_ws.FoSs, tr_ws.ωs)
                println(io, "warm,$ts,$P,$FoS,$ω")
            end
        end
        println("  Trace: $fname")
    end
end

main()
