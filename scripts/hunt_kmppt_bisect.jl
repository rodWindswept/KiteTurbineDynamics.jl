#!/usr/bin/env julia
# scripts/hunt_kmppt_bisect.jl
# Generic bisection-based k_mppt hunt with rich time-series structural data.
#
# Takes any system builder function, sweeps wind speeds, hunts the k_mppt
# that hits P_rated at each wind via pre-sweep + bisection, then runs a
# 60s verification capturing:
#   - 10 Hz:  P_kw, ω_rpm (cheap scalars — reveals spin-up transients)
#   - 1 Hz:   per-ring FoS, collapse margin, ring detail (FEA — structural evolution)
#
# Usage:
#   julia --project=. scripts/hunt_kmppt_bisect.jl

module ControlMapHunt

using KiteTurbineDynamics
using Printf, CSV, DataFrames, Dates

# ═══════════════════════════════════════════════════════════════
# Auto-detect code state — never hardcode (PRD 0006 checklist: stale hash made
# biased and corrected CSVs indistinguishable). "-dirty" flag covers uncommitted
# src/scripts edits (results/ excluded — runs write there).
function _detect_git_hash()
    root = dirname(@__DIR__)
    try
        h = strip(read(`git -C $root rev-parse --short HEAD`, String))
        dirty = !isempty(strip(read(
            `git -C $root status --porcelain --untracked-files=no -- src scripts ':!scripts/results'`,
            String)))
        return dirty ? "$h-dirty" : h
    catch
        return "unknown"
    end
end
const GIT_HASH       = _detect_git_hash()
const DT              = 4e-5
const T_HUNT          = 5.0      # pre-sweep + bisection sim duration (s)
const T_VERIFY        = 60.0     # verification sim duration (s)
const K_MIN           = 2.0
const K_MAX           = 5000.0
const POWER_TOL       = 0.5      # kW — bisection convergence
const MAX_BISECT      = 15
const BISECT_MIN_GAP  = 0.1
const TRACE_HZ        = 10       # P/ω/k scalar capture rate
const FEA_HZ          = 1        # per-ring FEA capture rate
const TRACE_EVERY     = round(Int, 1.0 / (TRACE_HZ * DT))
const FEA_EVERY       = round(Int, 1.0 / (FEA_HZ * DT))

# ═════════════════════════════════════════════════════════════════════════
struct HuntResult
    v_wind::Float64;   k_mppt::Float64;   P_kw::Float64
    ω_rpm::Float64;    min_fos::Float64;  collapse_margin_deg::Float64
    max_twist_deg::Float64;  T_max_kN::Float64
    reached_rated::Bool;     status::String
    # Gate 1 new columns
    P_aero_kw::Float64; P_loss_kw::Float64; P_static_kw::Float64
    consistency::Float64; closure_pct::Float64; converged::Bool
end

"""
    VerifySlice — one time-slice during the 60s verification sim.
"""
struct VerifySlice
    t_sim::Float64;          P_kw::Float64;        ω_rpm::Float64
    min_fos::Float64;        worst_ring::Int
    fos_worst::Float64;      n_failing::Int
    collapse_margin_deg::Float64
    max_twist_deg::Float64;  T_max_kN::Float64
    segment_twist::Vector{Float64}; ring_fos::Vector{Float64}
    P_aero_kw::Float64       # Gate 1: aero power at this slice
end

# ═════════════════════════════════════════════════════════════════════════
# Core simulation
# ═════════════════════════════════════════════════════════════════════════

