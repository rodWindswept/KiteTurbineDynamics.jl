using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    ω = u[6N + Nr + 1]
    β=p.elevation_angle
    sh=[cos(β), 0, sin(β)]
    hub = pos(u, sys.rotor.node_id)
    R = (sys.nodes[sys.rotor.node_id]::RingNode).radius
    bo = KTD.bridle_bearing_offset(R)
    perp1, perp2 = KTD.shaft_perp_basis(sh)
    pa = KTD.attachment_point(hub, R, 0.0, 1, p.n_lines, perp1, perp2)
    for (tag, bea) in
        (("ideal hub+bo·sh", hub .+ bo .* sh), ("settled bearing", pos(u, sys.bearing_id)))
        gap = norm(bea .- pa)
        cosθ = bo/gap
        @printf(
            "%-18s bea=[%.4f %.4f %.4f] pa=[%.4f %.4f %.4f] gap=%.5f bo/gap=%.5f\n",
            tag,
            bea...,
            pa...,
            gap,
            cosθ
        )
    end
    # direct call to current source function
    d = KTD.lift_chain_design(sys, p, lift, hub; omega_eq=ω)
    @printf(
        "current lift_chain_design: T_cyan=%.3f T_cyan_ax=%.3f T_bridle=%.3f gap=%.4f cosθ=%.4f T_top=%.3f\n",
        d.T_cyan,
        d.T_cyan_ax,
        d.T_bridle,
        d.gap,
        d.cosθ,
        d.T_top
    )
end
main()
