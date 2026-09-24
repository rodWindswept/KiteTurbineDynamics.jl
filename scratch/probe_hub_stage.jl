using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function split(sys, p, lift, hub)
    β=p.elevation_angle
    sh=[cos(β), 0, sin(β)]
    bo=KTD.bridle_bearing_offset((sys.nodes[sys.rotor.node_id]::RingNode).radius)
    bear=hub .+ bo .* sh
    sky, bdir=KTD._sky_anchor_design_pos(p, bear)
    cdir=normalize(bear .- sky)
    _, Tl, el=KTD.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    ld=[cos(deg2rad(el)), 0, sin(deg2rad(el))]
    Tb, Tc=KTD._sky_anchor_taut_split(cdir, bdir, ld, Tl, KTD.SKY_ANCHOR_MASS_KG)
    return (Tc, Tb, sky, bear)
end
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    @printf(
        "u0 (as built)      hub=[%.4f %.4f]  |hub|=%.4f\n",
        pos(u0, sys.rotor.node_id)[1],
        pos(u0, sys.rotor.node_id)[3],
        norm(pos(u0, sys.rotor.node_id))
    )
    u_settle = KTD.settle_to_equilibrium(sys, copy(u0), p)
    @printf(
        "after settle_eq    hub=[%.4f %.4f]  |hub|=%.4f\n",
        pos(u_settle, sys.rotor.node_id)[1],
        pos(u_settle, sys.rotor.node_id)[3],
        norm(pos(u_settle, sys.rotor.node_id))
    )
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
    hub = pos(u, sys.rotor.node_id)
    @printf("operating (polish) hub=[%.4f %.4f]  |hub|=%.4f\n", hub[1], hub[3], norm(hub))
    @printf(
        "  settled bearing=[%.4f %.4f]  sky=[%.4f %.4f]\n",
        pos(u, sys.bearing_id)[1],
        pos(u, sys.bearing_id)[3],
        pos(u, sys.sky_anchor_id)[1],
        pos(u, sys.sky_anchor_id)[3]
    )
    for (tag, H) in (("as-built u0", pos(u0, sys.rotor.node_id)), ("operating", hub))
        Tc, Tb, sky, bear = split(sys, p, lift, H)
        @printf(
            "  split at %-12s -> T_cyan=%8.3f T_back=%8.3f  sky=[%7.4f %7.4f] bear=[%7.4f %7.4f]\n",
            tag,
            Tc,
            Tb,
            sky[1],
            sky[3],
            bear[1],
            bear[3]
        )
    end
end
main()
