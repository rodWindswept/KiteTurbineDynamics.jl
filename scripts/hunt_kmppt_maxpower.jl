#!/usr/bin/env julia
# scripts/hunt_kmppt_maxpower.jl — Gate 1 control-map re-run
#
# Hunts UNREGULATED MAX POWER at each wind speed (not P_rated).
# Builders: V10 Tight λ=1.0, V10 Reinforced, blade-rescaled λ=0.69
# Winds: 5, 7, 9, 11, 13, 15 m/s
#
# Per-row outputs: P_ground, ω, FoS, collapse_margin, P_aero, P_loss,
#   static P prediction, P/(k·ω³) stamp, closure residual, dual-duration check
# Persists: full P(k) pre-sweep per wind, per-ring FEA timeseries
# Provenance: CSV header with script @ git hash · builder · date
#
# Superseded artifact: v10_tight_control_map.csv (tier X — retained, not overwritten)

module MaxPowerHunt

using KiteTurbineDynamics
using Printf, CSV, DataFrames, Dates

# ═══════════════════════════════════════════════════════════════
const DT             = 4e-5
const T_HUNT         = 5.0
const T_VERIFY       = 60.0
const T_4X           = 20.0     # 4×T_HUNT for convergence check
const K_MIN          = 2.0
const K_MAX          = 5000.0
const MAX_BISECT     = 5         # fewer steps — we want peak, not rated crossing
const POWER_TOL      = 0.5       # kW
const FOS_TOL        = 0.02      # 2% for convergence check
const TRACE_HZ       = 10
const FEA_HZ         = 1
const TRACE_EVERY    = round(Int, 1.0 / (TRACE_HZ * DT))
const FEA_EVERY      = round(Int, 1.0 / (FEA_HZ * DT))
const SWEEP_POINTS   = 12        # log-spaced sweep between K_MIN and K_MAX
const GIT_HASH       = "86ca0e5" # settle fix + blade scaling + loss regression

# ═══════════════════════════════════════════════════════════════
struct Row
    v_wind::Float64;        k_mppt::Float64;        P_ground_kw::Float64
    ω_rpm::Float64;         min_fos::Float64;       collapse_margin_deg::Float64
    max_twist_deg::Float64; T_max_kN::Float64
    # New columns for Gate 1
    P_aero_kw::Float64;     P_loss_kw::Float64
    P_static_kw::Float64    # static solver prediction at hunted k
    consistency::Float64    # P_ground/(k·ω³)
    closure_pct::Float64    # (ΣP_aero − P_loss − P_ground)/ΣP_aero × 100
    converged_4x::Bool      # dual-duration check passed
    status::String
end

struct SweepPoint
    k::Float64;     P_kw::Float64;     ω_rpm::Float64
    P_aero_kw::Float64; P_loss_kw::Float64
end

struct VerifySlice
    t_sim::Float64;    P_kw::Float64;     ω_rpm::Float64
    min_fos::Float64;  fos_worst::Float64; worst_ring::Int
    n_failing::Int;    collapse_margin_deg::Float64
    max_twist_deg::Float64; T_max_kN::Float64
    ring_fos::Vector{Float64}; segment_twist::Vector{Float64}
end

# ═══════════════════════════════════════════════════════════════

function eval_at_k(builder, wind_speed, k_val, duration; verbose=false, lift_device=nothing)
    sys, u0, p, _ = Base.invokelatest(builder)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = [wind_speed * max(pos[3], 1.0) / p.h_ref^(1.0/7.0), 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift_device, wind_fn=wf)
    n_steps = round(Int, duration / DT)

    local P_g=0.0; local ω_h=0.0; local P_a=0.0; local P_l=0.0
    local ring_f=Float64[]; local seg_t=Float64[]; local cm=Inf; local T_m=0.0

    ctrl = RampController(P_target=p.p_rated_w)
    init_geometry!(ctrl, sys, p)

    run_canonical_sim!(u, sys, p, wf, n_steps, DT; lift_device=lift_device, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, lift_device; brake_engaged=sys.brake_engaged[])
                P_g = ef.base.P_kw; ω_h = ef.base.omega_hub
                # Aero power = sum of per-rotor aero (ExtendedSimFrame.ra)
                P_a = sum(x for x in ef.ra if !isnan(x))
                P_l = P_a - P_g
                ring_f = copy(ef.ring_fos); seg_t = copy(ef.segment_twist_deg)
                cm = min_collapse_margin(u_curr, sys, ctrl); T_m = ef.base.T_max
            end
        end)

    ω_rpm = ω_h * 60 / (2π)
    a_fos = Float64[]; for i in 2:length(ring_f)
        v = ring_f[i]; (!isnan(v) && !isinf(v) && v > 0) && push!(a_fos, v)
    end
    mf = isempty(a_fos) ? Inf : minimum(a_fos)
    mt = isempty(seg_t) ? 0.0 : maximum(abs, seg_t)

    return P_g, ω_rpm, mf, cm, mt, T_m/1000.0, P_a, P_l
