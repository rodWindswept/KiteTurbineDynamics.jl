# scratch/preload_hub_budget.jl
#
# READ-ONLY. Rod's question (2026-09-12): does the line-tension calculation include
# rotor thrust (and multi-rotor thrusts)?
#
# This decomposes the hub's axial force budget from first principles and compares
# the sum with the ODE's own measured residual, so any missing term shows up as a
# discrepancy rather than an assumption.
#
#   scripts/ktd-julia scratch/preload_hub_budget.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
using KiteTurbineDynamics: main_rotor_swept_area, ct_at_tsr
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id
    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    sd = normalize(pos(u, hub))
    m_hub = (sys.nodes[hub]::RingNode).mass
    r_hub = (sys.nodes[hub]::RingNode).radius

    @printf("hub: mass=%.4f kg radius=%.4f m ; n_blades=%d m_blade=%.4f kg\n",
        m_hub, r_hub, p.n_blades, p.m_blade)
    @printf("rotor: radius=%.4f blade_hub_radius=%.4f wind_factor=%.4f\n",
        sys.rotor.radius, sys.rotor.blade_hub_radius, sys.rotor.wind_factor)
    @printf("n_expansion_rotors = %d ; ring_ids[end]=%d hub=%d\n\n",
        length(sys.expansion_rotors), sys.ring_ids[end], hub)

    w = u[6N + Nr]
    v_wind = wf(pos(u, hub), 0.0)
    v_hub_mag = norm(v_wind) * sys.rotor.wind_factor
    lam = abs(w) * sys.rotor.radius / v_hub_mag
    thrust = 0.5 * p.rho * v_hub_mag^2 * main_rotor_swept_area(sys) * ct_at_tsr(lam) *
             cos(p.elevation_angle)^2.0
    G = m_hub * 9.81
    @printf("v_hub=%.4f m/s  lambda=%.4f  ct=%.5f  A_swept=%.4f m2\n",
        v_hub_mag, lam, ct_at_tsr(lam), main_rotor_swept_area(sys))
    @printf("THRUST (main/hub rotor)   = %+10.4f N  (up-shaft)\n", thrust)
    @printf("GRAVITY on hub            = %+10.4f N  (down)\n", -G)

    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    EA = p.e_modulus * π * (p.tether_diameter / 2)^2

    # uppermost transmission segment: ring_ids[Nr-1] -> hub
    ga = sys.ring_ids[Nr - 1]
    na = sys.nodes[ga]::RingNode
    L_seg = ROPE_SUBSEGS * sys.sub_segs[(Nr - 2) * p.n_lines * ROPE_SUBSEGS + 1].length_0
    sumT = 0.0
    axT = 0.0
    for j in 1:p.n_lines
        pa = attachment_point(pos(u, ga), na.radius, u[6N + Nr - 1], j, p.n_lines, pp1, pp2)
        pb = attachment_point(pos(u, hub), r_hub, u[6N + Nr], j, p.n_lines, pp1, pp2)
        d = pb .- pa
        L = norm(d)
        T = EA * max(0.0, (L - L_seg) / L_seg)
        sumT += T
        axT += T * dot(d ./ L, sd)
    end

    # bridles: bearing -> hub attachment vertices
    bear = sys.bearing_id
    bsumT = 0.0
    baxT = 0.0
    nrest = 0.0
    for ss in sys.sub_segs
        (ss.end_a.node_id == hub && ss.end_b.node_id == bear) ||
            (ss.end_a.node_id == bear && ss.end_b.node_id == hub) || continue
        nrest = ss.length_0
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(pos(u, hub), r_hub, u[6N + Nr], ring_end.line_idx,
                              p.n_lines, pp1, pp2)
        d = pos(u, bear) .- pa          # force on hub points toward the bearing
        L = norm(d)
        T = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        bsumT += T
        baxT += T * dot(d ./ L, sd)
    end
    @printf("TRANSMISSION (ring %d->hub) = %+10.4f N (down)  [sum T = %.3f N]\n",
        Nr - 1, -axT, sumT)
    @printf("BRIDLES (found %d lines, rest %.6f m) = %+10.4f N (up)  [sum T = %.4f N]\n",
        p.n_lines, nrest, baxT, bsumT)

    exp_sum = 0.0
    for er in sys.expansion_rotors
        ri = er.ring_idx
        gid = sys.ring_ids[ri]
        @printf("  expansion rotor on ring %d (gid %d, r=%.4f) -> force applied at THAT ring\n",
            ri, gid, (sys.nodes[gid]::RingNode).radius)
    end

    predicted = thrust - G - axT + baxT
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    measured = m_hub * dot(du[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)], sd)
    @printf("\nPREDICTED sum (thrust - gravity - transmission + bridles) = %+10.4f N\n", predicted)
    @printf("MEASURED hub axial residual                               = %+10.4f N\n", measured)
    @printf("DISCREPANCY                                               = %+10.4f N\n",
        measured - predicted)
    @printf("\nrotor ring weight (m_ring*r^2) implied p.m_ring = %.4f\n", p.m_ring)
    println()
end

main()
