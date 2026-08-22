# test/runtests.jl — FAST UNIT SUITE (~3.5 min)
#
# UNIT TESTS ONLY. Static checks: geometry, BEM tables, parameters, types.
#
# The five ODE-heavy acceptance tests are NOT here. They live in
# test/acceptance_runtests.jl and run 20-30 s simulation windows each
# (~35 min sequential; ~18 min parallel). Do NOT wire them into this file.
#
# See DECISIONS.md [2026-08-20] "Test-suite split: fast unit vs slow acceptance".
#
# Run:  julia --project=. test/runtests.jl
using Test
using KiteTurbineDynamics

@testset "KiteTurbineDynamics" begin
    include("test_parameters.jl")
    include("test_aerodynamics.jl")
    include("test_bem_unified.jl")
    include("test_blade_geometry.jl")
    include("test_blade_mass_law.jl")
    include("test_golden_traces.jl")
    include("test_expansion_rotor.jl")
    include("test_expansion_stack.jl")
    include("test_expansion_analysis.jl")
    include("test_types.jl")
    include("test_geometry.jl")
    include("test_rope_forces.jl")
    include("test_ring_forces.jl")
    include("test_dynamics.jl")
    include("test_static_equilibrium.jl")
    include("test_rope_sag.jl")
    include("test_bearing_alignment.jl")
    include("test_emergent_torsion.jl")
    include("test_power.jl")
    include("test_trpt_axial_profiles.jl")
    include("test_ring_spacing_v4.jl")
    include("test_ring_element_analysis.jl")
    include("test_spacer_ring_design.jl")
    include("test_pitch_depower_sequence.jl")
    include("test_dashboard_smoke.jl")
    include("test_metric_consistency.jl")
    include("test_builders_v10.jl")
    include("test_expansion_induction.jl")
    include("test_physics_inertia_mass.jl")
    include("test_documented_claims.jl")
    include("test_objective_v11.jl")
    include("test_objective_v12.jl")
    include("test_physics_path_guard.jl")
    include("test_lift_kite_rotary.jl")
    include("test_lift_kite_stacked.jl")
end
