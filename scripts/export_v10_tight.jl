#!/usr/bin/env julia
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, CSV, DataFrames, Statistics, LinearAlgebra, DelimitedFiles

pt = CSV.read("scripts/results/v10_campaign_50kw/parameter_trace.csv", DataFrame)
ch = CSV.read("scripts/results/v10_campaign_50kw/convergence_history.csv", DataFrame)
println("Trace: $(nrow(pt)) rows, History: $(nrow(ch)) rows")

joined = innerjoin(pt, ch, on=[:island, :iteration])
feas = joined[joined.mass_kg .< 1000, :]
println("Feasible: $(nrow(feas)) rows")

param_cols = ["Do_top_m", "t_over_D", "beam_aspect", "Do_scale_exp",
              "r_hub_m", "r_bottom_m", "target_Lr", "n_lines",
              "density_profile", "rotor_mask_proxy", "bank_top", "bank_bottom",
              "lambda_top", "lambda_bottom"]
X = Matrix(feas[:, param_cols])
X_mean = vec(mean(X, dims=1))
X_std = vec(std(X, dims=1))
X_std[X_std .< 1e-12] .= 1.0
X_scaled = (X .- X_mean') ./ X_std'
U, S, Vt = svd(X_scaled)
explained = S.^2 ./ sum(S.^2)
println("PC1: $(round(explained[1]*100,digits=1))% PC2: $(round(explained[2]*100,digits=1))%")

PC = X_scaled * Vt'
pc1 = PC[:,1]; pc2 = PC[:,2]

writedlm("/tmp/v10_tight_pc1.txt", pc1)
writedlm("/tmp/v10_tight_pc2.txt", pc2)
writedlm("/tmp/v10_tight_mass.txt", feas.mass_kg)
writedlm("/tmp/v10_tight_pca_mean.txt", X_mean)
writedlm("/tmp/v10_tight_pca_std.txt", X_std)
writedlm("/tmp/v10_tight_pca_V.txt", Vt')
writedlm("/tmp/v10_tight_pca_var.txt", explained[1:4])

open("/tmp/v10_tight_atlas.csv", "w") do f
    write(f, "pc1,pc2,mass,n_lines,n_rotors,r_hub,r_bottom,bank_top,lambda_top,t_over_D,target_Lr,Do_top\n")
    for i in 1:3:nrow(feas)
        mask_proxy = feas.rotor_mask_proxy[i]
        idx = clamp(round(Int, mask_proxy), 0, N_VALID_MASKS - 1)
        mask = VALID_ROTOR_MASKS[idx + 1]
        n_rotors = count_ones(mask)
        write(f, "$(pc1[i]),$(pc2[i]),$(feas.mass_kg[i]),$(round(feas.n_lines[i])),$n_rotors,")
        write(f, "$(feas.r_hub_m[i]),$(feas.r_bottom_m[i]),$(feas.bank_top[i]),")
        write(f, "$(feas.lambda_top[i]),$(feas.t_over_D[i]),$(feas.target_Lr[i]),$(feas.Do_top_m[i])\n")
    end
end
println("Exported $(div(nrow(feas),3)) atlas points")
