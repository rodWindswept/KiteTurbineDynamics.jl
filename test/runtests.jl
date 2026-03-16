using Test
using KiteTurbineDynamics

@testset "KiteTurbineDynamics" begin
    include("test_parameters.jl")
    include("test_aerodynamics.jl")
    include("test_types.jl")
    include("test_geometry.jl")
    include("test_rope_forces.jl")
    include("test_ring_forces.jl")
    include("test_dynamics.jl")
    include("test_static_equilibrium.jl")
    include("test_rope_sag.jl")
    include("test_emergent_torsion.jl")
    include("test_power.jl")
end
