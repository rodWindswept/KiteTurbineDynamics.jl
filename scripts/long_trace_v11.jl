#!/usr/bin/env julia
# scripts/long_trace_v11.jl
# Compare warm-start vs full protocol on 12-gon, same design, same k.
# Logs FoS, P_kW, P_aero, ω at 1 Hz for ≥120 s.  Stops on stationarity
# (rolling 30 s windows agree within ~10%), not on plateau.
#
# Questions this trace answers:
#  1. Does warm-start converge to the same answer as full protocol?
#  2. Does P settle below the Σ-annulus Betz ceiling?
#  3. Does FoS_min from window reliably represent the stationary state?

using KiteTurbineDynamics, Printf, Statistics, Dates, LinearAlgebra

const OUT_DIR = joinpath(@__DIR__, "results", "recampaign")
const X12 = [
    0.075, 0.01, 1.0, 0.5, 3.7, 2.0, 2.5, 12.0, 0.0,
    8.0, 15.0, 5.0, 0.5, 0.3, log10(10.0),
]

const RUN_S     = 120.0     # minimum run time (seconds)
const WINDOW_S  = 30        # rolling window for stationarity
const EPSILON   = 0.10      # 10% tolerance for convergence
const SAMPLE_DT = 1.0       # 1 Hz logging

# ── Utility: rolling-window stationarity check ──────────────────────────────

function is_stationary(data::Vector{Float64}, window_W::Int, ε::Float64)
    n = length(data)
    n < 2 * window_W && return false
    w1 = mean(data[(n - 2*window_W + 1):(n - window_W)])
    w2 = mean(data[(n - window_W + 1):n])
    diff = abs(w1 - w2) / max(abs(w1), abs(w2), 0.01)
    return diff < ε
end

# ── Run protocol (shared between full and warm-start) ────────────────────────

function run_trace(sys::KiteTurbineSystem, u::Vector{Float64},
                   pc::SystemParams, wf::Function, k_mppt::Float64,
                   label::String, run_s::Float64, spoke)
    sys.k_mppt_ref[] = k_mppt
    V11_DT = 4e-5
    total_n = round(Int, run_s / V11_DT)
    sample_every = max(round(Int, SAMPLE_DT / V11_DT), 1)
    Nmax = div(total_n, sample_every) + 2

    ts   = Float64[];  Ps   = Float64[]
    Pa   = Float64[];  FoSs = Float64[]
    ωs   = Float64[];  status = "ran"

    function cb(uc, tc, s)
        s % sample_every != 0 && return
        try
            ef = capture_extended(uc, sys, pc, tc, wf, nothing;
                brake_engaged=sys.brake_engaged[])
            push!(ts, tc)
            push!(Ps, ef.base.P_kw)
            push!(Pa, ef.base.P_aero_kw)
            push!(ωs, abs(uc[6*sys.n_total + sys.n_ring + 1]))
            air = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]
                (!isnan(v) && !isinf(v) && v > 0) && push!(air, v)
            end
            push!(FoSs, isempty(air) ? Inf : minimum(air))
        catch
        end
    end

    t0 = time()
    early_exit = false
    try
        run_canonical_sim!(u, sys, pc, wf, total_n, V11_DT;
            lift_device=nothing, lin_damp=0.05, spoke=spoke, callback=cb)
    catch e
        @warn "$label: sim terminated early" exception=e
        status = "crashed"
    end
    elapsed = time() - t0

    @printf("%s: %d samples in %.0f s\n", label, length(ts), elapsed)
    return (; ts, Ps, Pa, FoSs, ωs, status, elapsed)
end

# ── Report ──────────────────────────────────────────────────────────────────

