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
    β = p.elevation_angle
    sh=[cos(β), 0, sin(β)]
    hub = pos(u, sys.rotor.node_id)
    bo = KTD.bridle_bearing_offset((sys.nodes[sys.rotor.node_id]::RingNode).radius)
    bear_d = hub .+ bo .* sh
    sky_d = bear_d .+ KTD.CYAN_L0_DESIGN .* sh
    back_ax = p.tether_length*cos(β)+p.back_anchor_fwd_x
    back=[back_ax, 0, 0]
    _, T_lift, el_deg = KTD.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    el=deg2rad(el_deg)
    ld=[cos(el), 0, sin(el)]
    Wsky=KTD.SKY_ANCHOR_MASS_KG*9.81
    cdir_d = normalize(bear_d .- sky_d)
    bdir_d = normalize(back .- sky_d)
    T_cyan_slack = max(-dot(T_lift .* ld .+ [0, 0, -Wsky], cdir_d), 0.0)
    A=[bdir_d[1] cdir_d[1]; bdir_d[3] cdir_d[3]]
    rhs=[-T_lift*ld[1]; -T_lift*ld[3]+Wsky]
    s=A\rhs
    T_back_taut, T_cyan_taut = s[1], s[2]

    perp1, perp2 = KTD.shaft_perp_basis(sh)
    pa = KTD.attachment_point(
        hub,
        (sys.nodes[sys.rotor.node_id]::RingNode).radius,
        0.0,
        1,
        p.n_lines,
        perp1,
        perp2,
    )
    gap = norm(bear_d .- pa)
    cosθ = bo/gap
    v_hub = p.v_wind_ref*sys.rotor.wind_factor
    λ = abs(ω)*sys.rotor.radius/max(v_hub, 1e-6)
    T_thrust = 0.5*p.rho*v_hub^2*KTD.main_rotor_swept_area(sys)*KTD.ct_at_tsr(λ)*cos(β)^2
    W_rotor = p.n_blades*p.m_blade*9.81
    ttop(Tc) = (
        T_thrust +
        p.n_lines*(max(
            (-Tc*(-dot(cdir_d, sh)) - KTD.BEARING_MASS_KG*9.81*sin(β))/(p.n_lines*cosθ),
            0.0,
        ))*cosθ - W_rotor*sin(β)
    )
    @printf(
        "ω=%.4f  T_thrust=%.2f  cosθ=%.4f  bo=%.4f  gap=%.4f\n", ω, T_thrust, cosθ, bo, gap
    )
    @printf("SLACK: T_cyan=%8.2f  T_top=%8.2f\n", T_cyan_slack, ttop(T_cyan_slack))
    @printf(
        "TAUT : T_cyan=%8.2f  T_back=%8.2f  T_top=%8.2f\n",
        T_cyan_taut,
        T_back_taut,
        ttop(T_cyan_taut)
    )

    # realisability at the taut T_top (margin disabled), and with the enforcement loop
    for Ttop in (ttop(T_cyan_slack), ttop(T_cyan_taut))
        τ_eq = sys.k_mppt_ref[]*ω^2
        g_inc = p.m_ring*9.81*sin(β)
        n_seg = sys.n_ring-1
        F_ax = zeros(n_seg)
        F_ax[n_seg]=max(Ttop, 20.0)
        for i in (n_seg - 1):-1:1
            F_ax[i]=F_ax[i + 1]+g_inc
        end
        pl = KTD.trpt_matched_place(sys, p, F_ax, τ_eq, ω, wf; raise_on_unrealisable=false)
        @printf(
            "  T_top=%8.2f -> demand max=%.4f (seg %d) twist=%.2f deg  [slack-floor]\n",
            Ttop,
            maximum(pl.demand),
            argmax(pl.demand),
            rad2deg(asin(min(maximum(pl.demand), 1.0)))
        )
    end
    # what the CURRENT function does (T_top=1457.86) for reference
    @printf("current lift_chain_design T_top = 1457.86 (from handover)\n")
end
main()