"""
    run_capture(builder, wind_speed, k_val, duration) → P_kw, ω_rpm, etc.

Build, settle, run a sim of `duration` seconds, capture one endpoint snapshot.
Used for the pre-sweep and bisection (fast path — no time-series overhead).
"""
function run_capture(
    builder::Function, wind_speed::Float64, k_val::Float64, duration::Float64;
    verbose::Bool=false, lift_device=nothing,
)
    sys, u0, p, _ = Base.invokelatest(builder)
    sys.k_mppt_ref[] = k_val

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [wind_speed * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end

    u = settle_to_operational_state(sys, copy(u0), p, 9.5;
        lift_device=lift_device, wind_fn=wf)
    n_steps = round(Int, duration / DT)

    ctrl = RampController(P_target=p.p_rated_w)
    init_geometry!(ctrl, sys, p)

    local P_kw=0.0; local ω_hub=0.0
    local ring_fos=Float64[]; local seg_twist=Float64[]
    local collapse_margin=Inf; local T_max=0.0

    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=lift_device, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, lift_device;
                    brake_engaged=sys.brake_engaged[])
                P_kw = ef.base.P_kw
                ω_hub = ef.base.omega_hub
                ring_fos = copy(ef.ring_fos)
                seg_twist = copy(ef.segment_twist_deg)
                collapse_margin = min_collapse_margin(u_curr, sys, ctrl)
                T_max = ef.base.T_max
            end
        end)

    ω_rpm = ω_hub * 60 / (2π)
    airborne_fos = Float64[]
    for i in 2:length(ring_fos)
        v = ring_fos[i]; (!isnan(v) && !isinf(v) && v > 0) && push!(airborne_fos, v)
    end
    min_fos = isempty(airborne_fos) ? Inf : minimum(airborne_fos)
    max_twist = isempty(seg_twist) ? 0.0 : maximum(abs, seg_twist)
    T_max_kN = T_max / 1000.0

    verbose && @printf("    k=%7.1f  P=%6.2f kW  ω=%5.1f rpm  FoS=%5.2f  cm=%.1f°\n",
        k_val, P_kw, ω_rpm, min_fos, collapse_margin)

    return P_kw, ω_rpm, min_fos, collapse_margin, max_twist, T_max_kN
end


"""
    run_verify_timeseries(builder, wind_speed, k_val)
    → Vector{VerifySlice}

Run the 60s verification sim with 10 Hz scalar capture + 1 Hz FEA capture.
Returns a vector of time-slices suitable for CSV output.
"""
function run_verify_timeseries(
    builder::Function, wind_speed::Float64, k_val::Float64;
    verbose::Bool=false, lift_device=nothing,
)
    sys, u0, p, _ = Base.invokelatest(builder)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [wind_speed * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end
    u = settle_to_operational_state(sys, copy(u0), p, 9.5;
        lift_device=lift_device, wind_fn=wf)
    n_steps = round(Int, T_VERIFY / DT)

    ctrl = RampController(P_target=p.p_rated_w)
    init_geometry!(ctrl, sys, p)

    slices = VerifySlice[]

    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=lift_device, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            # 10 Hz scalar capture (cheap)
            if step % TRACE_EVERY == 0 || step == n_steps
                # 1 Hz FEA capture (expensive)
                if step % FEA_EVERY == 0 || step == n_steps
                    ef = capture_extended(u_curr, sys, p, t_curr, wf, lift_device;
                        brake_engaged=sys.brake_engaged[])
                    P_kw  = ef.base.P_kw
                    ω_rpm = ef.base.omega_hub * 60 / (2π)
                    cm = min_collapse_margin(u_curr, sys, ctrl)
                    T_max = ef.base.T_max
                    ring_fos = Float64[]
                    for i in 1:length(ef.ring_fos)
                        v = ef.ring_fos[i]
                        push!(ring_fos, (isnan(v) || isinf(v) || v <= 0) ? Inf : v)
                    end
                    airborne = ring_fos[2:end]   # skip ground ring
                    min_f = minimum(airborne)
                    worst_i = argmin(airborne) + 1  # re-index to 1-based
                    n_fail = count(f -> f < 1.5, airborne)
                    mt = maximum(abs, ef.segment_twist_deg)
                    P_aero = sum(x for x in ef.rotor_aero_power if !isnan(x))

                    push!(slices, VerifySlice(
                        t_curr, P_kw, ω_rpm, min_f, worst_i,
                        ring_fos[worst_i], n_fail, cm, mt, T_max / 1000.0,
                        copy(ef.segment_twist_deg), copy(ring_fos), P_aero,
                    ))
                end
            end
        end)

    verbose && !isempty(slices) && begin
        s = slices[end]
        println("    final: t=$(round(s.t_sim, digits=1))s P=$(round(s.P_kw, digits=1))kW ω=$(round(s.ω_rpm, digits=0))rpm FoS=$(round(s.min_fos, digits=2)) cm=$(round(s.collapse_margin_deg, digits=1))° $(s.n_failing)/$(length(s.ring_fos)-1) failing")
    end

    return slices
end


# ═════════════════════════════════════════════════════════════════════════
# Hunt logic
# ═════════════════════════════════════════════════════════════════════════

