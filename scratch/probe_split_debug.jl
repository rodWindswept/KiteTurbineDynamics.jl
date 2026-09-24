using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function manual(sys, p, lift, hub)
    β=p.elevation_angle
    sh=[cos(β), 0, sin(β)]
    bo = KTD.bridle_bearing_offset((sys.nodes[sys.rotor.node_id]::RingNode).radius)
    bear = hub .+ bo .* sh
    sky, bdir = KTD._sky_anchor_design_pos(p, bear)
    cdir = normalize(bear .- sky)
    _, T_lift, el = KTD.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    ld=[cos(deg2rad(el)), 0, sin(deg2rad(el))]
    Tb, Tc = KTD._sky_anchor_taut_split(cdir, bdir, ld, T_lift, KTD.SKY_ANCHOR_MASS_KG)
    return (
        T_cyan=Tc,
        T_back=Tb,
        sky=sky,
        bear=bear,
        bdir=bdir,
        cdir=cdir,
        T_lift=T_lift,
        bo=bo,
        sh=sh,
    )
end
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    hub0 = pos(u0, sys.rotor.node_id)
    m = manual(sys, p, lift, hub0)
    d = KTD.lift_chain_design(sys, p, lift, hub0; omega_eq=12.983466)
    @printf("u0 hub=[%.4f %.4f %.4f]  |hub|=%.4f\n", hub0..., norm(hub0))
    @printf("manual: T_cyan=%.3f T_back=%.3f\n", m.T_cyan, m.T_back)
    @printf("  bear=[%.4f %.4f %.4f] sky=[%.4f %.4f %.4f]\n", m.bear..., m.sky...)
    @printf(
        "  cdir=[%+.5f %+.5f]  bdir=[%+.5f %+.5f]  T_lift=%.3f\n",
        m.cdir[1],
        m.cdir[3],
        m.bdir[1],
        m.bdir[3],
        m.T_lift
    )
    @printf(
        "src   : T_cyan=%.3f T_back=%.3f back_taut=%s\n", d.T_cyan, d.T_back, d.back_taut
    )
    @printf(
        "  bearing_pos=[%.4f %.4f %.4f] sky_pos=[%.4f %.4f %.4f]\n",
        d.bearing_pos...,
        d.sky_pos...
    )
end
main()
