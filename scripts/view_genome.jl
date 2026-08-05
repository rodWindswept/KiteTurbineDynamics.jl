#!/usr/bin/env julia
# scripts/view_genome.jl — Launch interactive dashboard for a specific genome from campaign CSV
using KiteTurbineDynamics, CSV, DataFrames, GLMakie, LinearAlgebra, Printf

csv_path = length(ARGS) >= 1 ? ARGS[1] : "scripts/results/recampaign/feasibility_phase_a_v2.csv"
hash_filter = length(ARGS) >= 2 ? ARGS[2] : ""

df = CSV.read(csv_path, DataFrame; comment="#")
if !isempty(hash_filter)
    idx = findfirst(df.genome_hash .== hash_filter)
    idx === nothing && error("Genome hash not found: $hash_filter")
    row = df[idx, :]
else
    sort!(df, :f_feas)
    row = first(df)
end

x = [row.x1, row.x2, row.x3, row.x4, row.x5, row.x6, row.x7, row.x8,
     row.x9, row.x10, row.x11, row.x12, row.x13, row.x14, row.x15]

println("Genome: $(row.genome_hash[1:16])")
println("  P=$(round(row.P_mean_kw; digits=1)) kW  FoS=$(round(row.FoS_min; digits=3))")
println("  n_lines=$(row.n_lines)  n_active=$(row.n_active)  gen=$(row.gen)")
println("  f_feas=$(round(row.f_feas; digits=4))  tier=$(row.tier)")

p = params_v5_50kw()
result = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; max_ground_radius=5.0, power_W=50000.0)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, 10.0^x[15])
label_str = "Genome $(row.genome_hash[1:8])"

println("System: $(sys.n_total) nodes, $(sys.n_ring) rings, n_lines=$(result.design.n_lines)")
println("Opening GLMakie dashboard...")

# Settle to operational state
function wf(pos, t)
    z = max(pos[3], 1.0)
    return [11.0 * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
end

u_settled = settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf)
println("Settled. Launching dashboard...")

# Run short sim to capture initial frame
total_n = round(Int, 10.0 / 4e-5)  # 10s at 4e-5 dt
run_canonical_sim!(u_settled, sys, pc, wf, total_n, 4e-5;
    lift_device=nothing, lin_damp=0.05)

# The GLMakie window from the dashboard build stays open until user closes it
# (The dashboard's main rendering is in interactive_dashboard.jl which we can't easily reuse)
# Instead, print key geometry for the user
println("\nDesign geometry:")
println("  r_hub = $(round(result.design.r_hub; digits=3)) m")
println("  r_bottom = $(round(result.design.r_bottom; digits=3)) m")
println("  tether_length = $(round(result.design.tether_length; digits=1)) m")
println("  target_Lr = $(round(result.design.target_Lr; digits=2))")
println("  density_profile = $(round(result.design.density_profile; digits=3))")
println("  n_rings = $(result.n_rings)")
println("  Expansion rotors: $(length(result.rotors)) active ($(result.n_active))")
for (i, rotor) in enumerate(result.rotors)
    println("    rotor $i: ring=$(rotor.ring_idx) bank=$(round(rotor.bank_angle_deg; digits=1)) deg  blade_scale=$(round(rotor.blade_scale; digits=3))  tip_radius=$(round(rotor.blade_tip_radius; digits=2)) m")
end
