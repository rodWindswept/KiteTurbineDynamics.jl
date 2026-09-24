using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_operational_state(
        sys,
        copy(u0),
        p,
        60.0;
        lift_device=lift,
        wind_fn=wf,
        n_op=300_000,
        polish_dt=2.5e-5,
        polish_iters=160_000,
    )
    du_on=zeros(length(u))
    KTD.multibody_ode!(du_on, u, (sys, p, wf, lift), 0.0)
    du_off=zeros(length(u))
    KTD.multibody_ode!(du_off, u, (sys, p, wf), 0.0)
    g=sys.sky_anchor_id
    m=sys.nodes[g].mass
    Fl =
        m .* (
            du_on[(3N + 3 * (g - 1) + 1):(3N + 3 * g)] .-
            du_off[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]
        )
    @printf(
        "applied lift vector at sky = [%.3f %.3f %.3f] |F|=%.3f ; device=%.3f N\n",
        Fl...,
        norm(Fl),
        KTD.lift_force_steady(lift, p.rho, p.v_wind_ref, p)[2]
    )
    dt = KTD.stable_dt_for_system(sys, p)
    du = zeros(length(u))
    @printf("integrating forward with dt=%.3e (Euler, as the dashboard/sim path)\n", dt)
    for s in 1:4
        for _ in 1:round(Int, 1.0 / dt)
            KTD.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
            @views u[1:(6N)] .+= du[1:(6N)] .* dt
        end
        sky=pos(u, sys.sky_anchor_id)
        hub=pos(u, sys.rotor.node_id)
        bx=p.tether_length*cos(p.elevation_angle)+p.back_anchor_fwd_x
        @printf(
            "  t=%ds sky=[%8.4f %8.4f] hub=|%7.4f|  b_dist=%9.5f\n",
            s,
            sky[1],
            sky[3],
            norm(hub),
            hypot(sky[1]-bx, sky[3])
        )
    end
end
main()
