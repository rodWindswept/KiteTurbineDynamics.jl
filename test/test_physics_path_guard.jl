# test/test_physics_path_guard.jl
# Permanent guard: verifies that the static objective (objective_v10)
# output differs between LEGACY and DEFAULT physics on a reference design.
# A refactor that decouples the static solver from the shared force model
# would silently revert the physics compass — this assertion makes it loud.

using Test
using KiteTurbineDynamics

@testset "physics-path guard — static objective reaches physics toggles" begin
    # Reference genome: 12-gon design known to produce feasible output
    x = zeros(14)
    x[1]  = 0.075   # Do_top
    x[2]  = 0.01    # t_over_D
    x[3]  = 1.0     # beam_aspect
    x[4]  = 0.5     # Do_scale_exp
    x[5]  = 3.7     # r_hub
    x[6]  = 2.0     # r_bottom
    x[7]  = 2.5     # target_Lr
    x[8]  = 12.0    # n_lines
    x[9]  = 0.0     # density_profile
    x[10] = 8.0     # rotor_mask proxy
    x[11] = 15.0    # bank_top
    x[12] = 5.0     # bank_bottom
    x[13] = 0.5     # lambda_top
    x[14] = 0.3     # lambda_bottom

    p = params_v5_50kw()
    beam = PROFILE_ELLIPTICAL

    # ── Evaluate under DEFAULT physics (all flags ON) ──────────────────
    # Default state after module load: all true
    set_expansion_physics!(ExpansionPhysics(true, true, true))
    f_default = objective_v10(x, beam, p)
    @test isfinite(f_default)

    # ── Evaluate under LEGACY physics (all flags OFF) ──────────────────
    set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)
    f_legacy = objective_v10(x, beam, p)
    # Legacy may produce Inf on this genome — that's a valid "different" result

    # ── RESTORE default physics ────────────────────────────────────────
    set_expansion_physics!(ExpansionPhysics(true, true, true))

    # ── The guard ──────────────────────────────────────────────────────
    @test !isfinite(f_legacy) || f_default != f_legacy

    # Document the actual values for audit
    println("Physics-path guard: f_default=$(round(f_default, digits=1))  f_legacy=$(round(f_legacy, digits=1))")
end
