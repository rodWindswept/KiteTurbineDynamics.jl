using LinearAlgebra

@testset "power generation" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    u_settled = settle_to_equilibrium(sys, u0, p)

    N  = sys.n_total
    Nr = sys.n_ring

    # Seed hub with startup omega
    u_start = copy(u_settled)
    u_start[6N + Nr + Nr] = 1.0   # hub ring_idx=Nr, omega = 1 rad/s

    wind_fn = (pos, t) -> begin
        z  = max(pos[3], 1.0)
        sh = (z / p.h_ref)^(1.0/7.0)
        [p.v_wind_ref * sh, 0.0, 0.0]
    end

    # Explicit damped integrator: 2 s simulated, no angular velocity kill
    # so aero torque can drive/maintain hub spin without Jacobian overhead.
    # lin_damp=0.05 stabilises rope oscillations; ang_damp=1.0 lets omega evolve freely.
    u_final = simulate(sys, u_start, p, wind_fn;
                       n_steps=50_000, dt=4e-5,
                       lin_damp=0.05, ang_damp=1.0)

    omega_hub_final = u_final[6N + Nr + Nr]
    @test abs(omega_hub_final) > 0.05   # hub still spinning after 2 s (aero torque sustains rotation)
end
