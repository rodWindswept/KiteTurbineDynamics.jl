#!/usr/bin/env julia
# Generate chart data from catalog sweep for forum report figures
using CSV, DataFrames, Printf

df = CSV.read("scripts/results/control_maps/catalog_corrected_geo.csv", DataFrame)
ok = filter(r -> r.status == "ok", df)
viable = filter(r -> r.pass, ok)

# --- Figure 1: P vs blade_scale, colored by k_mppt ---
println("# FIGURE 1: Power vs Blade Scale (k_mppt as color)")
println("# Columns: blade_scale, k_mppt, P_kw, min_fos, omega_rpm, viable")
for r in eachrow(ok)
    @printf("%.2f,%.0f,%.1f,%.2f,%.0f,%s\n",
        r.blade_scale, r.k_mppt, r.P_kw, r.min_fos, r.omega_rpm, r.pass ? "true" : "false")
end

println()
println("# ---")
println()

# --- Figure 2: FoS vs P (Pareto frontier) ---
println("# FIGURE 2: FoS vs Power (Pareto frontier)")
println("# Columns: blade_scale, k_mppt, P_kw, min_fos, label")
for r in sort(eachrow(viable), by=x -> -x.min_fos)
    label = r.min_fos >= 6.0 ? "ultra_safe" : r.min_fos >= 4.0 ? "safe" : r.min_fos >= 2.5 ? "adequate" : "marginal"
    @printf("%.2f,%.0f,%.1f,%.2f,%s\n", r.blade_scale, r.k_mppt, r.P_kw, r.min_fos, label)
end

println()
println("# ---")
println()

# --- Figure 3: k_mppt heatmap data ---
println("# FIGURE 3: k_mppt vs blade_scale heatmap (value = P_kw)")
println("# Rows: k_mppt values, Columns: blade_scale values")
println("# Format: k_mppt,blade_scale,P_kw,pass")
for r in eachrow(ok)
    @printf("%.0f,%.2f,%.1f,%s\n", r.k_mppt, r.blade_scale, r.P_kw, r.pass ? "true" : "false")
end
