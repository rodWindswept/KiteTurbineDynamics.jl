using Test
using KiteTurbineDynamics

# test/test_system_defaults.jl
# Static guards for two SystemParams / controller defaults that carried only
# behavioural cover (audit 2026-09-08, recommendations 3):
#
#   ζ (2026-08-12): a hardcoded 1.5 structural damper, rectified through the
#   rope model, produced a DC reverse torque and parked the rotor at −ω. ζ is
#   now a SystemParams field defaulted to 0.05. The suite had ZERO references
#   to zeta, so a silent re-hardcode would pass every test.
#
#   GeneratorLoadMode (2026-08-16): legacy `:mppt` must stay the default (all
#   existing campaigns are bit-identical under it), and the measured-load
#   modes must honour `omega_floor` — below it (including a reversed ring)
#   τ = 0, the real VESC "Too Slow 4 gen" behaviour. Without the floor the
#   load locks a reversed ring at τ_cap and the sim stalls at low wind.

@testset "system defaults — ζ promotion (2026-08-12)" begin
    # ζ is injected by the grouped-spec constructor at 0.05, not inherited
    # from a factory literal. Check both anchors: the legacy 10 kW machine and
    # the Daisy anchor the v13 campaign derives from.
    @test params_10kw().zeta == 0.05
    @test params_daisy().zeta == 0.05

    # The banned value itself: 1.5 was the reverse-torque source.
    @test params_10kw().zeta != 1.5
end

@testset "generator-load mode defaults (2026-08-16)" begin
    gl = GeneratorLoadMode()
    @test gl.mode === :mppt        # legacy MPPT is the default path
    @test gl.omega_floor == 0.0    # no floor unless a measured mode sets one
    @test gl.tau_cap == 0.0        # no cap unless set
end

@testset "generator-load floor: measured modes deliver no reverse torque" begin
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    N = sys.n_total
    Nr = sys.n_ring
    gnd_idx = 6N + Nr + 1          # ground-ring ω (layout: 6N + Nr + ring_idx)
    u = copy(u0)
    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]

    prev = KiteTurbineDynamics.GENERATOR_LOAD[]
    try
        # Measured τ(ω) table with a 2 rad/s floor.
        set_generator_load!(
            GeneratorLoadMode(;
                mode=:table,
                omega_pts=[1.0, 10.0],
                tau_pts=[5.0, 20.0],
                tau_cap=25.0,
                omega_floor=2.0,
            ),
        )

        # Reversed ring (ω < 0 ≤ floor) → τ = 0, never a cap-locked reverse load.
        u[gnd_idx] = -3.0
        tau_rev, _ = get_generator_torque(u, sys, p, 0.0, wind_fn; brake_engaged=false)
        @test tau_rev == 0.0

        # At the floor exactly → τ = 0 (the ≤ boundary).
        u[gnd_idx] = 2.0
        tau_floor, _ = get_generator_torque(u, sys, p, 0.0, wind_fn; brake_engaged=false)
        @test tau_floor == 0.0

        # Above the floor → interpolated τ, flat outside the knots, capped.
        u[gnd_idx] = 10.0
        tau_hi, _ = get_generator_torque(u, sys, p, 0.0, wind_fn; brake_engaged=false)
        @test tau_hi == 20.0
        u[gnd_idx] = 20.0
        tau_flat, _ = get_generator_torque(u, sys, p, 0.0, wind_fn; brake_engaged=false)
        @test tau_flat == 20.0

        # :const_power honours the same floor.
        set_generator_load!(
            GeneratorLoadMode(; mode=:const_power, p_set=300.0, omega_floor=2.0)
        )
        u[gnd_idx] = -5.0
        tau_cp_rev, _ = get_generator_torque(u, sys, p, 0.0, wind_fn; brake_engaged=false)
        @test tau_cp_rev == 0.0
        u[gnd_idx] = 10.0
        tau_cp, _ = get_generator_torque(u, sys, p, 0.0, wind_fn; brake_engaged=false)
        @test tau_cp ≈ 300.0 / 10.0
    finally
        set_generator_load!(prev)   # never leak a measured mode into other tests
    end
end
