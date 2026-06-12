using KiteTurbineDynamics, LinearAlgebra

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
ld = rotary_lifter_default()
ω = cbrt(p.p_rated_w / p.k_mppt)
wf = (pos, t) -> [11.0, 0.0, 0.0]

function my_settle(n_op, damp_op)
    u_start = KiteTurbineDynamics.settle_to_equilibrium(
        sys, u0, p; lift_device=ld, wind_fn=wf
    )

    # manual bisection/omega
    N = sys.n_total;
    Nr = sys.n_ring
    for ri in 1:Nr
        u_start[6N + Nr + ri] = ω
    end

    dt_op = 4e-5
    du2 = zeros(length(u_start))
    ode_params = (sys, p, wf, ld)

    for _ in 1:n_op
        fill!(du2, 0.0)
        multibody_ode!(du2, u_start, ode_params, 0.0)
        @views u_start[(3N + 1):6N] .+= dt_op .* du2[(3N + 1):6N]
        @views u_start[1:3N] .+= dt_op .* u_start[(3N + 1):6N]
        @views u_start[(3N + 1):6N] .*= damp_op
        @views u_start[(6N + Nr + 1):(6N + 2Nr)] .= ω
        u_start[1:3] .= 0.0;
        u_start[(3N + 1):(3N + 3)] .= 0.0
    end

    fill!(du2, 0.0)
    multibody_ode!(du2, u_start, ode_params, 0.0)

    bacc = du2[(3N + 3 * (sys.bearing_id - 1) + 1):(3N + 3 * sys.bearing_id)]
    sacc = du2[(3N + 3 * (sys.sky_anchor_id - 1) + 1):(3N + 3 * sys.sky_anchor_id)]

    return bacc, sacc
end

println("8000, 0.15: ", my_settle(8000, 0.15))
println("8000, 0.5: ", my_settle(8000, 0.5))
println("40000, 0.15: ", my_settle(40000, 0.15))
println("100000, 0.15: ", my_settle(100000, 0.15))
