# scratch/preload_hub_isolate.jl
#
# READ-ONLY. Isolates the unaccounted hub axial force.
#   budget (thrust - gravity - transmission + bridles) = -1419.70 N
#   ODE measured                                        = -479.75 N
#   unaccounted up-shaft term = 939.95 N
#
# Zeroing wind moves the residual by -1062 N, while the hand-computed main-rotor
# thrust is only +309 N.  So a large hub axial term exists that is neither the main
# thrust nor gravity nor the transmission.  This finds it by perturbation.
#
#   scripts/ktd-julia scratch/preload_hub_isolate.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
using KiteTurbineDynamics: main_rotor_swept_area, ct_at_tsr
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function hub_ax(sys, p, u, wf, lift, N, sd)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    hub = sys.rotor.node_id
    m = (sys.nodes[hub]::RingNode).mass
    return m * dot(du[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)], sd)
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id
    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    sd = normalize(pos(u, hub))
    base = hub_ax(sys, p, u, wf, lift, N, sd)
    @printf("base = %+.6f N\n\n", base)

    # (a) no wind at all
    a = hub_ax(sys, p, u, (r, t) -> zeros(3), lift, N, sd)
    @printf("(a) wind=0                       Δ = %+12.6f\n", a - base)

    # (b) neutralise the two expansion rotors by rebuilding sys without them
    ers = sys.expansion_rotors
    @printf("    expansion rotors: %d  rings=%s  tip_radii=%s  bank_deg=%s\n",
        length(ers), [e.ring_idx for e in ers],
        [e.blade_tip_radius for e in ers], [e.bank_angle_deg for e in ers])
    sys_noer = KiteTurbineSystem(
        sys.nodes, sys.sub_segs, sys.ring_ids, sys.rotor, sys.kite,
        sys.bearing_id, sys.sky_anchor_id, sys.n_ring, sys.n_total,
        sys.ring_tilt_axis, sys.brake_engaged, sys.k_mppt_ref, sys.kite_pos,
        ExpansionRotorParams[], sys.effective_radii,
        sys.ring_Do_top, sys.ring_toverD, sys.ring_aspect_ratio,
        sys.ring_Do_scale_exp,
    )
    b = hub_ax(sys_noer, p, u, wf, lift, N, sd)
    @printf("(b) expansion rotors removed     Δ = %+12.6f\n", b - base)

    # (c) hub rotor omega -> 0 (kills main thrust)
    save_w = u[6N + Nr]
    u[6N + Nr] = 0.0
    c = hub_ax(sys, p, u, wf, lift, N, sd)
    u[6N + Nr] = save_w
    @printf("(c) hub omega=0                  Δ = %+12.6f\n", c - base)

    # (d) all omegas -> 0
    save_all = copy(u[(6N + Nr + 1):(6N + 2Nr)])
    u[(6N + Nr + 1):(6N + 2Nr)] .= 0.0
    d = hub_ax(sys, p, u, wf, lift, N, sd)
    u[(6N + Nr + 1):(6N + 2Nr)] .= save_all
    @printf("(d) all omega=0                  Δ = %+12.6f\n", d - base)

    # (e) wind=0 AND all omega=0  -> should leave only gravity + transmission
    u[(6N + Nr + 1):(6N + 2Nr)] .= 0.0
    e = hub_ax(sys, p, u, (r, t) -> zeros(3), lift, N, sd)
    u[(6N + Nr + 1):(6N + 2Nr)] .= save_all
    @printf("(e) wind=0 and all omega=0       Δ = %+12.6f   (abs = %+.4f N)\n",
        e - base, e)

    # (f) what the main-rotor thrust SHOULD be, computed here
    w = u[6N + Nr]
    v = wf(pos(u, hub), 0.0)
    vh = norm(v) * sys.rotor.wind_factor
    lam = abs(w) * sys.rotor.radius / vh
    @printf("\n    hand thrust = 0.5*rho*vh^2*A*ct*cos^2 = %.4f N (vh=%.4f lam=%.4f ct=%.5f A=%.4f)\n",
        0.5 * p.rho * vh^2 * main_rotor_swept_area(sys) * ct_at_tsr(lam) *
        cos(p.elevation_angle)^2.0, vh, lam, ct_at_tsr(lam), main_rotor_swept_area(sys))
    @printf("    gravity on hub = %.4f N\n", (sys.nodes[hub]::RingNode).mass * 9.81)
    println()
end

main()