function hunt_k_at_wind(
    builder::Function, wind_speed::Float64, P_rated::Float64;
    verbose::Bool=false, lift_device=nothing, max_power::Bool=false,
)
    P_rated_kw = P_rated / 1000.0
    verbose && println("  v=$(wind_speed) m/s — pre-sweep …")

    ks_sweep = unique(sort(vcat(
        [K_MIN], exp10.(range(log10(3.0), log10(500.0); length=8)), [K_MAX]
    )))
    P_sweep = Float64[]; ω_sweep = Float64[]
    for k_try in ks_sweep
        Pk, ωk, _, _, _, _ = run_capture(
            builder, wind_speed, k_try, T_HUNT; verbose=false, lift_device=lift_device)
        push!(P_sweep, Pk); push!(ω_sweep, ωk)
    end
    P_peak, i_peak = findmax(P_sweep)

    verbose && @printf("    sweep: P_peak=%.1f kW (k=%.0f)  P_maxk=%.1f kW\n",
        P_peak, ks_sweep[i_peak], P_sweep[end])

    if P_peak < P_rated_kw * 0.85 && !max_power
        verbose && println("    → underpowered")
        return HuntResult(wind_speed, ks_sweep[i_peak], P_peak,
            ω_sweep[i_peak]*60/(2π), Inf, Inf, 0.0, 0.0, false, "underpowered",
            0.0, 0.0, 0.0, 0.0, 0.0, false),
            VerifySlice[]
    end

    k_best = ks_sweep[i_peak]
    P_best = P_peak

    if max_power
        verbose && @printf("    max-power mode: k=%.0f P_peak=%.1f kW\n", k_best, P_best)
    else
        k_low, P_low = K_MIN, P_sweep[1]
        k_high, P_high = ks_sweep[i_peak], P_peak
        for i in 2:i_peak
            if P_sweep[i-1] < P_rated_kw && P_sweep[i] >= P_rated_kw
                k_low, P_low = ks_sweep[i-1], P_sweep[i-1]
                k_high, P_high = ks_sweep[i], P_sweep[i]; break
            end
        end
        if P_low >= P_rated_kw
            verbose && println("    → all sweep points above rated")
            k_low, P_low = K_MIN, P_sweep[1]
        end
        verbose && @printf("    bracket: k∈[%.0f, %.0f] P∈[%.1f, %.1f] kW\n",
            k_low, k_high, P_low, P_high)

        k_best, P_best = k_low, P_low
        verbose && println("    bisecting …")
        for iter in 1:MAX_BISECT
            k_mid = (k_low + k_high) / 2.0
            abs(k_high - k_low) < BISECT_MIN_GAP && break
            P_mid, _, _, _, _, _ = run_capture(
                builder, wind_speed, k_mid, T_HUNT; verbose=false, lift_device=lift_device)
            verbose && @printf("    iter %2d: k=%7.1f P=%6.2f kW\n", iter, k_mid, P_mid)
            if P_mid < P_rated_kw
                k_low = k_mid; P_mid > P_best && (P_best=P_mid; k_best=k_mid)
            else
                k_high = k_mid
            end
            abs(P_mid - P_rated_kw) < POWER_TOL && (k_best=k_mid; P_best=P_mid; break)
        end
    end

    # Static prediction at hunted k (via extended capture)
    run_capture(builder, wind_speed, k_best, T_HUNT; verbose=false, lift_device=lift_device)
    sys_st, u0_st, p_st, _ = Base.invokelatest(builder)
    sys_st.k_mppt_ref[] = k_best
    wf_st(pos, t) = begin
        z = max(pos[3], 1.0)
        [wind_speed * (z / p_st.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end
    u_st = settle_to_operational_state(sys_st, copy(u0_st), p_st, 9.5; wind_fn=wf_st)
    ef_st = capture_extended(u_st, sys_st, p_st, 0.0, wf_st, nothing; brake_engaged=false)
    P_static = sum(x for x in ef_st.rotor_aero_power if !isnan(x))

    verbose && println("    verifying at k=$(round(k_best, digits=1)) (60s, 1Hz FEA) …")
    slices = run_verify_timeseries(
        builder, wind_speed, k_best; verbose=verbose, lift_device=lift_device)

    s_end = isempty(slices) ? (P_kw=0.0, ω_rpm=0.0, min_fos=Inf, collapse_margin_deg=Inf,
        max_twist_deg=0.0, T_max_kN=0.0) : slices[end]
    reached = s_end.P_kw >= P_rated_kw * 0.8
    st = !reached ? "power_deficit" : s_end.min_fos < 1.5 ? "FoS_fail" :
         s_end.collapse_margin_deg < 5.0 ? "collapse_risk" : "ok"
    verbose && @printf("    result: P=%.1f kW ω=%.0f rpm FoS=%.2f cm=%.1f° %s (%d slices)\n",
        s_end.P_kw, s_end.ω_rpm, s_end.min_fos, s_end.collapse_margin_deg, st, length(slices))

    # Gate 1: capture aero power from last verify slice
    P_aero = isempty(slices) ? 0.0 : slices[end].P_aero_kw
    P_loss = P_aero - s_end.P_kw
    ω_rad = s_end.ω_rpm * 2π / 60
    cons = ω_rad > 0.1 ? s_end.P_kw / (k_best * ω_rad^3) : 0.0
    close = P_aero > 0.1 ? (P_aero - P_loss - s_end.P_kw) / P_aero * 100 : 0.0

    # Dual-duration convergence check (5s vs 20s)
    P_20, _, _, _, _, _ = run_capture(
        builder, wind_speed, k_best, 20.0; verbose=false, lift_device=lift_device)
    conv = abs(s_end.P_kw - P_20) < POWER_TOL

    return HuntResult(wind_speed, k_best, s_end.P_kw, s_end.ω_rpm,
        s_end.min_fos, s_end.collapse_margin_deg, s_end.max_twist_deg, s_end.T_max_kN,
        reached, st, P_aero, P_loss, P_static, cons, close, conv), slices
end


# ═════════════════════════════════════════════════════════════════════════
# Top-level: run full control map, save CSVs
# ═════════════════════════════════════════════════════════════════════════

function hunt_control_map(
    builder::Function, P_rated::Float64, wind_speeds::Vector{Float64};
    out_dir::String=joinpath(dirname(@__DIR__), "scripts", "results", "control_maps"),
    name::String="control_map", verbose::Bool=true, lift_device=nothing,
    max_power::Bool=false,
)
    mkpath(out_dir)

    println("═"^60)
    println("Control map: $name")
    println("Rated: $(P_rated/1000) kW  Winds: $wind_speeds  Trace: $(TRACE_HZ)Hz  FEA: $(FEA_HZ)Hz")
    println("═"^60)

    results = HuntResult[]
    all_slices = VerifySlice[]

    for v in wind_speeds
        println()
        result, slices = hunt_k_at_wind(builder, v, P_rated;
            verbose=verbose, lift_device=lift_device, max_power=max_power)
        push!(results, result)
        for s in slices
            push!(all_slices, s)
        end
    end

    # ── Summary CSV ─────────────────────────────────────────────────
    viable = count(r -> r.status == "ok", results)
    println("\n── $(name) ──  $(viable)/$(length(wind_speeds)) viable")
    @printf("  %5s │ %8s │ %7s │ %5s │ %5s │ %5s │ %6s │ %7s │ %7s │ %-5s │ %s\n",
        "v", "k_mppt", "P_kW", "ω", "FoS", "cm°", "P_aero", "P_static", "P/kω³", "conv", "status")
    for r in results
        @printf("  %5.1f │ %8.1f │ %6.1f │ %4.0f │ %4.2f │ %5.1f │ %6.1f │ %7.1f │ %7.3f │ %-5s │ %s\n",
            r.v_wind, r.k_mppt, r.P_kw, r.ω_rpm, r.min_fos, r.collapse_margin_deg,
            r.P_aero_kw, r.P_static_kw, r.consistency, r.converged ? "Y" : "N", r.status)
    end

    stamp = "# script:hunt_kmppt_bisect @ $(GIT_HASH) · builder:$(name) · date:$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")) · max_power:$(max_power)"
    csv_path = joinpath(out_dir, "$(name)_summary.csv")
    open(csv_path, "w") do io; println(io, stamp); end
    df_summary = DataFrame(
        v_wind=[r.v_wind for r in results], k_mppt=[r.k_mppt for r in results],
        P_kw=[r.P_kw for r in results], ω_rpm=[r.ω_rpm for r in results],
        min_fos=[r.min_fos for r in results], collapse_margin_deg=[r.collapse_margin_deg for r in results],
        max_twist_deg=[r.max_twist_deg for r in results], T_max_kN=[r.T_max_kN for r in results],
        reached_rated=[r.reached_rated for r in results], status=[r.status for r in results],
        P_aero_kw=[r.P_aero_kw for r in results], P_loss_kw=[r.P_loss_kw for r in results],
        P_static_kw=[r.P_static_kw for r in results], consistency=[r.consistency for r in results],
        closure_pct=[r.closure_pct for r in results], converged=[r.converged for r in results],
    )
    CSV.write(csv_path, df_summary; append=true, header=true)

    # ── Timeseries CSV (1 Hz FEA slices) ────────────────────────────
    if !isempty(all_slices)
        df_ts = DataFrame(
            t_s=[s.t_sim for s in all_slices], P_kw=[s.P_kw for s in all_slices],
            ω_rpm=[s.ω_rpm for s in all_slices], min_fos=[s.min_fos for s in all_slices],
            worst_ring=[s.worst_ring for s in all_slices], fos_worst=[s.fos_worst for s in all_slices],
            n_failing=[s.n_failing for s in all_slices],
            collapse_margin_deg=[s.collapse_margin_deg for s in all_slices],
            max_twist_deg=[s.max_twist_deg for s in all_slices],
            T_max_kN=[s.T_max_kN for s in all_slices], P_aero_kw=[s.P_aero_kw for s in all_slices],
        )
        CSV.write(joinpath(out_dir, "$(name)_timeseries.csv"), df_ts)
        println("Timeseries: $(length(all_slices)) slices → $(name)_timeseries.csv")
    end

    println("Saved: $(name)_summary.csv")
    return df_summary
