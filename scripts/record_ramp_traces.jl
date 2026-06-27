#!/usr/bin/env julia
# scripts/record_ramp_traces.jl
#
# Headless trace recording for the soft-ramp k_mppt controller paper.
# Compares OLD (instant k_mppt step) vs NEW (soft-ramp controller) for:
#   1. Canonical 5-line 10 kW system
#   2. V10 Tight 50 kW system (if campaign data available)
#   3. Wind ramp 7→14 m/s (canonical only)
#
# Output: scripts/results/ramp_traces/*.csv
#
# Usage:
#   julia --project=. scripts/record_ramp_traces.jl
#   # Skip V10 Tight if campaign data unavailable:
#   julia --project=. scripts/record_ramp_traces.jl --canonical-only

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, LinearAlgebra, Printf, CSV, DataFrames
import Statistics: mean

# ── Output directory ──────────────────────────────────────────────────────
OUT_DIR = joinpath(@__DIR__, "results", "ramp_traces")
mkpath(OUT_DIR)

# ── Simulation parameters ─────────────────────────────────────────────────
const DT         = 4e-5           # ODE step (s)
const SAVE_EVERY = 500            # frames every ~0.02s
const T_SPINUP   = 5.0            # gravity + operational settle before recording
const T_SIM      = 60.0           # recorded duration (s)
const T_RAMP_WIND = 150.0         # wind ramp duration (s)
const V_RATED    = 11.0           # rated wind (m/s)

# ── DataFrame schema ──────────────────────────────────────────────────────
function empty_trace_df()
    DataFrame(
        t          = Float64[],
        k_mppt     = Float64[],
        P_kw       = Float64[],
        omega_hub  = Float64[],   # rad/s
        omega_gnd  = Float64[],   # rad/s
        delta_omega = Float64[],  # rad/s
        min_fos    = Float64[],
        collapse_margin_deg = Float64[],
        twist_deg  = Float64[],
        T_max_N    = Float64[],
        state      = String[],    # controller state label
    )
end

# ── Helpers ───────────────────────────────────────────────────────────────
function total_twist_deg(u, sys)
    N = sys.n_total; Nr = sys.n_ring
    alpha = @view u[(6N + 1):(6N + Nr)]
    rad2deg(sum(mod(alpha[i+1] - alpha[i] + π, 2π) - π for i in 1:(Nr-1)))
end

function wind_steady(v)
    (pos, t) -> [v, 0.0, 0.0]
end

function wind_ramp_fn(v_lo, v_hi, T)
    (pos, t) -> begin
        frac = clamp(t / T, 0.0, 1.0)
        [v_lo + frac * (v_hi - v_lo), 0.0, 0.0]
    end
end

# ── Run one scenario ──────────────────────────────────────────────────────
# run_scenario(sys, u0, p, label, k_mppt_val, controller)
#
# Run a simulation and record trace data.
# If `controller` is `nothing`: instant k_mppt step (OLD system).
# If `controller` is a `RampController`: soft-ramp (NEW system).
# Returns a DataFrame with per-frame traces.
function run_scenario(
    sys::KiteTurbineSystem,
    u0::Vector{Float64},
    p::SystemParams,
    label::String,
    k_mppt_val::Float64,
    controller::Union{Nothing, RampController};
    wind_fn = wind_steady(V_RATED),
    t_sim::Float64 = T_SIM,
    lift_device = rotary_lifter_default(),
)
    local u, df

    # Set initial k_mppt
    sys.k_mppt_ref[] = k_mppt_val
    if controller !== nothing
        reset!(controller)
        controller.P_target = p.p_rated_w
        init_geometry!(controller, sys, p)
    end

    # Settle to operational state
    print("  settling to operational state… ")
    flush(stdout)
    ω_guess = 9.5 * (V_RATED / 11.0)
    u = settle_to_operational_state(sys, copy(u0), p, ω_guess;
        lift_device=lift_device, wind_fn=wind_fn)
    println("done")

    # Simulation loop
    df = empty_trace_df()
    n_steps = round(Int, t_sim / DT)
    n_chunks = n_steps ÷ SAVE_EVERY
    du = zeros(Float64, length(u))
    t = 0.0
    ode_params = (sys, p, wind_fn, lift_device)
    frame_dt = DT * SAVE_EVERY

    t0w = time()
    for chunk in 1:n_chunks
        # Run SAVE_EVERY steps
        for _ in 1:SAVE_EVERY
            fill!(du, 0.0)
            multibody_ode!(du, u, ode_params, t)
            # Explicit Euler
            N = sys.n_total; Nr = sys.n_ring
            @views u[(3N + 1):6N] .+= DT .* du[(3N + 1):6N]
            @views u[1:3N] .+= DT .* u[(3N + 1):6N]
            @views u[(6N + Nr + 1):(6N + 2Nr)] .+= DT .* du[(6N + Nr + 1):(6N + 2Nr)]
            @views u[(6N + 1):(6N + Nr)] .+= DT .* u[(6N + Nr + 1):(6N + 2Nr)]
            # Damping + ground constraint
            @views u[(3N + 1):6N] .*= 0.05
            @views u[(6N + Nr + 1):(6N + 2Nr)] .*= 0.05
            u[1:3] .= 0.0; u[(3N + 1):(3N + 3)] .= 0.0
            u[6N + 1] = 0.0; u[6N + Nr + 1] = 0.0
            # Kite position update
            if lift_device !== nothing
                update_kite_pos!(sys, u, lift_device, p, DT)
            end
            t += DT
        end

        # Capture frame
        sf = capture_frame(u, sys, p, t, wind_fn, lift_device; brake_engaged=sys.brake_engaged[])
        N = sys.n_total; Nr = sys.n_ring
        ω_hub = u[6N + Nr + Nr]          # hub is last ring
        ω_gnd = u[6N + Nr + 1]           # ground is ring 1

        # Controller update (if active)
        state_label_str = "fixed"
        if controller !== nothing
            collapse_margin = min_collapse_margin(u, sys, controller)
            update_ramp!(controller, sys, sf, frame_dt;
                min_fos=sf.fos_ring, collapse_margin_deg=collapse_margin)
            state_label_str = string(controller.state)
        end

        push!(df, (
            t, sys.k_mppt_ref[], sf.P_kw, ω_hub, ω_gnd,
            ω_hub - ω_gnd, sf.fos_ring,
            controller !== nothing ? min_collapse_margin(u, sys, controller) : Inf,
            total_twist_deg(u, sys), sf.T_max, state_label_str,
        ))

        if chunk % 500 == 0 || chunk == n_chunks
            elapsed = time() - t0w
            eta = elapsed / chunk * (n_chunks - chunk)
            msg = @sprintf("  t=%6.1fs  k=%.1f  P=%.2fkW  ω=%.1frpm  FoS=%.2f  [wall %.0fs ETA %.0fs]",
                t, sys.k_mppt_ref[], sf.P_kw, ω_hub*60/(2π), sf.fos_ring, elapsed, eta)
            println(msg)
        end
    end

    println("  → $(nrow(df)) frames recorded in $(round(time()-t0w; digits=1))s")
    return df
