#!/usr/bin/env julia
# scripts/postprocess_gate2.jl — read hunt CSV, add stability + windowed-mean P
# Usage: julia --project=. scripts/postprocess_gate2.jl gate2_reinforced_tmp

using CSV, DataFrames, Statistics, Printf

name = ARGS[1]
in_dir  = joinpath(@__DIR__, "results", "control_maps")
ts_path = joinpath(in_dir, "$(name)_timeseries.csv")
sum_path = joinpath(in_dir, "$(name)_summary.csv")

ts  = CSV.read(ts_path, DataFrame, comment="#")
sum = CSV.read(sum_path, DataFrame, comment="#")

# Add columns
sum.P_windowed = zeros(Float64, nrow(sum))
sum.stability  = fill("ok", nrow(sum))
sum.n_spokes   = zeros(Int, nrow(sum))
sum.max_T_spoke_N = zeros(nrow(sum))
sum.min_fos_spoke  = fill(Inf, nrow(sum))
sum.spoke_drag_kW  = zeros(nrow(sum))
sum.tip_mach   = zeros(nrow(sum))

for i in 1:nrow(sum)
    v = sum[i, :v]
    k = sum[i, :k_mppt]
    rows = ts[(ts.v_wind .== v) .& (ts.k_mppt .== k), :]
    if nrow(rows) == 0; continue; end

    # Stability over final 20s
    late = rows[rows.t_sim .>= rows.t_sim[end] - 20.0, :]
    if nrow(late) >= 2
        pv = late.P_kw
        nr = (maximum(pv)-minimum(pv))/max(abs(mean(pv)),0.1)
        if nr > 0.15; sum[i,:stability] = "unstable"
        elseif nr > 0.05; sum[i,:stability] = "marginal"; end
        sum[i,:P_windowed] = mean(pv)
    else
        sum[i,:P_windowed] = rows[end,:P_kw]
    end

    # Tip Mach (r_tip ≈ 5.5m)
    ω = rows[end,:ω_rpm]
    sum[i,:tip_mach] = ω * 2π/60 * 5.5 / 340.0
end

# Write Gate 2 CSV
out = replace(sum_path, "_tmp" => "")
open(out, "w") do io
    write(io, "# script:postprocess_gate2 · builder:$(name) · POSTPROCESS_REQUIRED\n")
    CSV.write(io, sum)
end
println("Wrote $out")
