# test/test_airborne_fos.jl — regression for the 2026-08-25 off-by-one FoS bug.
#
# ring_element_analysis strips the ground ring AND the hub
# (sys.ring_ids[2:end-1]), so ef.ring_fos[1] is the lowest FLOATING ring — e.g.
# the transmission-cylinder ring in the three-section geometry — NOT the ground
# ring.  The old inline `for i in 2:length(ring_fos)` skipped it, hiding a
# buckled ring (FoS 0.57) behind the top-ring FoS (67.54) and letting
# structurally-invalid designs pass fos_hard.
#
# min_airborne_fos is now the single authority used by min_ring_fos,
# evaluate_windowed and objective_evaluator_ramp.  These tests pin the
# "index 1 is included" contract so the off-by-one cannot silently return.
using Test
using KiteTurbineDynamics

@testset "min_airborne_fos — includes index 1 (off-by-one regression)" begin
    f = KiteTurbineDynamics.min_airborne_fos

    # The bug case: the buckled lowest ring must be the reported minimum.
    fos, idx = f([0.57, 67.54])
    @test fos ≈ 0.57
    @test idx == 1

    # Minimum not at index 1 — index tracking stays correct.
    fos, idx = f([5.0, 2.0, 3.0])
    @test fos ≈ 2.0
    @test idx == 2

    # Invalid entries (NaN/Inf/≤0) are ignored, index still tracked.
    fos, idx = f([Inf, 2.0, NaN, -1.0])
    @test fos ≈ 2.0
    @test idx == 2

    # No valid entries -> (Inf, 0).
    fos, idx = f([Inf, NaN, 0.0])
    @test fos == Inf
    @test idx == 0

    # Empty vector -> (Inf, 0).
    fos, idx = f(Float64[])
    @test fos == Inf
    @test idx == 0
end

println("\n✓ airborne-FoS off-by-one regression tests complete")
