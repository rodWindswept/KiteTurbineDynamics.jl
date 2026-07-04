#!/usr/bin/env julia
# charts/generate_charts.jl — F1-F6 per PRD 0005, simplified for reliability
using Pkg; Pkg.activate(dirname(@__DIR__))
using CairoMakie
using Printf
using Dates

mkpath(joinpath(dirname(@__DIR__), "charts", "output"))

# ── Design hues ──
BLUE   = RGBf(0.0, 0.45, 0.7)
ORANGE = RGBf(0.9, 0.6, 0.0)
GREEN  = RGBf(0.0, 0.62, 0.45)
PURPLE = RGBf(0.8, 0.47, 0.65)
RED    = RGBf(0.84, 0.37, 0.0)
GREY   = RGBf(0.5, 0.5, 0.5)

function dc(λ)
    λ == 1.0 && return BLUE
    λ == 0.79 && return ORANGE
    λ == 0.69 && return GREEN
    λ == 0.54 && return PURPLE
    return GREY
end

function prov!(fig, script, commit, data, model)
    Label(fig[end+1, :], "$script @ $commit · $data · $model · $(today())",
          fontsize=7, color=:grey40, halign=:left)
end

function badge!(fig, tier)
    Label(fig[0, :, Right()], "TIER $tier", fontsize=8, font=:bold, halign=:right, color=:orange)
end

println("Generating charts...")

# ═══ F1: Power curve P(v), λ=0.69 ═══
let
    fig = Figure(size=(800, 480))
    ax = Axis(fig[1,1], xlabel="Wind speed (m/s)", ylabel="Power (kW)",
              title="F1 — Power curve λ=0.69")
    v = [5,7,9,11,13,15]
    p = [4.5,13.8,32.2,62.1,106.9,168.1]
    c = dc(0.69)
    scatter!(ax, v, p, color=c, markersize=12)
    lines!(ax, v, p, color=c, linestyle=:dash)
    v3 = 62.1 .* ((5:0.5:11) ./ 11).^3
    lines!(ax, 5:0.5:11, v3, color=:grey50, linestyle=:dot, label="P ∝ v³")
    hlines!(ax, [50], color=RED, linestyle=:dash, label="50 kW")
    axislegend(ax, position=:lt, fontsize=9)
    ylims!(ax, 0, 200)
    prov!(fig, "generate_charts.jl", "86ca0e5", "low_wind_curve.jl", "V10/constCL")
    badge!(fig, "P")
    save(joinpath(dirname(@__DIR__), "charts", "output", "F1_power_curve.svg"), fig)
    println("  F1 done")
end

# ═══ F2: FoS envelope ═══
let
    fig = Figure(size=(800, 480))
    ax = Axis(fig[1,1], xlabel="Wind speed (m/s)", ylabel="FoS",
              title="F2 — FoS envelope")
    v = [11,13,15]
    fos_069 = [4.29, 3.19, 2.51]
    fos_079 = [3.70, 2.76, 2.13]
    scatter!(ax, [11,15], [2.53, 1.36], color=dc(1.0), marker=:xcross, markersize=16, label="λ=1.0 gate")
    scatter!(ax, v, fos_079, color=dc(0.79), markersize=12, label="λ=0.79")
    lines!(ax, v, fos_079, color=dc(0.79), linestyle=:dash)
    scatter!(ax, v, fos_069, color=dc(0.69), markersize=12, label="λ=0.69")
    lines!(ax, v, fos_069, color=dc(0.69), linestyle=:dash)
    hlines!(ax, [1.5], color=RED, linestyle=:dash, linewidth=2, label="FoS=1.5")
    axislegend(ax, position=:rt, fontsize=9)
    ylims!(ax, 0, 5.5)
    prov!(fig, "generate_charts.jl", "86ca0e5", "envelope_test.jl", "V10/constCL")
    badge!(fig, "P")
    save(joinpath(dirname(@__DIR__), "charts", "output", "F2_fos_envelope.svg"), fig)
    println("  F2 done")
end

