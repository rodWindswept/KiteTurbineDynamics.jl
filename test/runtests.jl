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
    include("test_aerodynamics.jl")
    include("test_back_line_element.jl")
    include("test_dt_guard.jl")
    include("test_bem_unified.jl")
    include("test_blade_geometry.jl")
    include("test_blade_mass_law.jl")
    include("test_campaign_k_alignment.jl")
    include("test_golden_traces.jl")
    include("test_expansion_rotor.jl")
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
    include("test_fos_guard.jl")
    include("test_airborne_fos.jl")
    include("test_wind_blocking.jl")
    include("test_objective_v11.jl")
    include("test_objective_v12.jl")
    include("test_lift_kite_rotary.jl")
    include("test_lift_kite_stacked.jl")
    include("test_mass_model_2026_09.jl")
    include("test_settle_blocking_2026_09.jl")
    include("test_settle_preload_consistency.jl")
    include("test_trpt_realisability.jl")   # 2026-09-13: the torsional cliff must RAISE, not clamp
    include("test_trpt_twist_limit.jl")     # 2026-09-25: the over-twist authority, Tulloch (4.34)
    include("test_trpt_reference.jl")       # 2026-09-26: the printed reference values, pages 198-201
    include("test_trpt_drag_torque.jl")     # 2026-09-26: the drag moment must reach the ring spin
    include("test_trpt_drag_coefficient.jl") # 2026-09-26: the drag coefficient is a per-case setting
    include("test_settle_validity.jl")   # 2026-09-12: taut chain + force balance + smooth handoff
    include("test_fitness_appropriateness_2026_09.jl")
    include("test_system_defaults.jl")
    include("test_beam_sizing_closed_form.jl")
    include("test_rope_resolution.jl")
end
