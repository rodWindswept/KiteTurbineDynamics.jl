#!/usr/bin/env julia
# scripts/audit_geometry_delta.jl
# Compare old (biased geometry, tier-X) vs new (corrected 70/30) Gate 1 CSVs.
#
# Usage: julia --project=. scripts/audit_geometry_delta.jl

using CSV, DataFrames, Printf

const OLD_DIR = joinpath(@__DIR__, "results", "control_maps", "tier-X-biased-geometry")
const NEW_DIR = joinpath(@__DIR__, "results", "control_maps")

const BUILDERS = [
    ("V10 Tight λ=1.0",       "gate1_v10_tight_maxpower"),
    ("V10 Reinforced",         "gate1_v10_reinforced_maxpower"),
    ("λ=0.69 Blade-Scaled",    "gate1_blade_scaled_069_maxpower"),
]

println("# Gate 1 Delta — Biased vs Corrected Geometry\n")

for (label, stem) in BUILDERS
    old_path = joinpath(OLD_DIR, "$(stem)_summary.csv")
    new_path = joinpath(NEW_DIR, "$(stem)_summary.csv")

    if !isfile(new_path)
        println("## $label\n")
        println("⚠ **New CSV not yet available** — Gate 1 re-run may still be in progress.\n")
        continue
    end

    old = CSV.read(old_path, DataFrame; comment="#")
    new = CSV.read(new_path, DataFrame; comment="#")

    println("## $label\n")
    println("| Wind | P_old (kW) | P_new (kW) | ΔP | ω_old | ω_new | Δω | FoS_old | FoS_new | ΔFoS | k_old | k_new |")
    println("|------|-----------|-----------|-----|------|------|-----|---------|---------|------|-------|-------|")

    for row in 1:nrow(old)
        v = old[row, :v_wind]
        o_P = old[row, :P_kw];      n_P = new[row, :P_kw]
        o_ω = old[row, :ω_rpm];     n_ω = new[row, :ω_rpm]
        o_f = old[row, :min_fos];   n_f = new[row, :min_fos]
        o_k = old[row, :k_mppt];    n_k = new[row, :k_mppt]

        ΔP = n_P - o_P;  Δω = n_ω - o_ω;  Δf = n_f - o_f
        ΔP_str = @sprintf("%+.1f", ΔP)
        Δω_str = @sprintf("%+.0f", Δω)
        Δf_str = @sprintf("%+.2f", Δf)

        @printf("| %.0f | %.1f | %.1f | %s | %.0f | %.0f | %s | %.2f | %.2f | %s | %.1f | %.1f |\n",
            v, o_P, n_P, ΔP_str, o_ω, n_ω, Δω_str, o_f, n_f, Δf_str, o_k, n_k)
    end
    println()

    # Summary statistics
    dP = new.P_kw .- old.P_kw
    dFoS = new.min_fos .- old.min_fos
    dω = new.ω_rpm .- old.ω_rpm
    dk = new.k_mppt .- old.k_mppt

    @printf("**Summary:** ΔP: %+.1f to %+.1f kW, ΔFoS: %+.2f to %+.2f, Δω: %+.0f to %+.0f rpm, Δk: %+.1f to %+.1f\n\n",
        minimum(dP), maximum(dP), minimum(dFoS), maximum(dFoS),
        minimum(dω), maximum(dω), minimum(dk), maximum(dk))
end

println("---")
println("*Old CSVs from tier-X-biased-geometry/ (2026-07-05, pre-70/30 fix). New CSVs from Gate 1 re-run with corrected geometry.*")