end

# ═════════════════════════════════════════════════════════════════════════
# Builder factories (unchanged)
# ═════════════════════════════════════════════════════════════════════════

canonical_10kw_builder() = begin
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    sys, u0, p, "Canonical 10 kW"
end

function v10_tight_builder(; r_bottom_scale::Float64=1.0, tether_diameter::Float64=0.003, blade_scale::Float64=1.0)
    include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))
    return () -> Base.invokelatest(build_v10_tight_no_lowest;
        r_bottom_scale=r_bottom_scale, tether_diameter=tether_diameter, blade_scale=blade_scale)
end

end  # module

# ═════════════════════════════════════════════════════════════════════════
# GATE 1: Max-power control-map re-run
# ═════════════════════════════════════════════════════════════════════════
if abspath(PROGRAM_FILE) == @__FILE__
    using Pkg; Pkg.activate(dirname(@__DIR__))
    using KiteTurbineDynamics
    using .ControlMapHunt

    OUT_DIR = joinpath(dirname(@__DIR__), "scripts", "results", "control_maps")
    WINDS   = [5.0, 7.0, 9.0, 11.0, 13.0, 15.0]
    lift    = KiteTurbineDynamics.rotary_lifter_default()

    # ── Gate 1: all three builders completed 2026-07-05/06 ──────────────────
    # Re-run any gate by uncommenting the block below. Parameters are the
    # authoritative record of what was run.

    # Gate 1A: V10 Tight λ=1.0 (done — 2026-07-05T21:37, CSV: gate1_v10_tight_maxpower)
    # println("\n══════ GATE 1A: V10 Tight λ=1.0 ══════")
    # ControlMapHunt.hunt_control_map(
    #     ControlMapHunt.v10_tight_builder(blade_scale=1.0), 50000.0, WINDS;
    #     out_dir=OUT_DIR, name="gate1_v10_tight_maxpower", lift_device=lift,
    #     verbose=true, max_power=true)

    # Gate 1B: V10 Reinforced (done — 2026-07-05T22:58, CSV: gate1_v10_reinforced_maxpower)
    # println("\n══════ GATE 1B: V10 Reinforced ══════")
    # ControlMapHunt.hunt_control_map(
    #     ControlMapHunt.v10_tight_builder(r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0),
    #     50000.0, WINDS;
    #     out_dir=OUT_DIR, name="gate1_v10_reinforced_maxpower", lift_device=lift,
    #     verbose=true, max_power=true)

    # Gate 1C: Blade-rescaled λ=0.69 (done — 2026-07-06T00:37, CSV: gate1_blade_scaled_069_maxpower)
    # println("\n══════ GATE 1C: Blade-rescaled λ=0.69 ══════")
    # ControlMapHunt.hunt_control_map(
    #     ControlMapHunt.v10_tight_builder(blade_scale=0.69), 50000.0, WINDS;
    #     out_dir=OUT_DIR, name="gate1_blade_scaled_069_maxpower", lift_device=lift,
    #     verbose=true, max_power=true)

    println("\n═══ All Gate 1 builders completed. Uncomment a block above to re-run. ═══")
end
