#!/usr/bin/env julia
# scripts/plot_v10_trajectories.jl
# Multi-panel parameter-space map for V10 campaign winners

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, CSV, DataFrames, CairoMakie, Printf, Statistics

# ── Load data ──────────────────────────────────────────────────────────
ch = CSV.read("scripts/results/v10_campaign_50kw/convergence_history.csv", DataFrame)
pt = CSV.read("scripts/results/v10_campaign_50kw/parameter_trace.csv", DataFrame)
ib = CSV.read("scripts/results/v10_campaign_50kw/island_bests.csv", DataFrame)

# ── Extract global best trajectory ────────────────────────────────────
# For each iteration, find the best mass seen so far across all completed islands
global_best_traj = Tuple{Float64,Int,Int,Vector{Float64}}[]  # (time, island, iter, params)
best_so_far = Inf
best_params = Float64[]
island_start_times = Dict{Int,Float64}()

# Build approximate timeline from island bests
first_iter_per_island = Dict{Int,Int}()
for row in eachrow(ch)
    i = row.island
    it = row.iteration
    if !haskey(first_iter_per_island, i) || it < first_iter_per_island[i]
        first_iter_per_island[i] = it
    end
end

# Sort ch by island then iteration
sort!(ch, [:island, :iteration])

# Track when a new global best appears
global_best_island_traj = Tuple{Int,Float64,Vector{Float64}}[]  # island, mass, params
for row in eachrow(ch)
    if row.mass_kg < best_so_far && row.mass_kg < 200.0
        best_so_far = row.mass_kg
        # Find matching parameter trace
        pt_row = pt[(pt.island .== row.island) .& (pt.iteration .== row.iteration), :]
        if nrow(pt_row) > 0
            params = [pt_row.Do_top_m[1], pt_row.t_over_D[1], pt_row.beam_aspect[1],
                      pt_row.Do_scale_exp[1], pt_row.r_hub_m[1], pt_row.r_bottom_m[1],
                      pt_row.target_Lr[1], pt_row.n_lines[1], pt_row.density_profile[1],
                      pt_row.rotor_mask_proxy[1], pt_row.bank_top[1], pt_row.bank_bottom[1],
                      pt_row.lambda_top[1], pt_row.lambda_bottom[1]]
            push!(global_best_traj, (0.0, row.island, row.iteration, params))
            push!(global_best_island_traj, (row.island, row.mass_kg, params))
        end
    end
end

# Also get island-by-island bests for the background
island_final = ib[ib.mass_kg .< 200.0, :]
println("Global best trajectory: $(length(global_best_traj)) steps")
println("Feasible islands: $(nrow(island_final))")

# ── Decode key parameters ─────────────────────────────────────────────
masses = [m for (_, _, _, m) in global_best_traj]
island_nums = [i for (_, i, _, _) in global_best_traj]
n_lines_vals = [round(Int, clamp(p[8], 3, 16)) for p in [p for (_, _, _, p) in global_best_traj]]

# Decode rotor masks
n_rotor_vals = Int[]
bank_top_vals = Float64[]
lambda_top_vals = Float64[]
r_bottom_vals = Float64[]
r_hub_vals = Float64[]
for (_, _, _, p) in global_best_traj
    x = copy(p)
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    try
        res = design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw(); max_ground_radius=5.0, power_W=50000.0)
        push!(n_rotor_vals, res.n_active)
        if !isempty(res.rotors)
            push!(bank_top_vals, res.rotors[1].bank_angle_deg)
            push!(lambda_top_vals, res.rotors[1].blade_scale)
        else
            push!(bank_top_vals, NaN)
            push!(lambda_top_vals, NaN)
        end
        push!(r_bottom_vals, res.design.r_bottom)
        push!(r_hub_vals, res.design.r_hub)
    catch
        push!(n_rotor_vals, 0)
        push!(bank_top_vals, NaN); push!(lambda_top_vals, NaN)
        push!(r_bottom_vals, NaN); push!(r_hub_vals, NaN)
    end
end

# ── Build figure ───────────────────────────────────────────────────────
fig = Figure(size=(1400, 1000), backgroundcolor=:transparent)
CairoMakie.activate!(type="svg")

# Color by island
cmap = :plasma
n_steps = length(masses)
colors = [cmap[i/n_steps] for i in 1:n_steps]

