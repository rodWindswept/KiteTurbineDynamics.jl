#!/usr/bin/env julia
# scripts/calibrate_dlf.jl
# Phase B of the Design Cartography programme.
#
# Empirically calibrate OPT_DESIGN_LOAD_FACTOR by running the canonical
# multi-body ODE through a battery of structural-load scenarios and extracting
# the per-ring inward-force envelope.  The DLF is defined as the ratio:
#
#     DLF(t,ring) = F_inward_per_vertex(t,ring) / T_line_axial_peak
#
# where T_line_axial_peak is the static aerodynamic axial line tension at the
# scenario's peak wind speed.
#
# Scenarios:
#   1. STEADY11   — 11 m/s rated for 8 s (baseline)
#   2. STEADY15   — 15 m/s above-rated for 8 s
#   3. STEADY20   — 20 m/s near storm cut-out
#   4. STEADY25   — 25 m/s peak design wind
#   5. GUST_11_25 — IEC coherent gust ramp 11→25 m/s over 5 s, hold 3 s
#   6. EBRAKE     — 11 m/s steady, k_mppt × 3 step at t=4s (emergency brake)
#
# Outputs:
#   scripts/results/trpt_opt/dlf/<scenario>.csv     — per-ring time series
#   scripts/results/trpt_opt/dlf/envelope.csv       — peak DLF per ring per scenario
#   scripts/results/trpt_opt/dlf/dlf_summary.csv    — overall DLF envelope (one row)
#
# Replaces the hard-coded OPT_DESIGN_LOAD_FACTOR = 0.5 with a measured value
# (writes scripts/results/trpt_opt/dlf/recommended_dlf.txt).

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using LinearAlgebra, Printf, CSV, DataFrames, Random, Dates

const OUT_DIR = joinpath(dirname(@__DIR__), "scripts", "results", "trpt_opt", "dlf")
mkpath(OUT_DIR)

const DT          = 4e-5         # ODE step (matches dashboard)
const SAVE_EVERY  = 1000         # ~25 ms between saves
const LIN_DAMP    = 0.05
const T_REL_SETTLE = 1.5         # ignore first ~1.5 s of each scenario

# ── Per-ring inward force extractor ──────────────────────────────────────────
# We re-derive F_inward per vertex from N_comp returned by ring_safety_frame
#   F_inward = 2 · n_lines · tan(π/n_lines) · N_comp
# (See structural_safety.jl: F_v = F_inward/n_lines, N_comp = F_v/(2 tan(π/n))).
"""
    extract_per_ring_F_inward(u, sys, p) → (ring_idx, radius, F_inward_total, F_in_per_vertex)

Returns one row per polygon spacer ring (skips ground & hub).
"""
function extract_per_ring_F_inward(u::Vector{Float64},
                                    sys::KiteTurbineDynamics.KiteTurbineSystem,
                                    p::SystemParams)
    N  = sys.n_total
    Nr = sys.n_ring
    α  = u[6N + 1 : 6N + Nr]
    rows = []
    n = float(p.n_lines)
    safety = ring_safety_frame(u, α, sys, p)
    for r in safety
        # Recover the original F_inward from the polygon-equilibrium relation.
        #   F_v   = 2·tan(π/n)·N_comp
        #   F_in  = n·F_v
        F_v   = 2.0 * tan(π / n) * r.N_comp
        F_in  = n * F_v
        push!(rows, (ring_id = r.ring_id,
                     radius  = r.radius,
                     N_comp  = r.N_comp,
                     P_crit  = r.P_crit,
                     fos     = r.fos,
                     F_inward_total      = F_in,
                     F_inward_per_vertex = F_v))
    end
    return rows
end

# ── Static aerodynamic axial line-tension reference ──────────────────────────
"""
    T_line_axial_static(p, v_wind) → N

Conservative axial line tension for one of the n_lines tether lines at wind
speed v_wind, using CT = OPT_CT_PEAK = 1.0.
"""
function T_line_axial_static(p::SystemParams, v_wind::Float64)
    T_peak = peak_hub_thrust(p.rotor_radius, p.elevation_angle; v=v_wind)
    return T_peak / p.n_lines
end

# ── Scenario definitions ─────────────────────────────────────────────────────
struct Scenario
    name        :: String
    v_peak      :: Float64
    duration_s  :: Float64
    wind_fn     :: Function
    perturb_fn  :: Function   # (t) → optional change to system params (e.g. ebrake)
end

