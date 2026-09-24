using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "test_physics_path_ode.jl"))

# In this test, we test evaluate_windowed with an override or by testing F_top at 1350 N.
println("Testing evaluate_windowed with F_top = 1350 N preload enforcement...")

# Let us check evaluate_current()
# But wait, what if we temporarily make design_axial_preload enforce crossing limit?
