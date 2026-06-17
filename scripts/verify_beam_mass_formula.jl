#!/usr/bin/env julia
# scripts/verify_beam_mass_formula.jl
# Phase 2.4 — Extract beam-mass-only scaling formula.
# Standalone: does NOT import KiteTurbineDynamics (avoids Coaxial dependency).

using Printf

"""
Beam outer diameter at ring radius r, using power-law taper.
Do(r) = Do_top × (r / r_hub)^Do_scale_exp
"""
function beam_Do(r, r_hub, Do_top, Do_scale_exp)
    return Do_top * (r / r_hub)^Do_scale_exp
end

"""
Beam mass for a single ring (kg).
n_lines beams, each of length L = 2·r·sin(π/n),
thin-walled CFRP tube: mass = ρ × π × Do × t × L
"""
function ring_beam_mass(n, r, Do, t_over_D; ρ=1600.0)
    t = Do * t_over_D
    area_cs = π * Do * t  # thin-walled tube cross-section
    mass_per_m = ρ * area_cs
    L_poly = 2 * r * sin(π / n)
    return n * mass_per_m * L_poly
end

"""
Ring radius at normalised position t ∈ [0,1] (0=top/hub, 1=bottom/ground).
β controls density: z ∝ t^(1-β)
"""
function ring_radius(t, r_hub, r_bottom, β)
    return r_hub - (r_hub - r_bottom) * t^(1 - β)
end

# ── Parameters from best_design.json ──
Do_top    = 0.0949437454281317   # m
t_over_D  = 0.01
Do_scale  = 0.7086247061538968
r_hub     = 5.396543964537164    # m
r_bottom  = 1.0485906027920717   # m
β         = -0.12856962561009427
n_rings   = 9

println("=== Beam-Mass-Only Formula ===")
println("Fixed: Do_top=$(round(Do_top*1000, digits=1)) mm, r_hub=$(round(r_hub, digits=1)) m, n_rings=$n_rings, β=$(round(β, digits=2))")
println()

totals = Float64[]
base = NaN

for n in 3:12
    total = 0.0
    for ring_idx in 1:n_rings
        t_ring = (ring_idx - 1) / (n_rings - 1)
        r = ring_radius(t_ring, r_hub, r_bottom, β)
        Do = beam_Do(r, r_hub, Do_top, Do_scale)
        total += ring_beam_mass(n, r, Do, t_over_D)
    end
    push!(totals, total)
    if n == 3; global base = total; end
end

# Also compute: beam mass if we had the SAME Do at every ring (no taper)
# This isolates the pure polygon geometry effect
total_flat = Float64[]
Do_hub = beam_Do(r_hub, r_hub, Do_top, Do_scale)
for n in 3:12
    total = 0.0
    for ring_idx in 1:n_rings
        t_ring = (ring_idx - 1) / (n_rings - 1)
        r = ring_radius(t_ring, r_hub, r_bottom, β)
        total += ring_beam_mass(n, r, Do_hub, t_over_D)
    end
    push!(total_flat, total)
end

println("n    total_kg    norm     norm(flat_Do)")
println("---  ---------   ------   ------------")
for (i, n) in enumerate(3:12)
    norm = totals[i] / base
    norm_flat = total_flat[i] / total_flat[1]
    @printf("%2d   %9.3f   %6.3f×   %6.3f×\n", n, totals[i], norm, norm_flat)
end

# Compare with formula candidates
println()
println("=== Formula comparison (normalised) ===")
println("n    actual   n·sin    n·√sin   n·sin^1.5")
for (i, n) in enumerate(3:12)
    actual = totals[i] / base
    n_sin  = (n * sin(π/n)) / (3 * sin(π/3))
    n_sqrt = (n * sqrt(sin(π/n))) / (3 * sqrt(sin(π/3)))
    n_s15  = (n * sin(π/n)^1.5) / (3 * sin(π/3)^1.5)
    best = argmin(abs.([actual - n_sin, actual - n_sqrt, actual - n_s15]))
    markers = [" ", " ", " "]
    markers[best] = "←"
    @printf("%2d   %.3f   %.3f%s  %.3f%s  %.3f%s\n",
        n, actual, n_sin, markers[1], n_sqrt, markers[2], n_s15, markers[3])
end