scenarios(p::SystemParams) = [
    Scenario("steady11", 11.0, 6.0,
             (pos, t) -> begin
                z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1.0/7.0)
                [11.0 * sh, 0.0, 0.0]
             end,
             t -> p),
    Scenario("steady15", 15.0, 6.0,
             (pos, t) -> begin
                z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1.0/7.0)
                [15.0 * sh, 0.0, 0.0]
             end,
             t -> p),
    Scenario("steady20", 20.0, 6.0,
             (pos, t) -> begin
                z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1.0/7.0)
                [20.0 * sh, 0.0, 0.0]
             end,
             t -> p),
    Scenario("steady25", 25.0, 6.0,
             (pos, t) -> begin
                z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1.0/7.0)
                [25.0 * sh, 0.0, 0.0]
             end,
             t -> p),
    Scenario("gust_11_25", 25.0, 8.0,
             (pos, t) -> begin
                z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1.0/7.0)
                v_t = t < 1.5 ? 11.0 :
                      t < 4.5 ? 11.0 + (25.0 - 11.0) * (1 - cos(π*(t-1.5)/3.0))/2 :
                      25.0
                [v_t * sh, 0.0, 0.0]
             end,
             t -> p),
    Scenario("ebrake", 11.0, 6.0,
             (pos, t) -> begin
                z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1.0/7.0)
                [11.0 * sh, 0.0, 0.0]
             end,
             t -> p),  # k_mppt step is realised via callback below
]

# ── Run one scenario, log per-ring F_inward time series ──────────────────────
function run_scenario(p::SystemParams, sc::Scenario)
    println("\n>>> $(sc.name): v_peak=$(sc.v_peak) m/s  duration=$(sc.duration_s) s")
    t0 = time()
    sys, u0 = build_kite_turbine_system(p)
    println("    build_kite_turbine_system: $(round(time()-t0; digits=2)) s")

    t1 = time()
    u_start = settle_to_operational_state(sys, u0, p, 9.5)
    println("    settle_to_operational_state: $(round(time()-t1; digits=2)) s")

    n_steps = round(Int, sc.duration_s / DT)
    n_save  = n_steps ÷ SAVE_EVERY

    # ebrake: bump k_mppt × 3 at t=2.0s by mutating wind/dynamics.  Cheapest
    # implementation: run two sub-runs (pre-brake, then post-brake at higher k).
    if sc.name == "ebrake"
        u = copy(u_start)
        df_pre = run_log!(u, sys, p, sc.wind_fn, round(Int, 2.0/DT), DT)
        # rebuild with 3× k_mppt
        p_brake = SystemParams(
            p.rho, p.v_wind_ref, p.h_ref, p.elevation_angle, p.lifter_elevation,
            p.rotor_radius, p.tether_length, p.trpt_hub_radius, p.trpt_rL_ratio,
            p.n_lines, p.tether_diameter, p.e_modulus, p.n_rings, p.m_ring,
            p.n_blades, p.m_blade, p.cp, p.i_pto,
            p.k_mppt * 3.0,                   # ← step
            p.p_rated_w, p.β_min, p.β_max, p.β_rate_max, p.kp_elev,
            p.EA_back_line, p.c_back_line, p.back_anchor_fwd_x,
        )
        df_post = run_log!(u, sys, p_brake, sc.wind_fn,
                            round(Int, (sc.duration_s - 2.0)/DT), DT)
        df_post.t .+= 2.0
        df = vcat(df_pre, df_post)
    else
        u = copy(u_start)
        df = run_log!(u, sys, p, sc.wind_fn, n_steps, DT)
    end

    csv_path = joinpath(OUT_DIR, "$(sc.name).csv")
    CSV.write(csv_path, df)
    println("    saved $(csv_path)  ($(nrow(df)) rows)")

    # Compute per-ring DLF envelope (ignore the first T_REL_SETTLE seconds)
    df_late = df[df.t .>= T_REL_SETTLE, :]
    isempty(df_late) && (df_late = df)
    # Reference T_line at scenario v_peak
    T_ref = T_line_axial_static(p, sc.v_peak)
    rings = sort(unique(df_late.ring_id))
    env = DataFrame(
        scenario = String[],
        ring_id  = Int[],
        radius_m = Float64[],
        F_in_per_vertex_peak = Float64[],
        T_line_static_ref_N  = Float64[],
        DLF_peak             = Float64[],
        DLF_mean             = Float64[],
        DLF_p95              = Float64[],
    )
    for ri in rings
        sub = df_late[df_late.ring_id .== ri, :]
        # F per vertex = N_comp × 2 tan(π/n)
        n_lines_fl = float(p.n_lines)
        F_v_arr = 2.0 * tan(π / n_lines_fl) .* sub.N_comp
        push!(env, (sc.name, Int(ri), sub.radius[1],
                    maximum(F_v_arr),
                    T_ref,
                    maximum(F_v_arr) / max(T_ref, 1e-9),
                    sum(F_v_arr) / length(F_v_arr) / max(T_ref, 1e-9),
                    quantile(F_v_arr, 0.95) / max(T_ref, 1e-9)))
    end
    return df, env