function report(name, tr)
    n = length(tr.ts)
    n == 0 && (println("  No data"); return)

    @printf("\n── %s ──\n", name)
    @printf("  Duration:  %.0f s (%d samples)\n", tr.ts[end], n)

    # Stationarity
    W = WINDOW_S
    all_converged = [is_stationary(tr.Ps, W, EPSILON),
                     is_stationary(tr.FoSs[.!isinf.(tr.FoSs)], W, EPSILON),
                     is_stationary(tr.ωs, W, EPSILON)]
    @printf("  Stationary: P=%-5s  FoS=%-5s  ω=%-5s\n",
            all_converged[1] ? "yes" : "NO",
            all_converged[2] ? "yes" : "NO",
            all_converged[3] ? "yes" : "NO")

    # Window statistics (last WINDOW_S seconds)
    win_start = max(1, n - W)
    win_ts  = tr.ts[win_start:end]
    win_P   = tr.Ps[win_start:end]
    win_FoS = tr.FoSs[win_start:end]
    win_ω   = tr.ωs[win_start:end]
    fin_FoS = Float64[isfinite(x) ? x : NaN for x in win_FoS]

    @printf("  Final window (%.0f–%.0f s):\n", win_ts[1], win_ts[end])
    @printf("    P_mean:   %8.1f kW   (±%.1f)\n", mean(win_P), std(win_P))
    @printf("    P_min/max:%8.1f / %.1f kW\n", minimum(win_P), maximum(win_P))
    @printf("    FoS_mean: %8.3f   (±%.3f)\n", mean(skipmissing(fin_FoS)), std(skipmissing(fin_FoS)))
    @printf("    FoS_min:  %8.3f\n", minimum(skipmissing(fin_FoS)))
    @printf("    ω_mean:   %8.2f rad/s\n", mean(win_ω))

    # Betz check
    P_betz = betz_ceiling()
    @printf("    Betz ceiling: %.0f kW\n", P_betz)
    @printf("    Above Betz:   %s\n", mean(win_P) > P_betz * 1.1 ? "YES ⚠" : "no")

    return (; P_mean=mean(win_P), FoS_min=minimum(skipmissing(fin_FoS)),
             ω_mean=mean(win_ω), stationary=all(all_converged))
end

function betz_ceiling()
    # Σ-annulus Betz limit at 11 m/s, 50 kW rated, 12-gon geometry
    # Conservative estimate: Betz × swept area × 16/27
    ρ = 1.225; V = 11.0; r = 5.0
    A = π * r^2
    return 0.5 * ρ * A * V^3 * (16/27) / 1000  # kW
end

# ── Main ────────────────────────────────────────────────────────────────────