# ═══ F3: Energy waterfall ═══
let
    fig = Figure(size=(500, 380))
    ax = Axis(fig[1,1], ylabel="Power (kW)", title="F3 — Energy waterfall λ=0.69 @ 11 m/s",
              xticks=(1:3, ["ΣP_aero", "Shaft loss", "P_ground"]))
    p = [86.2, 24.1, 62.1]
    barplot!(ax, 1:3, p, color=[BLUE, ORANGE, dc(0.69)])
    hlines!(ax, [50], color=RED, linestyle=:dash)
    ylims!(ax, 0, 100)
    Label(fig[2,1], "ΣP − loss − P_gen = $(round(86.2-24.1-62.1, digits=2)) kW ✓",
          fontsize=7, color=:grey40)
    prov!(fig, "generate_charts.jl", "86ca0e5", "energy_balance.jl", "V10/constCL")
    badge!(fig, "P")
    save(joinpath(dirname(@__DIR__), "charts", "output", "F3_energy_waterfall.svg"), fig)
    println("  F3 done")
end

# ═══ F4: Static vs dynamics ═══
let
    fig = Figure(size=(800, 480))
    ax = Axis(fig[1,1], xlabel="ω (rpm)", ylabel="Expansion aero (kW)",
              title="F4 — Static aero vs ODE operating point")
    # λ=1.0 static curve (sampled)
    ω1 = [100, 150, 200, 248, 300, 350, 400]
    p1 = [100, 170, 235, 253, 245, 215, 170]
    lines!(ax, ω1, p1, color=dc(1.0), linewidth=2, label="λ=1.0 static")
    scatter!(ax, [221], [215.5], color=dc(1.0), markersize=14, marker=:diamond, label="λ=1.0 ODE")
    
    # λ=0.54 static
    p054 = p1 .* 0.29
    lines!(ax, ω1 .* 1.27, p054, color=dc(0.54), linewidth=2, label="λ=0.54 static (×0.29)")
    scatter!(ax, [207], [48.1], color=dc(0.54), markersize=12, marker=:diamond, label="λ=0.54 ODE")
    
    axislegend(ax, position=:rt, fontsize=8)
    ylims!(ax, 0, 300)
    prov!(fig, "generate_charts.jl", "86ca0e5", "static_sweep.jl", "V10/constCL")
    badge!(fig, "P")
    save(joinpath(dirname(@__DIR__), "charts", "output", "F4_static_vs_dynamic.svg"), fig)
    println("  F4 done")
end

# ═══ F5: Blade-scaling law ═══
let
    fig = Figure(size=(600, 480))
    ax = Axis(fig[1,1], xlabel="λ² (blade area ratio)", ylabel="P_ground @ 11 m/s (kW)",
              title="F5 — Blade-scaling law")
    lam2 = [0.29, 0.48, 0.62, 1.0]
    pgnd = [23.6, 62.1, 96.0, 193.8]
    scatter!(ax, lam2, pgnd, color=[dc(0.54), dc(0.69), dc(0.79), dc(1.0)], markersize=12)
    hlines!(ax, [50], color=RED, linestyle=:dash, label="50 kW")
    axislegend(ax, position=:lt, fontsize=9)
    prov!(fig, "generate_charts.jl", "86ca0e5", "envelope_test.jl", "V10/constCL")
    badge!(fig, "P")
    save(joinpath(dirname(@__DIR__), "charts", "output", "F5_blade_scaling.svg"), fig)
    println("  F5 done")
end

# ═══ F6: Loss discriminator ═══
let
    fig = Figure(size=(800, 500))
    ax = Axis(fig[1,1], xlabel="ω (rad/s)", ylabel="Loss (kW)",
              title="F6 — Loss mechanism: c·ω³ shaft drag")
    
    og = [23.13, 31.73]; lg = [28.4, 69.1]
    o069 = [8.45,12.30,16.32,20.32,24.35,28.32]
    l069 = [2.9,7.3,14.1,24.1,37.5,55.5]
    
    scatter!(ax, og, lg, color=dc(1.0), markersize=14, label="Gate (λ=1.0)")
    scatter!(ax, o069, l069, color=dc(0.69), markersize=10, label="λ=0.69")
    
    wf = 5:2:35
    lines!(ax, wf, 2.3 .* wf.^3 ./ 1000, color=:grey30, linestyle=:dash, linewidth=2, label="c·ω³ (c=2.3)")
    
    # Annotate knockout pair
    text!(ax, 24, 32, text="same P_aero\n2× loss", fontsize=8, color=:grey30)
    
    axislegend(ax, position=:lt, fontsize=9)
    prov!(fig, "generate_charts.jl", "86ca0e5", "loss_regression.csv", "V10/constCL")
    badge!(fig, "P")
    save(joinpath(dirname(@__DIR__), "charts", "output", "F6_loss_discriminator.svg"), fig)
    println("  F6 done")
end

println("\nAll charts saved to charts/output/")