end

# Run the integrator while logging per-ring F_inward at every saved step.
function run_log!(u::Vector{Float64},
                  sys::KiteTurbineDynamics.KiteTurbineSystem,
                  p::SystemParams,
                  wind_fn::Function,
                  n_steps::Int,
                  dt::Float64)
    df = DataFrame(t = Float64[],
                   v_hub = Float64[],
                   ring_id = Int[],
                   radius  = Float64[],
                   N_comp  = Float64[],
                   P_crit  = Float64[],
                   fos     = Float64[],
                   F_inward_total      = Float64[],
                   F_inward_per_vertex = Float64[])
    run_canonical_sim!(u, sys, p, wind_fn, n_steps, dt;
        lin_damp = LIN_DAMP,
        callback = (u_curr, t_curr, step) -> begin
            if step % SAVE_EVERY == 0
                hub_z = u_curr[3*(sys.rotor.node_id-1)+3]
                v_h   = wind_fn([0.0, 0.0, hub_z], t_curr)[1]
                rows  = extract_per_ring_F_inward(u_curr, sys, p)
                for r in rows
                    push!(df, (t_curr, v_h, r.ring_id, r.radius,
                               r.N_comp, r.P_crit, r.fos,
                               r.F_inward_total, r.F_inward_per_vertex))
                end
            end
        end
    )
    return df
end

# Helper: percentile (avoid Statistics.quantile import quirks under module reuse)
function quantile(x::AbstractVector, q::Float64)
    n = length(x); n == 0 && return 0.0
    s = sort(x)
    idx = clamp(round(Int, q * n), 1, n)
    return s[idx]
end

# ── Main ─────────────────────────────────────────────────────────────────────
function main()
    println("=" ^ 72)
    println("Phase B — Design Load Factor calibration")
    println("=" ^ 72)
    p = params_10kw()
    println("Config           : 10 kW canonical")
    println("Settings         : DT=$DT  SAVE_EVERY=$SAVE_EVERY  LIN_DAMP=$LIN_DAMP")
    println("Output dir       : $OUT_DIR")
    println("=" ^ 72)

    all_envs = DataFrame()
    for sc in scenarios(p)
        try
            _, env = run_scenario(p, sc)
            all_envs = vcat(all_envs, env)
        catch err
            @warn "scenario $(sc.name) failed: $err"
        end
    end

    env_path = joinpath(OUT_DIR, "envelope.csv")
    CSV.write(env_path, all_envs)
    println("\nWrote envelope: $env_path")

    # Overall summary: max DLF across all scenarios and rings
    overall_dlf_peak = maximum(all_envs.DLF_peak)
    overall_dlf_p95  = quantile(all_envs.DLF_p95, 0.95)
    overall_dlf_mean = sum(all_envs.DLF_mean) / nrow(all_envs)

    summary = DataFrame(
        timestamp        = [string(now())],
        n_scenarios      = [length(unique(all_envs.scenario))],
        n_rings          = [length(unique(all_envs.ring_id))],
        DLF_peak         = [overall_dlf_peak],
        DLF_p95          = [overall_dlf_p95],
        DLF_mean         = [overall_dlf_mean],
        DLF_recommended  = [overall_dlf_peak * 1.10],  # +10% safety margin
    )
    CSV.write(joinpath(OUT_DIR, "dlf_summary.csv"), summary)
    open(joinpath(OUT_DIR, "recommended_dlf.txt"), "w") do io
        @printf(io, "DLF_peak       = %.4f\n", overall_dlf_peak)
        @printf(io, "DLF_p95        = %.4f\n", overall_dlf_p95)
        @printf(io, "DLF_mean       = %.4f\n", overall_dlf_mean)
        @printf(io, "DLF_recommended= %.4f  (1.10 × peak)\n", overall_dlf_peak * 1.10)
    end

    println("\n" * "=" ^ 72)
    println("Calibration complete.")
    @printf("  DLF peak (across scenarios)  : %.4f\n", overall_dlf_peak)
    @printf("  DLF p95                      : %.4f\n", overall_dlf_p95)
    @printf("  DLF mean                     : %.4f\n", overall_dlf_mean)
    @printf("  Recommended DLF (peak × 1.1) : %.4f\n", overall_dlf_peak * 1.10)
    println("=" ^ 72)
    println("Compare: current OPT_DESIGN_LOAD_FACTOR = $(OPT_DESIGN_LOAD_FACTOR)")
end

main()