end

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

function main()
    println("═"^72)
    println("Soft-Ramp k_mppt Trace Recording")
    println("═"^72)
    println("T_sim = $(T_SIM)s, DT = $(DT)s, save every $(SAVE_EVERY) steps (~$(round(DT*SAVE_EVERY*1000, digits=1))ms)")
    println()

    # ── 1. Canonical 5-line 10 kW ─────────────────────────────────────────
    println("── 1a. Canonical 10kW — INSTANT step to k_mppt=11 ──")
    p10 = params_10kw()
    sys10, u0_10 = build_kite_turbine_system(p10)
    df_can_instant = run_scenario(sys10, u0_10, p10, "canonical-instant", 11.0, nothing)

    println()
    println("── 1b. Canonical 10kW — SOFT-RAMP from k_min=2 → P_target=10kW ──")
    sys10b, u0_10b = build_kite_turbine_system(p10)
    ctrl10 = RampController(; k_min=2.0, k_max=30.0, Kp=5e-4, P_target=10000.0)
    df_can_ramp = run_scenario(sys10b, u0_10b, p10, "canonical-ramp", 2.0, ctrl10)

    # ── 2. V10 Tight 50 kW ────────────────────────────────────────────────
    println()
    println("── 2. V10 Tight 50kW ──")
    df_v10_instant = DataFrame()
    df_v10_ramp   = DataFrame()
    try
        # Use the dashboard's builder function
        include("interactive_dashboard.jl")
        sys_v10, u0_v10, p_v10, _ = build_v10_tight_no_lowest()

        println()
        println("── 2a. V10 Tight — INSTANT step to k_mppt=62 ──")
        df_v10_instant = run_scenario(sys_v10, u0_v10, p_v10, "v10-instant", 62.0, nothing;
            t_sim=90.0)

        println()
        println("── 2b. V10 Tight — SOFT-RAMP from k_min=20 → P_target=50kW ──")
        sys_v10b, u0_v10b, _ = build_v10_tight_no_lowest()
        ctrl50 = RampController(; k_min=20.0, k_max=200.0, Kp=1e-4, P_target=50000.0)
        df_v10_ramp = run_scenario(sys_v10b, u0_v10b, p_v10, "v10-ramp", 20.0, ctrl50;
            t_sim=90.0)
    catch e
        println("  V10 Tight skipped: $(sprint(showerror, e))")
    end

    # ── 3. Wind ramp 7→14 m/s (canonical) ──────────────────────────────────
    println()
    println("── 3a. Wind ramp 7→14 m/s — INSTANT k_mppt=11 ──")
    sys10c, u0_10c = build_kite_turbine_system(p10)
    df_ramp_instant = run_scenario(sys10c, u0_10c, p10, "ramp-instant", 11.0, nothing;
        wind_fn=wind_ramp_fn(7.0, 14.0, T_RAMP_WIND), t_sim=T_RAMP_WIND)

    println()
    println("── 3b. Wind ramp 7→14 m/s — SOFT-RAMP ──")
    sys10d, u0_10d = build_kite_turbine_system(p10)
    ctrl_ramp = RampController(; k_min=2.0, k_max=30.0, Kp=5e-4, P_target=10000.0)
    df_ramp_soft = run_scenario(sys10d, u0_10d, p10, "ramp-soft", 2.0, ctrl_ramp;
        wind_fn=wind_ramp_fn(7.0, 14.0, T_RAMP_WIND), t_sim=T_RAMP_WIND)

    # ── Save all CSVs ─────────────────────────────────────────────────────
    println()
    println("── Saving CSVs ──")
    for (name, df) in [
        ("canonical_10kw_instant", df_can_instant),
        ("canonical_10kw_softramp", df_can_ramp),
        ("v10_tight_50kw_instant",  df_v10_instant),
        ("v10_tight_50kw_softramp", df_v10_ramp),
        ("wind_ramp_instant",       df_ramp_instant),
        ("wind_ramp_softramp",      df_ramp_soft),
    ]
        if nrow(df) > 0
            path = joinpath(OUT_DIR, "$name.csv")
            CSV.write(path, df)
            @printf "  %s  (%d rows)\n" path nrow(df)
        end
    end

    println()
    println("Done. Results in: $OUT_DIR")
end

main()
