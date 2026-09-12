# scratch/preload_equilibrium_exists.jl
#
# READ-ONLY. The question this answers: does a top tension exist that BOTH
#   (a) puts the airborne assembly at axial hub equilibrium, and
#   (b) is GEOMETRICALLY REALISABLE (sin(dA) <= 1 in every segment)?
#
# Why this matters.  Rod's correction (2026-09-12): every node above the ground
# ring is free -- sky hook, bearing and lift kite all float, and the back line is
# the only thing that can hold the sky hook down.  On the state the settle returns,
# the back line is SLACK, so the airborne assembly is not in equilibrium at all
# (hub 496 N, bearing 229 N, sky 268 N net).  Any fixed point driven on that state
# is measuring a non-equilibrium configuration.
#
# Separately, the closed form in `_matched_place_twist` needs
#     sin(dA) = tau * chord / (n_lines * T_s * r_a * r_b) <= 1,
# i.e. a PER-SEGMENT TENSION FLOOR
#     T_s >= tau * chord / (n_lines * r_a * r_b).
# `asin(clamp(., -1, 1))` silently returns 90 deg when that is violated.
#
# This sweeps T_top, places the rings with the matched-place solve at each value,
# and reports: the hub axial residual (from the ODE, self-consistent geometry) and
# the worst sin(dA) with its realisability verdict.  A zero crossing inside the
# realisable region = the approved task is well posed.  A zero crossing OUTSIDE it
# = the preload the hub wants cannot be built, and the conflict is real.
#
#   scripts/ktd-julia scratch/preload_equilibrium_exists.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    n_seg = Nr - 1
    hub = sys.rotor.node_id
    m_hub = (sys.nodes[hub]::RingNode).mass
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    EA = p.e_modulus * π * (p.tether_diameter / 2)^2

    base = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    omega = base[6N + Nr + 1]
    τ_eq = sys.k_mppt_ref[] * omega^2
    @printf("beta=%.1f deg  n_seg=%d  n_lines=%d  tau_eq=%.6f N.m  m_hub=%.4f kg\n",
        rad2deg(p.elevation_angle), n_seg, p.n_lines, τ_eq, m_hub)

    # place rings only; keep the airborne assembly where the settle left it, and
    # report forces from the ODE.  The hub force balance is what defines equilibrium.
    function place(F)
        α, ctrs = KiteTurbineDynamics._matched_place_twist(sys, p, F, τ_eq, omega, wf, sd)
        u = copy(base)
        for (ri, gid) in enumerate(sys.ring_ids)
            u[(3gid - 2):3gid] .= ctrs[ri]
            u[6N + ri] = α[ri]
        end
        # rope nodes along the new chords (closed-form chord, no tilt)
        pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
        for node in sys.nodes
            node isa RopeNode || continue
            s, j = node.seg_idx, node.line_idx
            ra = isempty(sys.expansion_rotors) ? sys.nodes[sys.ring_ids[s]].radius :
                 sys.effective_radii[s]
            rb = isempty(sys.expansion_rotors) ? sys.nodes[sys.ring_ids[s + 1]].radius :
                 sys.effective_radii[s + 1]
            pa = attachment_point(ctrs[s], ra, α[s], j, p.n_lines, pp1, pp2)
            pb = attachment_point(ctrs[s + 1], rb, α[s + 1], j, p.n_lines, pp1, pp2)
            u[(3node.id - 2):3node.id] .= pa .+ (node.sub_idx / ROPE_SUBSEGS) .* (pb .- pa)
        end
        KiteTurbineDynamics.set_orbital_velocities!(u, sys, p)
        return u
    end

    function hub_axial(u)
        du = zeros(length(u))
        KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
        return m_hub * dot(du[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)], sd)
    end

    # per-segment realizability at a given F_ax
    function worst_sin(F)
        worst = 0.0
        for s in 1:n_seg
            ga, gb = sys.ring_ids[s], sys.ring_ids[s + 1]
            ra = isempty(sys.expansion_rotors) ? (sys.nodes[ga]::RingNode).radius :
                 sys.effective_radii[s]
            rb = isempty(sys.expansion_rotors) ? (sys.nodes[gb]::RingNode).radius :
                 sys.effective_radii[s + 1]
            chord0 = ROPE_SUBSEGS *
                     sys.sub_segs[(s - 1) * p.n_lines * ROPE_SUBSEGS + 1].length_0
            Ts = F[s] / p.n_lines
            chord = chord0 * (1 + Ts / EA)
            worst = max(worst, τ_eq * chord / (p.n_lines * Ts * ra * rb))
        end
        worst
    end

    F0 = design_axial_preload(sys, p, lift)
    @printf("first guess: T_top=%.3f  worst sin(dA)=%.6f  hub residual=%+.3f N\n\n",
        F0[end], worst_sin(F0), hub_axial(place(F0)))

    println("sweep of T_top (ring weights held at the design increment):")
    @printf("  %12s %16s %14s %10s\n", "T_top_N", "hub_resid_N", "worst_sin", "verdict")
    g_inc = p.m_ring * 9.81 / sin(p.elevation_angle)
    for T in range(900.0, 1800.0; length=19)
        F = zeros(n_seg)
        F[n_seg] = T
        for i in (n_seg - 1):-1:1
            F[i] = F[i + 1] + g_inc
        end
        f = hub_axial(place(F))
        ws = worst_sin(F)
        @printf("  %12.3f %16.6f %14.6f %10s\n", T, f, ws,
            ws > 1.0 ? "INFEASIBLE" : "ok")
    end
    println()
end

main()
