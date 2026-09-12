# scratch/preload_floor_exact.jl
#
# READ-ONLY. Computes the EXACT per-segment realisability floor
#     T_s >= tau * chord / (n_lines * r_a * r_b)
# and converts it to the equivalent top tension, so the conflict in plan §2.4.1 is
# recorded with computed numbers rather than interpolated ones.
#
#   scripts/ktd-julia scratch/preload_floor_exact.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    n_seg = Nr - 1
    base = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    omega = base[6N + Nr + 1]
    tau = sys.k_mppt_ref[] * omega^2
    EA = p.e_modulus * π * (p.tether_diameter / 2)^2
    g_inc = p.m_ring * 9.81 / sin(p.elevation_angle)

    @printf("tau = %.6f N.m   EA_single = %.6g N   g_inc = %.6f N/segment\n",
        tau, EA, g_inc)
    @printf("profile: F_ax[s] = T_top + (n_seg - s) * g_inc   (n_seg = %d)\n\n", n_seg)

    worst = 0.0
    worst_s = 0
    for s in 1:n_seg
        ga, gb = sys.ring_ids[s], sys.ring_ids[s + 1]
        ra = isempty(sys.expansion_rotors) ? (sys.nodes[ga]::RingNode).radius :
             sys.effective_radii[s]
        rb = isempty(sys.expansion_rotors) ? (sys.nodes[gb]::RingNode).radius :
             sys.effective_radii[s + 1]
        chord0 = ROPE_SUBSEGS *
                 sys.sub_segs[(s - 1) * p.n_lines * ROPE_SUBSEGS + 1].length_0
        # chord depends weakly on T_s; fixed-point the floor
        Ts = 100.0
        for _ in 1:80
            Ts = tau * chord0 * (1 + Ts / EA) / (p.n_lines * ra * rb)
        end
        Ttop_needed = Ts * p.n_lines - (n_seg - s) * g_inc
        @printf("  seg %d: r_a=%.5f r_b=%.5f chord0=%.6f  Ts_floor=%.4f N/line  T_top>=%.4f N\n",
            s, ra, rb, chord0, Ts, Ttop_needed)
        if Ttop_needed > worst
            worst = Ttop_needed
            worst_s = s
        end
    end
    @printf("\nBINDING segment %d: realisability floor  T_top >= %.4f N\n", worst_s, worst)

    F0 = design_axial_preload(sys, p, lift)
    @printf("design first guess T_top = %.4f N\n", F0[end])

    # equilibrium zero crossing: f(T) is linear with slope df/dT; use the two
    # sweep endpoints already measured in preload_equilibrium_exists.jl.
    # f(1300) = -164.539762, f(1287?) -- recompute two points here for exactness.
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    hub = sys.rotor.node_id
    m_hub = (sys.nodes[hub]::RingNode).mass
    function place(F)
        α, ctrs = KiteTurbineDynamics._matched_place_twist(sys, p, F, tau, omega, wf, sd)
        u = copy(base)
        for (ri, gid) in enumerate(sys.ring_ids)
            u[(3gid - 2):3gid] .= ctrs[ri]
            u[6N + ri] = α[ri]
        end
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
    function hubf(T)
        F = zeros(n_seg)
        F[n_seg] = T
        for i in (n_seg - 1):-1:1
            F[i] = F[i + 1] + g_inc
        end
        du = zeros(length(base))
        KiteTurbineDynamics.multibody_ode!(du, place(F), (sys, p, wf, lift), 0.0)
        m_hub * dot(du[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)], sd)
    end
    fa, fb = hubf(1200.0), hubf(1300.0)
    slope = (fb - fa) / 100.0
    T_eq = 1200.0 - fa / slope
    @printf("\naxial equilibrium: f(1200)=%+.6f  f(1300)=%+.6f  slope=%+.6f\n", fa, fb, slope)
    @printf("  => f = 0 at T_top = %.4f N ; residual at the floor (%.4f N) = %+.4f N\n",
        T_eq, worst, hubf(worst))
    @printf("\nCONFLICT: equilibrium wants %.1f N, realisability needs >= %.1f N (gap %.1f N)\n",
        T_eq, worst, worst - T_eq)
    println()
end

main()
