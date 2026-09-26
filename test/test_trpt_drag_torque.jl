# test/test_trpt_drag_torque.jl
#
# T1 and T2 of docs/plans/2026-09-26-trpt-drag-torque-fix.md.
#
# The defect: the tether drag was added to node forces and never to the ring torque
# accumulator. The ring spin reads the accumulator only, so the drag could not
# resist the rotation.
#
# T1 checks the moment helper against hand cases.
# T2 checks the wiring, and it fails before the fix. It spins a whole system with
# zero wind and reads the ring torques. Every intermediate ring must gain a
# negative torque from that spin alone.
#
# The test is a difference, not an absolute. The spin state is a rigid rotation,
# so the strain does not change, so the tension contribution cancels.

using LinearAlgebra

@testset "TRPT drag torque reaches the shaft" begin
    @testset "T1 the moment helper" begin
        z = [0.0, 0.0, 1.0]
        r = [1.0, 0.0, 0.0]     # moment arm: 1 m along x, ring radius 1 m
        Ft = [0.0, 3.0, 0.0]    # a tangential force, 3 N

        # (r x F)_z = r_x F_y - r_y F_x = 1 * 3 - 0 = 3
        @test KiteTurbineDynamics.shaft_moment(r, Ft, z) ≈ 3.0

        # A force along the moment arm makes no moment about the shaft.
        @test abs(KiteTurbineDynamics.shaft_moment(r, [3.0, 0.0, 0.0], z)) < 1e-12

        # A force along the shaft makes no moment about the shaft.
        @test abs(KiteTurbineDynamics.shaft_moment(r, z, z)) < 1e-12

        # The opposite side of the ring reverses the sign.
        @test KiteTurbineDynamics.shaft_moment([-1.0, 0.0, 0.0], Ft, z) ≈ -3.0

        # A radial arm and a tangential force at 2 m give twice the moment.
        @test KiteTurbineDynamics.shaft_moment([2.0, 0.0, 0.0], Ft, z) ≈ 6.0
    end

    @testset "T2 the drag wiring, from the ring torque" begin
        p = params_10kw()
        sys, u0 = build_kite_turbine_system(p)
        N, Nr = sys.n_total, sys.n_ring
        zero_wind = (pos, t) -> [0.0, 0.0, 0.0]
        alpha0 = zeros(Nr)

        # Shaft axis and origin from the two end rings. No assumption about +z.
        c_ground = u0[(3 * (sys.ring_ids[1] - 1) + 1):(3 * sys.ring_ids[1])]
        c_hub = u0[(3 * (sys.ring_ids[Nr] - 1) + 1):(3 * sys.ring_ids[Nr])]
        axis = normalize(c_hub .- c_ground)
        origin = copy(c_ground)

        # A rigid rotation of the whole structure about the shaft axis. Every node
        # takes omega x (p - origin). The ring centres lie on the axis, so their
        # own velocity is zero, as in the simulation.
        function spin_state(omega)
            u = copy(u0)
            for i in 1:N
                pp = @view u[(3 * (i - 1) + 1):(3 * i)]
                vv = omega .* cross(axis, pp .- origin)
                @views u[(3N + 3 * (i - 1) + 1):(3N + 3 * i)] .= vv
            end
            return u
        end

        function ring_torques(u)
            f = [zeros(3) for _ in 1:N]
            tau = zeros(Nr)
            compute_rope_forces!(f, tau, u, alpha0, sys, p, zero_wind, 0.0)
            return tau
        end

        tau_rest = ring_torques(u0)
        tau_spin = ring_torques(spin_state(10.0))
        tau_fast = ring_torques(spin_state(20.0))

        # The drag only. The strain is identical in both states, so the tension
        # contribution cancels and the remainder is the aerodynamic drag.
        d_spin = tau_spin .- tau_rest
        d_fast = tau_fast .- tau_rest

        # A. Every intermediate ring feels the drag. A one-sided fix, on the upper
        #    end of a bay only or the lower end only, fails here.
        for i in 2:(Nr - 1)
            @test abs(d_spin[i]) > 1e-9
        end

        # B. The drag opposes the rotation.
        @test sum(d_spin) < 0.0

        # C. The drag grows with the square of the spin rate. The tolerance is
        #    loose because the rope damping term grows linearly and rides along in
        #    the same difference.
        @test isapprox(sum(d_fast), 4.0 * sum(d_spin); rtol = 0.25)

        # D. A machine at rest in still air has no drag.
        @test maximum(abs.(tau_rest)) < 1e-6
    end
end
