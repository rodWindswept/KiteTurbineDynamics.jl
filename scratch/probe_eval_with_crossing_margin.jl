# scratch/probe_eval_with_crossing_margin.jl
using KiteTurbineDynamics
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "test_physics_path_ode.jl"))

println("Testing evaluate_windowed under current working tree...")
res, threw = evaluate_current()
println("Threw: ", threw)
if res !== nothing
    println("Status: ", res.status)
    println("P_mean: ", res.P_mean)
    println("FoS_min: ", res.FoS_min)
    println("twist_crossed: ", res.twist_crossed)
    println("max_ratio: ", res.max_ratio)
end
