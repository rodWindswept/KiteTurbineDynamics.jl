# scratch/preload_settle_chain.jl
#
# READ-ONLY diagnostic for the lift-chain coupling raised by Rod (2026-09-12):
# "we must make sure the bearing, sky, hook, backline and lift kite configuration
#  is all able to settle in the settle... if the bearing doesn't move the lift
#  lines get over stretched in the settle."
#
# The concern in model terms: the matched-place preload SHORTENS the transmission
# (18.805 -> 18.173 m, handover 2026-09-11 §3.1).  The hub therefore sits closer to
# the ground, and the bearing (BearingNode) and sky anchor (SkyAnchorNode) must move
# down-shaft with it or the cyan line / back line are held stretched.
#
# This measures, on the state `settle_to_operational_state` actually RETURNS:
#   1. are bearing and sky anchor at force equilibrium (residual accel), and did
#      they actually move during the operational settle?
#   2. cyan line and back line stretch (achieved length vs their slack length);
#   3. the bearing's error from its hub-relative DESIGN position -- this is exactly
#      the quantity that tilts the ring plane in `multibody_ode!` (dynamics.jl:29-51)
#      and `_tilted_ring_basis`, i.e. the tilt that `_matched_place_twist` ignores.
#
#   scripts/ktd-julia scratch/preload_settle_chain.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

sd_of(u, sys) = begin
    hub = sys.rotor.node_id
    p = u[(3 * (hub - 1) + 1):(3 * hub)]
    norm(p) > 0.1 ? p ./ norm(p) : [cos(0.5236), 0.0, sin(0.5236)]
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id
    bear = sys.bearing_id
    sky = sys.sky_anchor_id

    # state after the pre-operational settle (before preload restore / op settle)
    u_eq = settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    # fully settled state
    u_op = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)

    @printf("nodes: N=%d  hub=%d  bearing=%d  sky=%d\n\n", N, hub, bear, sky)

    println("Positions [x y z] and axial coordinate along the design shaft:")
    for (label, u) in (("after settle_to_equilibrium", u_eq), ("returned by op settle", u_op))
        @printf("  %-28s\n", label)
        for (nm, gid) in (("hub", hub), ("bearing", bear), ("sky", sky))
            q = pos(u, gid)
            @printf("    %-8s [%9.4f %9.4f %9.4f]   |r|=%9.4f\n",
                nm, q[1], q[2], q[3], norm(q))
        end
    end

    sd = sd_of(u_op, sys)
    @printf("\nshaft dir = [%.6f %.6f %.6f]\n", sd...)

    # ── 1. did bearing/sky move, and are they in equilibrium? ──────────────────
    Δb = pos(u_op, bear) .- pos(u_eq, bear)
    Δs = pos(u_op, sky) .- pos(u_eq, sky)
    @printf("\n[1] movement during the operational settle:\n")
    @printf("    bearing  Δ = [%+.5f %+.5f %+.5f]  |Δ| = %.5f m  axial = %+.5f m\n",
        Δb..., norm(Δb), dot(Δb, sd))
    @printf("    sky      Δ = [%+.5f %+.5f %+.5f]  |Δ| = %.5f m  axial = %+.5f m\n",
        Δs..., norm(Δs), dot(Δs, sd))

    du = zeros(length(u_op))
    KiteTurbineDynamics.multibody_ode!(du, u_op, (sys, p, wf, lift), 0.0)
    for (nm, gid) in (("bearing", bear), ("sky", sky), ("hub", hub))
        m = (sys.nodes[gid]::Union{BearingNode,SkyAnchorNode,RingNode}).mass
        a = du[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)]
        @printf("    %-8s mass=%7.3f kg   net force = [%+12.6f %+12.6f %+12.6f] N  |F|=%.6f N\n",
            nm, m, (m .* a)..., m * norm(a))
    end

    # ── 2. cyan and back line stretch ─────────────────────────────────────────
    # cyan: sky anchor -> bearing, slack length 5.0 m (ring_forces.jl:522)
    cyan_L0 = 5.0
    cyan_now = norm(pos(u_op, sky) .- pos(u_op, bear))
    # back line: back anchor -> sky anchor; SlackLength is reconstructed the same
    # way ring_forces.jl:530-538 does it.
    bearing_offset = 6.0
    back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    L_axis_design = p.tether_length + bearing_offset + cyan_L0
    dsx = L_axis_design * cos(p.elevation_angle)
    dsz = L_axis_design * sin(p.elevation_angle)
    back_L0 = sqrt((dsx - back_ax)^2 + dsz^2) + p.backline_payout
    back_now = sqrt((pos(u_op, sky)[1] - back_ax)^2 + pos(u_op, sky)[2]^2 +
                    pos(u_op, sky)[3]^2)
    @printf("\n[2] line stretch on the returned state:\n")
    @printf("    cyan   L0=%.6f  now=%.6f  stretch=%+.4f mm  strain=%+.3e\n",
        cyan_L0, cyan_now, 1000 * (cyan_now - cyan_L0), (cyan_now - cyan_L0) / cyan_L0)
    @printf("    back   L0=%.6f  now=%.6f  stretch=%+.4f mm  strain=%+.3e\n",
        back_L0, back_now, 1000 * (back_now - back_L0), (back_now - back_L0) / back_L0)

    # ── 3. bearing error from its hub-relative design position (the tilt driver) ─
    hub_pos = pos(u_op, hub)
    bearing_design = hub_pos .+ bearing_offset .* sd
    berr = pos(u_op, bear) .- bearing_design
    tilt_perp = berr .- dot(berr, sd) .* sd
    @printf("\n[3] bearing error from hub+6m*sd (drives the ring-plane tilt):\n")
    @printf("    error = [%+.6f %+.6f %+.6f]  |perp| = %.6f m  -> tilt = %.4f deg\n",
        berr..., norm(tilt_perp), rad2deg(min(norm(tilt_perp) * 0.1, π / 6)))

    # transmission length achieved vs untwisted design
    untwisted = sum(ROPE_SUBSEGS *
                    sys.sub_segs[(k - 1) * p.n_lines * ROPE_SUBSEGS + 1].length_0
                    for k in 1:(Nr - 1))
    @printf("\n    untwisted design length = %.6f m ; |hub| = %.6f m ; shortening = %.4f m\n",
        untwisted, norm(hub_pos), untwisted - norm(hub_pos))

    # ── hub axial residual (the item-2 target) ────────────────────────────────
    m_hub = (sys.nodes[hub]::RingNode).mass
    f = m_hub * dot(du[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)], sd)
    @printf("\n    hub axial residual f = %+.6f N\n", f)
    println()
end

main()
