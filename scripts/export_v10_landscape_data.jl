#!/usr/bin/env julia
# scripts/export_v10_landscape_data.jl
# Export PCA-projected campaign data for Python matplotlib rendering

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, CSV, DataFrames, Statistics, LinearAlgebra, DelimitedFiles

const RD = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw")

println("Loading...")
ch = CSV.read(joinpath(RD, "convergence_history.csv"), DataFrame)
pt = CSV.read(joinpath(RD, "parameter_trace.csv"), DataFrame)
pca_mean = vec(readdlm("/tmp/v10_pca_mean.txt"))
pca_std  = vec(readdlm("/tmp/v10_pca_std.txt"))
pca_V    = readdlm("/tmp/v10_pca_V.txt")

function pc_proj(row)
    x = [row.Do_top_m, row.t_over_D, row.beam_aspect, row.Do_scale_exp,
         row.r_hub_m, row.r_bottom_m, row.target_Lr, row.n_lines,
         row.density_profile, row.rotor_mask_proxy, row.bank_top, row.bank_bottom,
         hasproperty(row, :blade_scale_top) ? row.blade_scale_top : row.lambda_top,
         hasproperty(row, :blade_scale_bottom) ? row.blade_scale_bottom : row.lambda_bottom]
    xc = (x .- pca_mean) ./ max.(pca_std, 1e-10)
    (dot(xc, pca_V[:,1]), dot(xc, pca_V[:,2]))
end

# Export all feasible points (sample every 3rd)
println("Exporting points...")
pc1_a, pc2_a, mass_a = Float64[], Float64[], Float64[]
for i in 1:3:nrow(pt)
    pc1, pc2 = pc_proj(pt[i, :])
    cm = ch[(ch.island .== pt[i,:island]) .& (ch.iteration .== pt[i,:iteration]), :]
    mass = nrow(cm) > 0 ? cm.mass_kg[1] : NaN
    if mass < 200.0
        push!(pc1_a, pc1); push!(pc2_a, pc2); push!(mass_a, mass)
    end
end
writedlm("/tmp/v10_pc1.txt", pc1_a)
writedlm("/tmp/v10_pc2.txt", pc2_a)
writedlm("/tmp/v10_mass.txt", mass_a)
println("  $(length(pc1_a)) points")

# Export trajectories
println("Exporting trajectories...")
for island in sort(unique(pt.island))
    pt_i = pt[pt.island .== island, :]
    if nrow(pt_i) < 50; continue; end
    open("/tmp/v10_traj_$island.txt", "w") do f
        for k in 1:10:nrow(pt_i)
            pc1, pc2 = pc_proj(pt_i[k, :])
            cm = ch[(ch.island .== island) .& (ch.iteration .== pt_i[k,:iteration]), :]
            mass = nrow(cm) > 0 ? cm.mass_kg[1] : NaN
            if mass < 200.0
                writedlm(f, [pc1 pc2 mass])
            end
        end
    end
end
println("Done — $(length(unique(pt.island))) islands exported to /tmp/v10_traj_*.txt")