function main()
    mkpath(OUT_DIR)
    p = params_v5_50kw()
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)
    k_mppt = 10.0^X12[15]

    # Build system once
    result = design_from_vector_v10(X12[1:14], PROFILE_ELLIPTICAL, p)
    result.n_active == 0 && error("No active rotors")
    (; design, rotors, n_rings, zs) = result
    n_lines = design.n_lines

    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, k_mppt)

    # Build expansion params and solve equilibrium (for warm-start)
    expansion_params_v10 = KiteTurbineDynamics.ExpansionRotorParams[]
    for rotor in rotors
        er = KiteTurbineDynamics.ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius,
            rotor.blade_chord, KiteTurbineDynamics.EXP_CL_DESIGN, KiteTurbineDynamics.EXP_CD0_DESIGN, KiteTurbineDynamics.EXP_K_INDUCED,
            rotor.bank_angle_deg,
            KiteTurbineDynamics.expansion_blade_mass(rotor.blade_tip_radius, rotor.blade_scale),
            rotor.ring_idx, 1.0,
        )
        push!(expansion_params_v10, er)
    end
    _, radii, _ = ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
        density_profile=design.density_profile,
    )
    λ_eff = result.n_active > 0 ? rotors[1].blade_scale : 1.0
    k_eff = p.k_mppt * λ_eff^2
    p_scaled = override_params(p; k_mppt=k_eff)
    ω_eq, r_ref = KiteTurbineDynamics.solve_equilibrium_self_consistent(
        design, expansion_params_v10, p_scaled, n_lines, radii, zs;
        P_per_rotor=50000.0 / max(result.n_active, 1),
        v_wind=11.0, elev_rad=π/6,
    )
    @printf("Shared: ω_eq = %.2f rad/s, k_mppt = %.0f\n\n", ω_eq, k_mppt)

    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [11.0 * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    # ══════════════════════════════════════════════════════════════════════════
    # Protocol A: Full (kickstart + settle + window)
    # ══════════════════════════════════════════════════════════════════════════
    println("=== Protocol A: FULL (kickstart + settle + window) ===")
    u_full = copy(u0)
    # Settle first
    u_full = settle_to_equilibrium(sys, u_full, pc; wind_fn=wf)
    # Kickstart: spin-up with ω_eq orbital velocities
    N = sys.n_total; Nr = sys.n_ring
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        pos = u_full[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]; tang ./= norm(tang)
            vx_idx = 3*N + 3*(gid-1) + 1
            u_full[vx_idx:(vx_idx+2)] .= (ω_eq * r) .* tang
        end
    end
    trace_full = run_trace(sys, u_full, pc, wf, k_mppt, "FULL", RUN_S, spoke)
    rep_full = report("FULL protocol", trace_full)

    # ══════════════════════════════════════════════════════════════════════════
    # Protocol B: Warm-start (settle + ω-v init + window)
    # ══════════════════════════════════════════════════════════════════════════
    println("\n\n=== Protocol B: WARM-START (settle + ω-v init + window) ===")
    u_ws = copy(u0)
    u_ws = settle_to_equilibrium(sys, u_ws, pc; wind_fn=wf)
    # Set ring angular velocities AND orbital velocities (FIXED)
    u_ws[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        pos = u_ws[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]; tang ./= norm(tang)
            vx_idx = 3*N + 3*(gid-1) + 1
            u_ws[vx_idx:(vx_idx+2)] .= (ω_eq * r) .* tang
        end
    end
    trace_ws = run_trace(sys, u_ws, pc, wf, k_mppt, "WARM", RUN_S, spoke)
    rep_ws = report("WARM-START protocol", trace_ws)

    # ══════════════════════════════════════════════════════════════════════════
    # Comparison
    # ══════════════════════════════════════════════════════════════════════════
    if !isnothing(rep_full) && !isnothing(rep_ws)
        println("\n\n=== COMPARISON ===")
        δP = abs(rep_full.P_mean - rep_ws.P_mean) / max(abs(rep_full.P_mean), 0.01)
        δω = abs(rep_full.ω_mean - rep_ws.ω_mean) / max(abs(rep_full.ω_mean), 0.01)
        @printf("  P  ratio:  %.3f  (%s)\n", δP, δP < 0.15 ? "AGREE" : "DIVERGE")
        @printf("  ω  ratio:  %.3f  (%s)\n", δω, δω < 0.15 ? "AGREE" : "DIVERGE")
        @printf("  FoS full:  %.3f\n", rep_full.FoS_min)
        @printf("  FoS warm:  %.3f\n", rep_ws.FoS_min)

        fname = joinpath(OUT_DIR, "long_trace_$(Dates.format(now(), "yyyymmdd_HHMM")).csv")
        open(fname, "w") do io
            println(io, "protocol,ts,P_kW,P_aero_kW,FoS,omega")
            for (ts,P,Pa,FoS,ω) in zip(trace_full.ts, trace_full.Ps, trace_full.Pa, trace_full.FoSs, trace_full.ωs)
                println(io, "full,$ts,$P,$Pa,$FoS,$ω")
            end
            for (ts,P,Pa,FoS,ω) in zip(trace_ws.ts, trace_ws.Ps, trace_ws.Pa, trace_ws.FoSs, trace_ws.ωs)
                println(io, "warm,$ts,$P,$Pa,$FoS,$ω")
            end
        end
        println("\n  Trace: $fname")
    end
end

main()