end

function static_prediction(builder, wind_speed, k_val)
    sys, u0, p, _ = Base.invokelatest(builder)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = [wind_speed * max(pos[3], 1.0) / p.h_ref^(1.0/7.0), 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; wind_fn=wf)
    ef = capture_extended(u, sys, p, 0.0, wf, nothing; brake_engaged=false)
    return sum(x for x in ef.ra if !isnan(x))  # total aero power (kW) at settled state
end

function run_sweep(builder, wind_speed; verbose=false, lift_device=nothing)
    ks = unique(sort(vcat([K_MIN], exp10.(range(log10(3.0), log10(K_MAX); length=SWEEP_POINTS-2)), [K_MAX])))
    points = SweepPoint[]
    for k in ks
        P_g, ω_r, mf, cm, mt, Tm, P_a, P_l = eval_at_k(builder, wind_speed, k, T_HUNT; verbose=false, lift_device=lift_device)
        push!(points, SweepPoint(k, P_g, ω_r, P_a, P_l))
    end
    P_peak, i_peak = findmax([p.P_kw for p in points])
    verbose && @printf("  sweep: P_peak=%.1f kW at k=%.0f, ω=%.0f rpm\n", P_peak, points[i_peak].k, points[i_peak].ω_rpm)
    return points, i_peak
end

function run_verify(builder, wind_speed, k_val; verbose=false, lift_device=nothing)
    sys, u0, p, _ = Base.invokelatest(builder)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = [wind_speed * max(pos[3], 1.0) / p.h_ref^(1.0/7.0), 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift_device, wind_fn=wf)
    n_steps = round(Int, T_VERIFY / DT)
    ctrl = RampController(P_target=p.p_rated_w)
    init_geometry!(ctrl, sys, p)
    slices = Vector{VerifySlice}(undef, 0)
    run_canonical_sim!(u, sys, p, wf, n_steps, DT; lift_device=lift_device, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            if (step % FEA_EVERY == 0) || (step == n_steps)
                ef = capture_extended(u_curr, sys, p, t_curr, wf, lift_device; brake_engaged=sys.brake_engaged[])
                P_k = ef.base.P_kw; ω_r = ef.base.omega_hub * 60 / (2π)
                cm_v = min_collapse_margin(u_curr, sys, ctrl); Tm = ef.base.T_max
                rf = Float64[]; for i in 1:length(ef.ring_fos)
                    v = ef.ring_fos[i]; push!(rf, (isnan(v) || isinf(v) || v <= 0) ? Inf : v)
                end
                air = rf[2:end]; mf = minimum(air); wi = argmin(air) + 1
                nf = count(f -> f < 1.5, air); mt = maximum(abs, ef.segment_twist_deg)
                push!(slices, VerifySlice(t_curr, P_k, ω_r, mf, rf[wi], wi, nf, cm_v, mt, Tm/1000.0, copy(rf), copy(ef.segment_twist_deg)))
            end
        end)
    if !isempty(slices)
        s = slices[end]
        verbose && @printf("  verify end: t=%.0f P=%.1f ω=%.0f FoS=%.2f cm=%.1f° fail=%d/%d\n",
            s.t_sim, s.P_kw, s.ω_rpm, s.min_fos, s.collapse_margin_deg, s.n_failing, length(s.ring_fos)-1)
    end
    return slices
end

function check_convergence(builder, wind_speed, k_val; lift_device=nothing)
    P_5, ω_5, mf_5, cm_5, mt_5, Tm_5, Pa_5, Pl_5 = eval_at_k(builder, wind_speed, k_val, T_HUNT; lift_device=lift_device)
    P_20, ω_20, mf_20, cm_20, mt_20, Tm_20, Pa_20, Pl_20 = eval_at_k(builder, wind_speed, k_val, T_4X; lift_device=lift_device)
    p_ok = abs(P_5 - P_20) < POWER_TOL
    f_ok = abs(mf_5 - mf_20) < FOS_TOL * max(abs(mf_5), 1.0)
    return p_ok && f_ok, (P_5, P_20, mf_5, mf_20)
