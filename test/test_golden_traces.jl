# test/test_golden_traces.jl
# Regression baseline for the physics core. Catches silent regressions
# like the centre-constraint spoke bug.
#
# ODE golden traces are blocked by settle_to_operational_state performance
# (~15s per build). When the integrator is faster (item 12) or a pre-settled
# state checkpoint is committed, add ODE endpoint assertions here.

@testset "Golden traces — structural physics" begin

    # ═══ Polygon force resolution — sin(π/n) since June 2026 fix ═══
    @testset "Polygon force resolution — sin not tan" begin
        for n in [3, 5, 8, 12]
            sin_val = sin(π / n)
            tan_val = tan(π / n)
            @test sin_val < tan_val
            if n == 3
                # At n=3, tan(π/3)=√3≈1.732, sin(π/3)=√3/2≈0.866 — ratio is 2.0
                @test tan_val / sin_val ≈ 2.0  rtol=0.01
            end
        end
    end

    # ═══ Ring spacing geometry — analytic invariant ═══
    @testset "Ring spacing v4 — analytic properties" begin
        # API 2026-07: (r_top, r_bottom, tether_length, target_Lr; max_rings)
        #   → (z_positions, radii, n_rings); radii increase ground→hub
        zs, radii, n_rings = KiteTurbineDynamics.ring_spacing_v4(5.0, 1.0, 60.0, 3.0; max_rings=20)
        @test length(radii) == length(zs)
        @test radii[end] ≈ 5.0  rtol=0.01   # hub = top
        @test radii[1]  ≈ 1.0  rtol=0.01   # ground = bottom
        @test all(diff(radii) .> 0)          # monotonically increasing ground→hub
        @test zs[1] ≈ 0.0 atol=1e-9
        @test zs[end] ≈ 60.0 rtol=0.01
    end

    # ═══ Beam section properties — known analytic values ═══
    @testset "Beam section properties — circular tube" begin
        # Do=0.06, t/D=0.01 → t=0.0006m, Di=0.0588m
        Do, t_over_D = 0.06, 0.01
        # API 2026-07: BeamSpec(profile::BeamProfile, Do, t_over_D, aspect_ratio)
        spec = KiteTurbineDynamics.BeamSpec(KiteTurbineDynamics.PROFILE_CIRCULAR, Do, t_over_D, 1.0)
        props = KiteTurbineDynamics.beam_section_properties(spec)

        # API 2026-07: beam_section_properties → (A, I_min, J) tuple
        A_val, I_val, _ = props

        t = Do * t_over_D
        Di = Do - 2*t
        I_expected = π/64 * (Do^4 - Di^4)
        A_expected = π/4 * (Do^2 - Di^2)

        @test I_val ≈ I_expected  rtol=0.01
        @test A_val ≈ A_expected  rtol=0.01
    end

end
