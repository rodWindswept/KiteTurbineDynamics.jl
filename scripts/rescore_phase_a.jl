#!/usr/bin/env julia
# scripts/rescore_phase_a.jl
# ═══════════════════════════════════════════════════════════════════════
# Re-score archived feasibility_phase_a_garbage.csv under corrected rules
# (commits ce85b3a+: A1-A5 fixes applied).
#
# USAGE:
#   # Test on first 3 rows (~5-30 min):
#   julia --project=. scripts/rescore_phase_a.jl --limit 3
#
#   # Full re-score (~2-8 hours depending on rejection rate):
#   nohup julia --project=. scripts/rescore_phase_a.jl > rescore.log 2>&1 &
#
# INPUT:  scripts/results/recampaign/feasibility_phase_a_garbage.csv
# OUTPUT: scripts/results/recampaign/feasibility_phase_a_rescored.csv
#
# Columns in output: genome_hash, n_lines, n_active, P_mean_kw, FoS_min,
#   f_feas, tier, util_axial, util_bending, stationary, rescore_git, rescore_time
#
# WHAT CHANGED (A1-A5):
#   A1 — util_a/util_b now from FoS-min sample (was independent maxima)
#   A2 — Betz ceiling rejects P > (16/27)·½ρ·πR²·v³
#   A3 — n_rings < 5 rejected at decode (Tulloch model validity)
#   A4 — n_lines clamp raised from 12→16 (was 27% dead zone)
#   A5 — rejection returns use 12.0 band (was 1e9 sentinel)
#
# AFTER RE-SCORING:
#   1. Compare old vs new P-vs-FoS scatter — the Pareto front decides
#      frames vs tubes.  See Rod's handover § "Re-scored power-versus-FoS
#      Pareto front reviewed before committing another 40 hours."
#   2. Check that 1103 kW row is now flagged (Betz ceiling, A2).
#   3. Check that util_a + util_b ≈ 1/FoS_min holds (A1 identity).
# ═══════════════════════════════════════════════════════════════════════

using KiteTurbineDynamics, CSV, DataFrames, Printf, Dates

const IN_CSV  = joinpath(@__DIR__, "results", "recampaign", "feasibility_phase_a_garbage.csv")
const OUT_CSV = joinpath(@__DIR__, "results", "recampaign", "feasibility_phase_a_rescored.csv")
const GIT_HASH = strip(read(`git -C $(dirname(@__DIR__)) rev-parse --short HEAD`, String))

const BEAM    = PROFILE_ELLIPTICAL
const P_BASE  = params_v5_50kw()
const POWER_W = 50000.0
const V_RATED = 11.0
const P_CAP   = 50.0
const P_FLOOR = 25.0
const FOS_DES = 1.5

lim = something(tryparse(Int, get(ARGS, length(ARGS) >= 2 && ARGS[1] == "--limit" ? 2 : -1, "")), 0)

df = CSV.read(IN_CSV, DataFrame)
n = lim > 0 ? min(lim, nrow(df)) : nrow(df)
@printf("Re-scoring %d/%d rows (commit %s)\n", n, nrow(df), GIT_HASH)

results = DataFrame(
    genome_hash = String[], n_lines = Int[], n_active = Int[],
    P_mean_kw = Float64[], FoS_min = Float64[], f_feas = Float64[],
    tier = String[], util_axial = Float64[], util_bending = Float64[],
    stationary = Bool[], rescore_git = String[], rescore_time = String[],
)

for i in 1:n
    row = df[i, :]
    x = [row.x1, row.x2, row.x3, row.x4, row.x5, row.x6, row.x7,
         row.x8, row.x9, row.x10, row.x11, row.x12, row.x13, row.x14, row.x15]

    t0 = time()
    fitness, P_mean, FoS_min, ω_eq, P_range, drifted, stationary, util_a, util_b =
        objective_v11_warmstart(x, BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED)

    f_feas = objective_feasibility(P_mean, FoS_min; P_cap=P_CAP, P_floor=P_FLOOR, FoS_design=FOS_DES)
    tier = f_feas >= 12.0 ? "rejected" :
           f_feas >= 10.0 ? "stalled" :
           f_feas > 0.0   ? "feasibility" : "feasible"

    push!(results, (
        row.genome_hash, round(Int, row.n_lines), round(Int, row.n_active),
        P_mean, FoS_min, f_feas, tier, util_a, util_b, stationary,
        GIT_HASH, string(now())
    ))

    elapsed = time() - t0
    eta_s = (n - i) * elapsed / 60
    @printf("  [%3d/%d] %.1fs  P=%.1f kW  FoS=%.2f  f=%.3f  %s  eta %.0f min\n",
            i, n, elapsed, P_mean, FoS_min, f_feas, tier, eta_s)
    flush(stdout)
end

CSV.write(OUT_CSV, results)
@printf("\nDone.  %d rows → %s\n", n, OUT_CSV)

# Quick comparison summary
old_bad = count(row -> row.P_mean_kw > 100, eachrow(df[1:n, :]))
new_bad = count(r -> r.P_mean_kw > 100, eachrow(results))
@printf("Old: %d rows with P > 100 kW  New: %d rows\n", old_bad, new_bad)