end

function hunt_max_power(builder, wind_speed; verbose=true, lift_device=nothing)
    verbose && @printf("\n── v=%.1f m/s ──\n", wind_speed)
    sweep, i_peak = run_sweep(builder, wind_speed; verbose=verbose, lift_device=lift_device)
    k_peak = sweep[i_peak].k; P_peak = sweep[i_peak].P_kw

    if P_peak < 1.0
        verbose && println("  → no power (ω=0)")
        return Row(wind_speed, k_peak, P_peak, 0.0, Inf, Inf, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, "no_spin"), sweep, VerifySlice[]
    end

    verbose && @printf("  peak: k=%.0f P=%.1f kW\n", k_peak, P_peak)

    # Refine: sweep around peak with finer spacing
    k_refine = unique(sort([k_peak * 0.7, k_peak * 0.85, k_peak, k_peak * 1.15, k_peak * 1.3]))
    filter!(k -> K_MIN <= k <= K_MAX, k_refine)
    for k in k_refine
        P_g, ω_r, mf, cm, mt, Tm, P_a, P_l = eval_at_k(builder, wind_speed, k, T_HUNT; lift_device=lift_device)
        push!(sweep, SweepPoint(k, P_g, ω_r, P_a, P_l))
        if P_g > P_peak; P_peak = P_g; k_peak = k; end
    end
    verbose && @printf("  refined peak: k=%.0f P=%.1f kW\n", k_peak, P_peak)

    # Static prediction at hunted k
    P_static = static_prediction(builder, wind_speed, k_peak)

    # 60s verification at peak
    verbose && println("  verifying (60s, 1Hz FEA) …")
    slices = run_verify(builder, wind_speed, k_peak; verbose=verbose, lift_device=lift_device)

    # Dual-duration convergence check
    conv, (p5, p20, f5, f20) = check_convergence(builder, wind_speed, k_peak; lift_device=lift_device)
    if !conv && verbose
        @printf("  ⚠ convergence: P(5s)=%.1f P(20s)=%.1f FoS(5s)=%.2f FoS(20s)=%.2f\n", p5, p20, f5, f20)
    end

    s_end = isempty(slices) ? (P_kw=0.0, ω_rpm=0.0, min_fos=Inf, collapse_margin_deg=Inf, max_twist_deg=0.0, T_max_kN=0.0, n_failing=0, ring_fos=Float64[]) : slices[end]
    P_a = sum(sweep[end].P_aero_kw)  # from refined sweep
    P_l = sum(sweep[end].P_loss_kw)
    ω_rad = s_end.ω_rpm * 2π / 60
    consistency = ω_rad > 0.1 ? s_end.P_kw / (k_peak * ω_rad^3) : 0.0
    closure = P_a > 0.1 ? (P_a - P_l - s_end.P_kw) / P_a * 100 : 0.0

    st = s_end.P_kw < 1.0 ? "no_power" :
         s_end.min_fos < 1.5 ? "FoS_fail" :
         s_end.collapse_margin_deg < 5.0 ? "collapse_risk" : "ok"

    return Row(wind_speed, k_peak, s_end.P_kw, s_end.ω_rpm, s_end.min_fos, s_end.collapse_margin_deg,
        s_end.max_twist_deg, s_end.T_max_kN, P_a, P_l, P_static, consistency, closure, conv, st), sweep, slices
end

