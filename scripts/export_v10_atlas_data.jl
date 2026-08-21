#!/usr/bin/env julia
# scripts/export_v10_atlas_data.jl
# Export PCA-projected campaign data with all parameters for multi-panel atlas

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

# Map rotor_mask to n_active for visualization
function decode_n_rotors(proxy)
    idx = clamp(round(Int, proxy), 0, N_VALID_MASKS - 1)
    mask = VALID_ROTOR_MASKS[idx + 1]
    return count_ones(mask)
end

# Export full dataset with per-parameter fields (sample every 3rd)
println("Exporting atlas data...")
open("/tmp/v10_atlas.csv", "w") do f
    write(f, "pc1,pc2,mass,n_lines,n_rotors,r_hub,r_bottom,bank_top,blade_scale_top,t_over_D,target_Lr,Do_top\n")
    for i in 1:3:nrow(pt)
        row = pt[i, :]
        pc1, pc2 = pc_proj(row)
        cm = ch[(ch.island .== row.island) .& (ch.iteration .== row.iteration), :]
        mass = nrow(cm) > 0 ? cm.mass_kg[1] : NaN
        if mass < 200.0
            n_rotors = decode_n_rotors(row.rotor_mask_proxy)
            write(f, "$pc1,$pc2,$mass,$(row.n_lines),$n_rotors,")
            write(f, "$(row.r_hub_m),$(row.r_bottom_m),$(row.bank_top),")
            write(f, "$(hasproperty(row, :blade_scale_top) ? row.blade_scale_top : row.lambda_top),$(row.t_over_D),$(row.target_Lr),$(row.Do_top_m)\n")
        end
    end
end

println("Atlas data exported to /tmp/v10_atlas.csv")
println("Columns: pc1,pc2,mass,n_lines,n_rotors,r_hub,r_bottom,bank_top,blade_scale_top,t_over_D,target_Lr,Do_top")
