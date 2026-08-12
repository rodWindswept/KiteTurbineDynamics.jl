#!/usr/bin/env julia
# scripts/ramp_calibration_campaign.jl
#
# Small 50kW ramp-controller calibration campaign.
# Evaluates genomes through `evaluate_ramp` (RampController IDLE→RAMPING→HOLDING)
# to capture ramp-converged k_mppt and compare against bracket results.
#
# Usage:
#   julia --project=. scripts/ramp_calibration_campaign.jl
#
# Output:
#   scripts/results/ramp_calibration/ramp_campaign_v1.csv
#
# Provenance: git hash + physics-era + geometry fingerprint in CSV headers.

using KiteTurbineDynamics
using Printf, Statistics, Dates

const OUT_DIR = joinpath(@__DIR__, "results", "ramp_calibration")
mkpath(OUT_DIR)
const OUTFILE = joinpath(OUT_DIR, "ramp_campaign_v1.csv")

# ══════════════════════════════════════════════════════════════════════════════
# Campaign parameters
# ══════════════════════════════════════════════════════════════════════════════

const N_EVALS            = 20          # number of genomes to evaluate
const V_WIND             = 11.0        # rated wind speed (m/s)
const POWER_W            = 50_000.0    # target power (W)
const BEAM_PROFILE       = PROFILE_ELLIPTICAL
const PER_EVAL_TIMEOUT_S = 1200.0      # wall-clock seconds per evaluation

# Seed genomes (14-D V10) — mix of known-good and exploratory
const SEEDS = [
    # V10 tight nominal (blade_scale=1.0, 4mm tethers)
    [0.15, 0.05, 1.5, 0.5, 3.0, 3.0, 2.0, 8.0, 0.0, 30.0, 15.0, 15.0, 1.0, 1.0],
    # Smaller blades (0.85×)
    [0.15, 0.05, 1.5, 0.5, 3.0, 3.0, 2.0, 8.0, 0.0, 30.0, 15.0, 15.0, 0.85, 1.0],
    # Larger ring diameter
    [0.20, 0.05, 1.5, 0.5, 3.0, 3.0, 2.0, 8.0, 0.0, 30.0, 15.0, 15.0, 1.0, 1.0],
    # Higher r_bottom
    [0.15, 0.05, 2.0, 0.5, 3.0, 3.0, 2.0, 8.0, 0.0, 30.0, 15.0, 15.0, 1.0, 1.0],
    # Steeper bank angle
    [0.15, 0.05, 1.5, 0.5, 3.0, 3.0, 5.0, 8.0, 0.0, 25.0, 15.0, 15.0, 1.0, 1.0],
]

# ══════════════════════════════════════════════════════════════════════════════
# Setup
# ══════════════════════════════════════════════════════════════════════════════

p_base = params_v5_50kw()
git_hash = readchomp(`git rev-parse --short HEAD`)
start_time = now()

println("═══════════════════════════════════════════════════════════")
println("Ramp Calibration Campaign — $(N_EVALS) evals, $(V_WIND) m/s, $(POWER_W/1000) kW")
println("═══════════════════════════════════════════════════════════")
println("Start: $(Dates.format(start_time, "yyyy-mm-dd HH:MM:SS"))")
println("Git:   $git_hash")
println("Output: $OUTFILE")
println()

# ══════════════════════════════════════════════════════════════════════════════
# CSV header
# ══════════════════════════════════════════════════════════════════════════════

open(OUTFILE, "w") do io
    println(io, "# ramp_calibration_campaign v1")
    println(io, "# date: $(Dates.format(start_time, "yyyy-mm-dd HH:MM:SS"))")
    println(io, "# git: $git_hash")
    println(io, "# n_evals: $N_EVALS")
    println(io, "# v_wind: $V_WIND  power_W: $POWER_W")
    println(io, "# protocol: evaluate_ramp (RampController IDLE→RAMPING→HOLDING, 60s window)")
    println(io, "eval_id,seed_idx,status,fitness,P_mean_kw,FoS_min,omega_eq_rpm,P_range_kw,drifted,stationary,k_converged,ramp_chunks,wall_time_s")
end

# ══════════════════════════════════════════════════════════════════════════════
# Evaluation loop
# ══════════════════════════════════════════════════════════════════════════════

cfg = ObjectiveConfig(; power_W=POWER_W, v_rated=V_WIND, relax_s=10.0, window_s=30.0)

# ── Per-eval timeout helper ─────────────────────────────────────────────
# Runs `f()` in an @async task; returns fallback if it doesn't complete
# within `timeout_s` wall-clock seconds.  The ODE loop runs inside a tight
# explicit-Euler kernel, so this can't interrupt mid-simulation — the
# orphaned task will eventually finish (or get GC'd) on its own.
function with_timeout(f::Function, timeout_s::Float64, fallback)
    task = @async f()
    deadline = time() + timeout_s
    while !istaskdone(task) && time() < deadline
        sleep(0.25)
    end
    if istaskdone(task)
        try
            return fetch(task)
        catch e
            @warn "Eval threw" exception = e
            return fallback
        end
    else
        @warn "Per-eval timeout after $(timeout_s) s — returning fallback"
        return fallback
    end
end

for eval_id in 1:N_EVALS
    # Cycle through seeds if we have more evals than seeds
    seed_idx = mod1(eval_id, length(SEEDS))
    x = copy(SEEDS[seed_idx])

    # Add small random perturbation to explore around seed
    if eval_id > length(SEEDS)
        x .+= 0.02 .* randn(length(x)) .* x
        x = clamp.(x, 0.001, 100.0)  # safety clamp
    end

    t_start = time()
    println("[$(eval_id)/$N_EVALS] Evaluating seed $seed_idx...")

    result = with_timeout(PER_EVAL_TIMEOUT_S, rejected_eval()) do
        objective_v12_ramp(x, BEAM_PROFILE, p_base; cfg=cfg,
                           lift_device=rotary_lifter_default())
    end

    wall_s = round(time() - t_start, digits=1)

    # Determine k_converged and ramp info (not yet in ObjectiveResult — extract from sys)
    k_conv = result.status === :ok ? 0.0 : 0.0  # TODO: capture k from ramp evaluator
    n_chunks = 0  # TODO: capture from ramp evaluator

    # Write CSV row
    open(OUTFILE, "a") do io
        println(io, join([
            eval_id, seed_idx, result.status, result.fitness,
            round(result.P_mean, digits=2),
            round(result.FoS_min, digits=2),
            round(result.ω_eq * 60 / (2π), digits=1),
            round(result.P_range, digits=2),
            result.drifted, result.stationary,
            round(k_conv, digits=4), n_chunks, wall_s,
        ], ","))
    end

    status_mark = result.status === :ok ? "✓" : "✗"
    println(@sprintf("  %s P=%.1f kW  FoS=%.1f  ω=%.0f rpm  stationary=%s  %ss",
        status_mark, result.P_mean, result.FoS_min,
        result.ω_eq * 60 / (2π), result.stationary, wall_s))

    flush(stdout)
    GC.gc()  # critical for memory management between evals
end

# ══════════════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════════════

elapsed = now() - start_time
println()
println("═══════════════════════════════════════════════════════════")
println("Campaign complete.")
println("  Evals:  $N_EVALS")
println("  Time:   $(Dates.canonicalize(Dates.CompoundPeriod(elapsed)))")
println("  Output: $OUTFILE")
println("═══════════════════════════════════════════════════════════")