function run_builder(builder, name, winds, out_dir; lift_device=nothing)
    mkpath(out_dir)
    rows = Row[]; all_sweeps = Dict{Float64,Vector{SweepPoint}}(); all_slices = Vector{VerifySlice}(undef, 0)

    for v in winds
        row, sweep, slices = hunt_max_power(builder, v; lift_device=lift_device)
        push!(rows, row); all_sweeps[v] = sweep
        for s in slices; push!(all_slices, s); end
    end

    # Summary
    viable = count(r -> r.status == "ok", rows)
    println("\n── $name ──  $viable/$(length(winds)) viable")
    @printf("  %6s │ %8s │ %7s │ %5s │ %5s │ %5s │ %6s │ %7s │ %7s │ %-6s │ %s\n",
        "v", "k_mppt", "P_kW", "ω", "FoS", "cm°", "P_aero", "P_static", "P/kω³", "conv", "status")
    for r in rows
        @printf("  %5.1f │ %8.1f │ %6.1f │ %4.0f │ %4.2f │ %5.1f │ %6.1f │ %7.1f │ %7.3f │ %-5s │ %s\n",
            r.v_wind, r.k_mppt, r.P_ground_kw, r.ω_rpm, r.min_fos, r.collapse_margin_deg,
            r.P_aero_kw, r.P_static_kw, r.consistency, r.converged_4x ? "Y" : "N", r.status)
    end

    # Save summary CSV with provenance header
    stamp = "# script:hunt_kmppt_maxpower @ $GIT_HASH · builder:$name · date:$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"))"
    csv_path = joinpath(out_dir, "$(name)_summary.csv")
    open(csv_path, "w") do io
        println(io, stamp)
    end
    df = DataFrame(v_wind=[r.v_wind for r in rows], k_mppt=[r.k_mppt for r in rows],
        P_ground_kw=[r.P_ground_kw for r in rows], ω_rpm=[r.ω_rpm for r in rows],
        min_fos=[r.min_fos for r in rows], collapse_margin_deg=[r.collapse_margin_deg for r in rows],
        max_twist_deg=[r.max_twist_deg for r in rows], T_max_kN=[r.T_max_kN for r in rows],
        P_aero_kw=[r.P_aero_kw for r in rows], P_loss_kw=[r.P_loss_kw for r in rows],
        P_static_kw=[r.P_static_kw for r in rows], consistency=[r.consistency for r in rows],
        closure_pct=[r.closure_pct for r in rows], converged_4x=[r.converged_4x for r in rows],
        status=[r.status for r in rows])
    CSV.write(csv_path, df; append=true, header=true)

    # Save pre-sweep CSVs
    for v in winds
        sw = all_sweeps[v]
        df_sw = DataFrame(k=[s.k for s in sw], P_kw=[s.P_kw for s in sw],
            ω_rpm=[s.ω_rpm for s in sw], P_aero_kw=[s.P_aero_kw for s in sw],
            P_loss_kw=[s.P_loss_kw for s in sw])
        CSV.write(joinpath(out_dir, "$(name)_sweep_v$(Int(v)).csv"), df_sw)
    end

    # Save timeseries
    if !isempty(all_slices)
        df_ts = DataFrame(t_s=[s.t_sim for s in all_slices], P_kw=[s.P_kw for s in all_slices],
            ω_rpm=[s.ω_rpm for s in all_slices], min_fos=[s.min_fos for s in all_slices],
            fos_worst=[s.fos_worst for s in all_slices], worst_ring=[s.worst_ring for s in all_slices],
            n_failing=[s.n_failing for s in all_slices], collapse_margin_deg=[s.collapse_margin_deg for s in all_slices],
            max_twist_deg=[s.max_twist_deg for s in all_slices], T_max_kN=[s.T_max_kN for s in all_slices])
        CSV.write(joinpath(out_dir, "$(name)_timeseries.csv"), df_ts)
    end

    println("Saved: $csv_path (+ sweep CSVs, timeseries)")
    return rows
end

end  # module

# ═══════════════════════════════════════════════════════════════
if abspath(PROGRAM_FILE) == @__FILE__
    using Pkg; Pkg.activate(dirname(@__DIR__))
    using KiteTurbineDynamics
    using .MaxPowerHunt

    OUT  = joinpath(dirname(@__DIR__), "scripts", "results", "control_maps")
    W    = [5.0, 7.0, 9.0, 11.0, 13.0, 15.0]
    lift = KiteTurbineDynamics.rotary_lifter_default()

    include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

    # Gate 1A — V10 Tight λ=1.0 (reproduction gate)
    println("\n══════ GATE 1A: V10 Tight λ=1.0 (reproduction) ══════")
    println("Expected: ~193 kW at k≈15.6, 11 m/s")
    MaxPowerHunt.run_builder(
        () -> Base.invokelatest(build_v10_tight_no_lowest; blade_scale=1.0),
        "v10_tight_lambda_100", W, OUT; lift_device=lift)

    # Gate 1B — V10 Reinforced
    println("\n══════ GATE 1B: V10 Reinforced ══════")
    MaxPowerHunt.run_builder(
        () -> Base.invokelatest(build_v10_tight_no_lowest; r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0),
        "v10_reinforced", W, OUT; lift_device=lift)

    # Gate 1C — Blade-rescaled λ=0.69
    println("\n══════ GATE 1C: Blade-rescaled λ=0.69 ══════")
    MaxPowerHunt.run_builder(
        () -> Base.invokelatest(build_v10_tight_no_lowest; blade_scale=0.69),
        "v10_blade_scaled_069", W, OUT; lift_device=lift)

    println("\n═══ Gate 1 complete. Check CSVs in $(OUT) ═══")
end
