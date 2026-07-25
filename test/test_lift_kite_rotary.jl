# test/test_lift_kite_rotary.jl
# Verify RotaryLifter force model (uses PCA-2 from CoaxialAutogyroStacking)

@testset "RotaryLifter force" begin
    lifter = rotary_lifter_default()
    rho = 1.225

    # ── Produces lift at zero wind (ω·r > 0 gives apparent wind) ────────────
    F_hub0, T0, elev0 = lift_force_steady(lifter, rho, 0.0)
    @test T0 > 0.0           # tension even at zero wind
    @test elev0 > 0.0        # elevation angle is valid

    # ── Lift increases with wind speed ──────────────────────────────────────
    _, T5, _ = lift_force_steady(lifter, rho, 5.0)
    _, T10, _ = lift_force_steady(lifter, rho, 10.0)
    @test T10 > T5 > T0      # monotonic with wind

    # ── Larger rotor → more lift ────────────────────────────────────────────
    big = RotaryLifterParams(3.0, 0.3, 3, 0.15, 1.0, 0.08, 33.0, 25.0, 200_000.0, 4.0)
    _, T_big, _ = lift_force_steady(big, rho, 8.0)
    _, T_norm, _ = lift_force_steady(lifter, rho, 8.0)
    @test T_big > T_norm    # 2× radius → ~4× area → more lift
end
