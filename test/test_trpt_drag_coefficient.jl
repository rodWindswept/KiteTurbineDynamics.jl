# test/test_trpt_drag_coefficient.jl
#
# T1 to T4 of docs/plans/2026-09-26-tether-drag-coefficient-setting.md (Ruling 3).
#
# The tether drag coefficient becomes a per-case setting. Three named values exist:
#
#   :legacy_default   1.0   the value every campaign before 2026-09-26 used
#   :physical_line    1.2   the printed value for a cylinder in crossflow
#   :daisy_lumped     2.7   the printed best fit to Daisy, a lumped value that
#                           absorbs the ring drag and the bridle drag the printed
#                           model omits
#
# The setting must carry its meaning, so a reader returns the value and the name
# together.
#
# The proportionality test is written to isolate the coefficient. Every measured
# quantity below is a DIFFERENCE between two settings of the same state, so the
# elastic tension cancels (it depends on positions only) and the rope material
# damping cancels (it is the same in both calls). What remains is linear in CD.
#
# Each testset restores the setting in a `finally`, so the fast suite cannot leak
# a coefficient into the tests that follow.

using LinearAlgebra

@testset "tether drag coefficient is a per-case setting" begin
    D = KiteTurbineDynamics

    @testset "T4 the named settings" begin
        saved = D.tether_drag_model()
        try
            @test D.set_tether_drag!(:physical_line) ≈ 1.2
            @test D.tether_drag_cd() ≈ 1.2
            @test D.tether_drag_model()[2] === :physical_line

            @test D.set_tether_drag!(:daisy_lumped) ≈ 2.7
            @test D.tether_drag_cd() ≈ 2.7
            @test D.tether_drag_model()[2] === :daisy_lumped

            # An unknown name refuses. It must not fall back to a value, because a
            # silent fallback would stamp a wrong coefficient into a campaign.
            @test_throws ErrorException D.set_tether_drag!(:nonsense)

            # The refusal leaves the previous setting in place.
            @test D.tether_drag_cd() ≈ 2.7
        finally
            D.set_tether_drag!(saved[2])
        end
    end

    @testset "T2 the default does not drift" begin
        # A fresh read equals the constant, with no test having set anything.
        @test D.tether_drag_cd() == D.TETHER_DRAG_CD
        @test D.tether_drag_model()[1] == D.TETHER_DRAG_CD
        @test D.tether_drag_model()[2] === :legacy_default
    end

    @testset "T1 the ODE drag torque follows CD" begin
        saved = D.tether_drag_model()
        try
            p = params_10kw()
            sys, u0 = build_kite_turbine_system(p)
            N, Nr = sys.n_total, sys.n_ring
            zero_wind = (pos, t) -> [0.0, 0.0, 0.0]
            alpha0 = zeros(Nr)

            c_ground = u0[(3 * (sys.ring_ids[1] - 1) + 1):(3 * sys.ring_ids[1])]
            c_hub = u0[(3 * (sys.ring_ids[Nr] - 1) + 1):(3 * sys.ring_ids[Nr])]
            axis = normalize(c_hub .- c_ground)
            origin = copy(c_ground)

            # A rigid rotation about the shaft axis. The strain is identical at every
            # spin rate, so the tension cancels between any two calls.
            function spin_state(omega)
                u = copy(u0)
                for i in 1:N
                    pp = @view u[(3 * (i - 1) + 1):(3 * i)]
                    vv = omega .* cross(axis, pp .- origin)
                    @views u[(3N + 3 * (i - 1) + 1):(3N + 3 * i)] .= vv
                end
                return u
            end

            # The ring torque from the drag at one coefficient, spin minus rest.
            function drag_torque(omega)
                f = [zeros(3) for _ in 1:N]
                tau = zeros(Nr)
                compute_rope_forces!(f, tau, spin_state(omega), alpha0, sys, p, zero_wind, 0.0)
                return sum(tau)
            end

            D.set_tether_drag!(:legacy_default)   # CD 1.0
            d_lo = drag_torque(10.0) - drag_torque(0.0)
            D.set_tether_drag!(:physical_line)    # CD 1.2
            d_mid = drag_torque(10.0) - drag_torque(0.0)
            D.set_tether_drag!(:daisy_lumped)     # CD 2.7
            d_hi = drag_torque(10.0) - drag_torque(0.0)

            # The drag opposes the rotation at every setting.
            @test d_lo < 0.0
            @test d_hi < 0.0

            # A heavier coefficient means more drag, so a more negative torque.
            @test d_hi < d_mid < d_lo

            # Linear in CD. The increments are chosen so the damping and the tension
            # cancel: inc_lo is the drag at a CD step of 0.2, inc_hi at a step of 1.5.
            # The ratio of the increments is 1.5 / 0.2 = 7.5, and it holds with no
            # assumption about the size of the damping.
            inc_lo = d_mid - d_lo
            inc_hi = d_hi - d_mid
            @test isapprox(inc_hi / inc_lo, 7.5; rtol = 0.02)
        finally
            D.set_tether_drag!(saved[2])
        end
    end

    @testset "T3 the screen loss follows CD" begin
        saved = D.tether_drag_model()
        try
            p = params_10kw()
            sys, u0 = build_kite_turbine_system(p)
            omega = 10.0

            D.set_tether_drag!(:legacy_default)
            s_lo = D.settle_parasitic_drag_power(sys, p, omega, u0)
            D.set_tether_drag!(:physical_line)
            s_mid = D.settle_parasitic_drag_power(sys, p, omega, u0)
            D.set_tether_drag!(:daisy_lumped)
            s_hi = D.settle_parasitic_drag_power(sys, p, omega, u0)

            # The screen also carries the ring beam drag and the expansion blade drag,
            # neither of which depends on the tether coefficient. The increments cancel
            # them, so the same 7.5 ratio appears.
            inc_lo = s_mid - s_lo
            inc_hi = s_hi - s_mid
            @test inc_lo > 0.0
            @test isapprox(inc_hi / inc_lo, 7.5; rtol = 0.02)
        finally
            D.set_tether_drag!(saved[2])
        end
    end
end
