using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]

# Standard two-circle intersection in the (x,z) plane.  Returns the UPPER point.
function circles_upper(c1, r1, c2, r2)
    d = norm(c2 .- c1)
    (d > r1 + r2 || d < abs(r1 - r2) || d < 1e-12) && return nothing
    a = (r1^2 - r2^2 + d^2) / (2d)
    h2 = r1^2 - a^2
    h2 < 0 && return nothing
    h = sqrt(h2)
    u = (c2 .- c1) ./ d
    p = c1 .+ a .* u
    perp = [-u[2], u[1]]
    q1 = p .+ h .* perp
    q2 = p .- h .* perp
    return q1[2] >= q2[2] ? q1 : q2
end

function twobytwo(cdir, bdir, T_lift, ld, Wsky)
    A=[bdir[1] cdir[1]; bdir[3] cdir[3]]
    rhs=[-T_lift*ld[1]; -T_lift*ld[3]+Wsky]
    return A\rhs
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    β=p.elevation_angle
    sh=[cos(β), 0, sin(β)]
    hub=pos(u, sys.rotor.node_id)
    sky=pos(u, sys.sky_anchor_id)
    R=(sys.nodes[sys.rotor.node_id]::RingNode).radius
    bo=KTD.bridle_bearing_offset(R)
    bear_d = hub .+ bo .* sh
    bx = p.tether_length*cos(β)+p.back_anchor_fwd_x
    L_axis = p.tether_length + bo + KTD.CYAN_L0_DESIGN
    ds = [L_axis*cos(β), L_axis*sin(β)]
    back_L0 = norm(ds .- [bx, 0.0])
    @printf(
        "R=%.4f bo=%.5f bear_d=[%.5f %.5f] bx=%.5f  L_axis=%.5f designsky=[%.5f %.5f] back_L0=%.5f\n",
        R,
        bo,
        bear_d[1],
        bear_d[3],
        bx,
        L_axis,
        ds...,
        back_L0
    )
    sk2 = circles_upper([bx, 0.0], back_L0, [bear_d[1], bear_d[3]], KTD.CYAN_L0_DESIGN)
    @printf(
        "circle sky = [%.5f %.5f]   ODE sky=[%.5f %.5f]  err=%.5f m\n",
        sk2...,
        sky[1],
        sky[3],
        norm([sk2[1], 0, sk2[2]] .- sky)
    )
    sk = [sk2[1], 0.0, sk2[2]]
    _, T_lift, el_deg = KTD.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    el=deg2rad(el_deg)
    ld=[cos(el), 0, sin(el)]
    Wsky=KTD.SKY_ANCHOR_MASS_KG*9.81
    res=Dict{String, Float64}()
    for (tag, S) in
        (("circle", sk), ("ODE settled", sky), ("ideal shaft", [ds[1], 0, ds[2]]))
        cdir=normalize(bear_d .- S)
        bdir=normalize([bx, 0, 0] .- S)
        s=twobytwo(cdir, bdir, T_lift, ld, Wsky)
        res[tag]=s[2]
        @printf(
            "  %-12s backdir=[%+.5f %+.5f] T_cyan=%8.3f T_back=%8.3f slack=%8.3f\n",
            tag,
            bdir[1],
            bdir[3],
            s[2],
            s[1],
            max(-dot(T_lift .* ld .+ [0, 0, -Wsky], cdir), 0.0)
        )
    end
    perp1, perp2=KTD.shaft_perp_basis(sh)
    pa=KTD.attachment_point(hub, R, 0.0, 1, p.n_lines, perp1, perp2)
    gap=norm(bear_d .- pa)
    cosθ=bo/gap
    Tthr=1100.85
    Wr=p.n_blades*p.m_blade*9.81
    @printf("cosθ=%.5f W_bearing·sinβ=%.4f\n", cosθ, KTD.BEARING_MASS_KG*9.81*sin(β))
    for tag in ("circle", "ideal shaft")
        Tc=res[tag]
        Tb=max((Tc-KTD.BEARING_MASS_KG*9.81*sin(β))/(p.n_lines*cosθ), 0.0)
        @printf(
            "  %-12s T_cyan=%8.3f -> T_bridle/line=%7.3f N (total %6.1f) T_top=%8.2f\n",
            tag,
            Tc,
            Tb,
            Tb*p.n_lines,
            Tthr+p.n_lines*Tb*cosθ-Wr*sin(β)
        )
    end
    d = KTD.lift_chain_design(sys, p, lift, hub; omega_eq=u[6N + Nr + 1])
    @printf(
        "CURRENT src: T_cyan=%.3f T_bridle=%.3f T_top=%.2f\n", d.T_cyan, d.T_bridle, d.T_top
    )
end
main()
