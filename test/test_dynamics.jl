@testset "ODE smoke test" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)

    wind_fn = (pos, t) -> [0.0, 0.0, 0.0]  # zero wind
    du      = zeros(state_size(sys))

    # Should not throw
    @test_nowarn multibody_ode!(du, u0, (sys, p, wind_fn), 0.0)

    # du should not contain NaN or Inf
    @test all(isfinite, du)
end
