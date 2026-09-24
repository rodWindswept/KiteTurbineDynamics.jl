using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function cyanT(u, sys)
    tot=0.0
    for ss in sys.sub_segs
        na, nb=ss.end_a.node_id, ss.end_b.node_id
        (
            (na==sys.sky_anchor_id&&nb==sys.bearing_id)||(
                na==sys.bearing_id&&nb==sys.sky_anchor_id
            )
        )||continue
        L=norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
        tot+=ss.EA*max(0.0, (L-ss.length_0)/ss.length_0)
    end
    return tot
end
function handoff(u, sys, p, wf, lift)
    N=sys.n_total
    du=zeros(length(u))
    KTD.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    acc=[norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    force=[sys.nodes[g].mass*acc[g] for g in 1:N]
    sg=[
        g for
        g in 1:N if sys.nodes[g] isa RingNode || g==sys.bearing_id || g==sys.sky_anchor_id
    ]
    return maximum(acc), maximum(acc[g] for g in sg), maximum(force)
end
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    t0=time()
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    @printf("settle wall time = %.1f s\n", time()-t0)
    ω = u[6N + Nr + 1]
    hub=pos(u, sys.rotor.node_id)
    d = KTD.lift_chain_design(sys, p, lift, hub; omega_eq=ω)
    @printf(
        "design @ operating hub: T_cyan=%.2f T_back=%.2f T_top=%.2f back_taut=%s\n",
        d.T_cyan,
        d.T_back,
        d.T_top,
        d.back_taut
    )
    a, ast, f = handoff(u, sys, p, wf, lift)
    @printf(
        "V6: acc_all=%.2f acc_struct=%.2f max_force=%.2f  (gates 98.1 / 200)\n", a, ast, f
    )
    bx=p.tether_length*cos(p.elevation_angle)+p.back_anchor_fwd_x
    sky=pos(u, sys.sky_anchor_id)
    bd=hypot(sky[1]-bx, sky[3])
    @printf(
        "settled: b_dist=%.5f T_back(law)=%.2f  T_cyan=%.2f\n",
        bd,
        KTD.back_line_tension(bd, 13.92547, p.backline_payout, p.EA_back_line),
        cyanT(u, sys)
    )
    res = Dict{String, Float64}()
    du=zeros(length(u))
    KTD.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    sd=hub ./ norm(hub)
    for (nm, g) in (
        ("hub", sys.rotor.node_id), ("bearing", sys.bearing_id), ("sky", sys.sky_anchor_id)
    )
        m=sys.nodes[g].mass
        res[nm]=dot(m .* du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)], sd)
    end
    @printf(
        "axial residuals: hub=%.2f bearing=%.2f sky=%.2f (gate 50 N)\n",
        res["hub"],
        res["bearing"],
        res["sky"]
    )
end
main()
