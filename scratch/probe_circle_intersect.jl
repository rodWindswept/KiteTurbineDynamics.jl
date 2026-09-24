using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]

function sky_from_circles(bx, R1, bex, bez, R2)
    A = 2*(bex - bx)
    B = -2*bez
    C = R2^2 - R1^2 - bx^2 + bex^2 + bez^2
    a = 1 + (A/B)^2
    b = -2*bx - 2*(C/B)*(A/B)
    c = bx^2 + (C/B)^2 - R1^2
    disc = b^2 - 4*a*c
    disc < 0 && return nothing
    r1 = (-b + sqrt(disc))/(2a)
    r2 = (-b - sqrt(disc))/(2a)
    cands = [(r1, (C-A*r1)/B), (r2, (C-A*r2)/B)]
    x, z = cands[argmax(getindex.(cands, 2))]
    return [x, 0.0, z]
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
    dsx = L_axis*cos(β)
    dsz = L_axis*sin(β)
    back_L0 = hypot(dsx - bx, dsz)
    sk = sky_from_circles(bx, back_L0, bear_d[1], bear_d[3], KTD.CYAN_L0_DESIGN)
    @printf(
        "bx=%.5f back_L0=%.5f bear_d=[%.4f %.4f] R2=%.4f\n",
        bx,
        back_L0,
        bear_d[1],
        bear_d[3],
        KTD.CYAN_L0_DESIGN
    )
    @printf(
        "circle sky = [%.5f %.5f %.5f]   ODE sky = [%.5f %.5f %.5f]   err=%.5f m\n",
        sk...,
        sky...,
        norm(sk .- sky)
    )
    @printf(
        "design sky = [%.5f %.5f %.5f]  err vs ODE = %.5f m\n",
        dsx,
        0.0,
        dsz,
        norm([dsx, 0, dsz] .- sky)
    )
    _, T_lift, el_deg = KTD.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    el=deg2rad(el_deg)
    ld=[cos(el), 0, sin(el)]
    Wsky=KTD.SKY_ANCHOR_MASS_KG*9.81
    results = Dict{String, Float64}()
    for (tag, S) in (
        ("circle-intersection", sk),
        ("ODE settled", sky),
        ("ideal shaft placement", [dsx, 0, dsz]),
    )
        cdir=normalize(bear_d .- S)
        bdir=normalize([bx, 0, 0] .- S)
        s=twobytwo(cdir, bdir, T_lift, ld, Wsky)
        slack=max(-dot(T_lift .* ld .+ [0, 0, -Wsky], cdir), 0.0)
        results[tag]=s[2]
        @printf(
            "  %-22s backdir=[%+.5f %+.5f] T_cyan=%8.3f T_back=%8.3f slack=%8.3f\n",
            tag,
            bdir[1],
            bdir[3],
            s[2],
            s[1],
            slack
        )
    end
    perp1, perp2=KTD.shaft_perp_basis(sh)
    pa=KTD.attachment_point(hub, R, 0.0, 1, p.n_lines, perp1, perp2)
    gap=norm(bear_d .- pa)
    cosθ=bo/gap
    Tauthrust = 1100.85
    Wrotor=p.n_blades*p.m_blade*9.81
    @printf(
        "cosθ=%.5f gap=%.5f W_bearing·sinβ=%.4f\n",
        cosθ,
        gap,
        KTD.BEARING_MASS_KG*9.81*sin(β)
    )
    for (tag, Tc) in (
        ("ideal", results["ideal shaft placement"]),
        ("circle", results["circle-intersection"]),
    )
        Tb = max((Tc - KTD.BEARING_MASS_KG*9.81*sin(β))/(p.n_lines*cosθ), 0.0)
        Ttop = Tauthrust + p.n_lines*Tb*cosθ - Wrotor*sin(β)
        @printf(
            "  %-7s T_cyan=%8.3f -> T_bridle/line=%7.3f N (total %6.1f N)  T_top=%8.2f\n",
            tag,
            Tc,
            Tb,
            Tb*p.n_lines,
            Ttop
        )
    end
    d = KTD.lift_chain_design(sys, p, lift, hub; omega_eq=u[6N + Nr + 1])
    @printf(
        "CURRENT src: T_cyan=%.3f T_bridle=%.3f T_top=%.2f\n", d.T_cyan, d.T_bridle, d.T_top
    )
end
main()
