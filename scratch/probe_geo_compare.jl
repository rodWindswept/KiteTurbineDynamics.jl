using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
sys, u0, p, lift, wf = build_case(nothing, nothing)
u = settle_to_operational_state(
    sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
)
β = p.elevation_angle;
sh = [cos(β), 0.0, sin(β)]
hub = pos(u, sys.rotor.node_id);
bea = pos(u, sys.bearing_id);
sky = pos(u, sys.sky_anchor_id)
bo = KTD.bridle_bearing_offset((sys.nodes[sys.rotor.node_id]::RingNode).radius)
bear_d = hub .+ bo .* sh;
sky_d = bear_d .+ KTD.CYAN_L0_DESIGN .* sh
back_ax = p.tether_length*cos(β)+p.back_anchor_fwd_x;
back=[back_ax, 0.0, 0.0]
_, T_lift, el_deg = KTD.lift_force_steady(lift, p.rho, p.v_wind_ref, p);
el=deg2rad(el_deg)
ld=[cos(el), 0.0, sin(el)];
W=[0.0, 0.0, -KTD.SKY_ANCHOR_MASS_KG*9.81]
function solve(cdir, bdir, tag)
    A=[bdir[1] cdir[1]; bdir[3] cdir[3]]
    rhs=[-T_lift*ld[1]; -T_lift*ld[3]+KTD.SKY_ANCHOR_MASS_KG*9.81]
    s=A\rhs
    @printf(
        "  %-34s T_back=%8.3f  T_cyan=%8.3f  slack=%8.3f  residual=%.3e\n",
        tag,
        s[1],
        s[2],
        max(-dot(T_lift .* ld .+ W, cdir), 0.0),
        norm(A*s-rhs)
    )
end
@printf("T_lift=%.3f N el=%.3f  back_ax=%.5f\n", T_lift, el_deg, back_ax)
@printf(
    "hub=[%.4f %.4f %.4f]  bea=[%.4f %.4f %.4f]  sky=[%.4f %.4f %.4f]\n",
    hub...,
    bea...,
    sky...
)
@printf("bear_d=[%.4f %.4f %.4f] sky_d=[%.4f %.4f %.4f]\n", bear_d..., sky_d...)
@printf("norm(bea-bear_d)=%.5f  norm(sky-sky_d)=%.5f\n", norm(bea-bear_d), norm(sky-sky_d))
solve(normalize(bear_d .- sky_d), normalize(back .- sky_d), "IDEAL sky_d + ideal cdir")
solve(normalize(bear_d .- sky_d), normalize(back .- sky), "back uses SETTLED sky")
solve(normalize(bea .- sky), normalize(back .- sky), "both SETTLED (probe exact)")
