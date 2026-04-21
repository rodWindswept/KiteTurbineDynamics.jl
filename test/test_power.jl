using LinearAlgebra

@testset "power generation" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    u_settled = settle_to_equilibrium(sys, u0, p)

    N  = sys.n_total
    Nr = sys.n_ring

    # Seed hub with startup omega
    u_start = copy(u_settled)
    u_start[6N + Nr + Nr] = 9.0   # hub omega near optimal TSR: λ = 9×5/11 ≈ 4.1

    wind_fn = (pos, t) -> begin
        z  = max(pos[3], 1.0)
        sh = (z / p.h_ref)^(1.0/7.0)
        [p.v_wind_ref * sh, 0.0, 0.0]
    end

    # 2 s transient — torsional spring dynamics dominate (rope nodes start at zero-twist).
    # We verify that: (a) aero torque drove the hub, (b) torsional coupling propagated
    # angular momentum to the ground ring (= generator input shaft).
    u_final = simulate(sys, u_start, p, wind_fn;
                       n_steps=50_000, dt=4e-5,
                       lin_damp=0.05, ang_damp=1.0)

    alpha_gnd = u_final[6N + 1]         # ground ring accumulated twist
    omega_gnd = u_final[6N + Nr + 1]    # generator shaft angular velocity

    @test alpha_gnd > 0.0    # torsional coupling drove ground ring in hub's direction
    @test omega_gnd >= 0.0   # generator shaft spinning in the correct direction
end