# ── Title ──────────────────────────────────────────────────────────────
Label(fig[1, 1:3], "V10 Campaign — Global Best Trajectory Across Islands";
      fontsize=18, font=:bold, color=:white, padding=(0,0,10,0))

# ── Panel A: Mass trajectory ──────────────────────────────────────────
ax_mass = Axis(fig[2, 1:3];
    xlabel="Global best step", ylabel="Mass (kg)",
    title="A: Cost Function Descent",
    xgridvisible=false, ygridvisible=true,
    backgroundcolor=RGBf(0.08,0.08,0.12))
scatter!(ax_mass, 1:n_steps, masses; color=colors, markersize=10)
lines!(ax_mass, 1:n_steps, masses; color=:lawngreen, linewidth=1.5, alpha=0.5)
# Annotate best
best_idx = argmin(masses)
text!(ax_mass, best_idx, masses[best_idx] + 2;
      text="$(round(masses[best_idx], digits=1)) kg\nisland $(island_nums[best_idx])",
      color=:yellow, fontsize=10, align=(:center, :bottom))

# ── Panel B: n_lines (discrete heat) ──────────────────────────────────
ax_n = Axis(fig[3, 1];
    xlabel="Global best step", ylabel="n_lines",
    title="B: Polygon Lines",
    yticks=3:1:16, backgroundcolor=RGBf(0.08,0.08,0.12))
scatter!(ax_n, 1:n_steps, n_lines_vals; color=colors, markersize=12, marker=:rect)

# ── Panel C: n_rotors (discrete heat) ─────────────────────────────────
ax_nr = Axis(fig[3, 2];
    xlabel="Global best step", ylabel="n_rotors",
    title="C: Active Rotors",
    yticks=0:1:6, backgroundcolor=RGBf(0.08,0.08,0.12))
scatter!(ax_nr, 1:n_steps, n_rotor_vals; color=colors, markersize=12, marker=:diamond)

# ── Panel D: r_hub and r_bottom ───────────────────────────────────────
ax_r = Axis(fig[3, 3];
    xlabel="Global best step", ylabel="Radius (m)",
    title="D: Hub vs Ground Radius",
    backgroundcolor=RGBf(0.08,0.08,0.12))
scatter!(ax_r, 1:n_steps, r_hub_vals; color=:cyan, markersize=8, label="r_hub")
scatter!(ax_r, 1:n_steps, r_bottom_vals; color=:orange, markersize=8, label="r_bottom")
axislegend(ax_r; position=:lt, labelsize=8)

# ── Panel E: bank_top ─────────────────────────────────────────────────
ax_bank = Axis(fig[4, 1];
    xlabel="Global best step", ylabel="Bank (deg)",
    title="E: Bank Angle (top rotor)",
    backgroundcolor=RGBf(0.08,0.08,0.12))
scatter!(ax_bank, 1:n_steps, bank_top_vals; color=colors, markersize=10)
ylims!(ax_bank, 0, 36)

# ── Panel F: lambda_top ───────────────────────────────────────────────
ax_lam = Axis(fig[4, 2];
    xlabel="Global best step", ylabel="λ (blade scale)",
    title="F: Blade Scale (top rotor)",
    backgroundcolor=RGBf(0.08,0.08,0.12))
scatter!(ax_lam, 1:n_steps, lambda_top_vals; color=colors, markersize=10)

# ── Panel G: Mass by island ───────────────────────────────────────────
ax_island = Axis(fig[4, 3];
    xlabel="Island", ylabel="Best Mass (kg)",
    title="G: Per-Island Convergence",
    backgroundcolor=RGBf(0.08,0.08,0.12))
scatter!(ax_island, island_final.island, island_final.mass_kg;
         color=:lawngreen, markersize=6, alpha=0.7)
hlines!(ax_island, [minimum(island_final.mass_kg)]; color=:yellow, linestyle=:dash)

# ── Formatting ─────────────────────────────────────────────────────────
for ax in [ax_mass, ax_n, ax_nr, ax_r, ax_bank, ax_lam, ax_island]
    ax.xgridcolor = RGBf(0.15, 0.15, 0.2)
    ax.ygridcolor = RGBf(0.15, 0.15, 0.2)
end
colgap!(fig.layout, 10)
rowgap!(fig.layout, 8)

# ── Save ───────────────────────────────────────────────────────────────
save("docs/awes-forum-diagrams/v10-trajectories.png", fig)
println("Saved docs/awes-forum-diagrams/v10-trajectories.png")
