# scratch/preload_fixedpoint_conv.jl
#
# READ-ONLY diagnostic. Establishes, with the CORRECTED update sign
# (`T_top += 0.7·m_hub·a_ax`, see docs/plans/2026-09-11-settle-ode-coherence.md §2.4),
# three things the implementation in src/initialization.jl depends on:
#
#   1. the fixed point actually CONVERGES to |m_hub·a_ax| < 1e-2 N, and where it
#      lands (the committed preload_kernel_probe.jl stopped after 4 hard-coded
#      iterations at residual -4.47 N, which is NOT converged);
#   2. the measured per-iteration contraction, to size the iteration cap honestly;
#   3. whether the hub axial residual is ~0 on the state the settle actually
#      RETURNS -- i.e. whether the settle reaches the hub equilibrium that the
#      fixed point assumes. This is the assumption item 2 rests on and it has
#      never been measured on the returned state (the committed probe only
#      measured it on its hand-placed trial geometry).
#
# Touches no src/ code and writes nothing. Run from the repo root:
#   scripts/ktd-julia scratch/preload_fixedpoint_conv.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

# ── the probe's placement, reused verbatim so the comparison is like-for-like ──
function place_trial(sys, p, base, F, wf)
    N, Nr = sys.n_total, sys.n_ring
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    omega = base[6N + Nr + 1]
    alpha, centers = KiteTurbineDynamics._matched_place_twist(
        sys, p, F, sys.k_mppt_ref[] * omega^2, omega, wf, sd)
    u = copy(base)
    for (ri, gid) in enumerate(sys.ring_ids)
        u[(3gid - 2):3gid] .= centers[ri]
        u[6N + ri] = alpha[ri]
    end
    hub = sys.rotor.node_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    for node in sys.nodes
        node isa RopeNode || continue
        s, j = node.seg_idx, node.line_idx
        ra = isempty(sys.expansion_rotors) ? sys.nodes[sys.ring_ids[s]].radius : sys.effective_radii[s]
        rb = isempty(sys.expansion_rotors) ? sys.nodes[sys.ring_ids[s + 1]].radius : sys.effective_radii[s + 1]
        pa = attachment_point(centers[s], ra, alpha[s], j, p.n_lines, pp1, pp2)
        pb = attachment_point(centers[s + 1], rb, alpha[s + 1], j, p.n_lines, pp1, pp2)
        u[(3node.id - 2):3node.id] .= pa .+ (node.sub_idx / ROPE_SUBSEGS) .* (pb .- pa)
    end
    KiteTurbineDynamics.set_orbital_velocities!(u, sys, p)
    return u
end

# The quantity item 2 drives to zero: the hub's mass-weighted axial acceleration.
function hub_residual(sys, p, u, wf, lift)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    N = sys.n_total
    hub = sys.rotor.node_id
    sd = normalize(u[(3 * (hub - 1) + 1):(3 * hub)])
    m_hub = (sys.nodes[hub]::RingNode).mass
    return m_hub * dot(du[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)], sd)
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    base = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    N, Nr = sys.n_total, sys.n_ring

    @printf("beta = %.3f deg   rings = %d   n_seg = %d   m_hub = %.4f kg\n",
        rad2deg(p.elevation_angle), Nr, Nr - 1, (sys.nodes[sys.rotor.node_id]::RingNode).mass)

    # ── 3. is the RETURNED settle state at hub equilibrium? ─────────────────────
    f_ret = hub_residual(sys, p, base, wf, lift)
    @printf("\n[A] hub axial residual on the RETURNED settle state = %+.6f N\n", f_ret)

    # ── 1+2. the fixed point, with the corrected sign, run to convergence ───────
    F = design_axial_preload(sys, p, lift)
    T0 = F[end]
    @printf("\n[B] design_axial_preload first guess T_top = %.6f N\n", T0)

    # local sensitivity, to get the analytic contraction as well as the measured one
    fp = hub_residual(sys, p, place_trial(sys, p, base, F .+ 1.0, wf), wf, lift)
    fm = hub_residual(sys, p, place_trial(sys, p, base, F .- 1.0, wf), wf, lift)
    dfdT = (fp - fm) / 2
    @printf("    df/dT = %+.6f   => contraction |1 - 0.7*df/dT| = %.4f\n",
        dfdT, abs(1 - 0.7 * dfdT))

    println("\n[C] corrected fixed point (T_top += 0.7*f), tol 1e-2 N, cap 40:")
    T = T0
    prev = NaN
    converged = false
    for it in 1:40
        u = place_trial(sys, p, base, F .+ (T - T0), wf)
        f = hub_residual(sys, p, u, wf, lift)
        ratio = isnan(prev) || f == 0 ? NaN : abs(f) / abs(prev)
        @printf("    it=%2d  T_top=%12.6f  f=%16.9f  contraction=%s\n",
            it, T, f, isnan(ratio) ? "     -   " : @sprintf("%.4f", ratio))
        if abs(f) < 1e-2
            converged = true
            break
        end
        prev = f
        T += 0.7 * f
    end
    @printf("\n    converged = %s   T_top* = %.6f N   (%.2f %% below the first guess)\n",
        converged, T, 100 * (T0 - T) / T0)

    # ── does the derived profile reproduce the settled tensions? (the S1 idea) ──
    u_star = place_trial(sys, p, base, F .+ (T - T0), wf)
    ef = KiteTurbineDynamics.capture_extended(u_star, sys, p, 0.0, wf, lift)
    intended = (F .+ (T - T0)) ./ p.n_lines
    @printf("\n[D] achieved tension vs kernel-derived F_ax/n_lines:\n")
    @printf("    %4s %14s %14s %10s\n", "seg", "achieved_N", "intended_N", "err_%")
    for s in 1:(Nr - 1)
        a = ef.segment_tension[s]
        @printf("    %4d %14.4f %14.4f %+9.2f\n", s, a, intended[s],
            100 * (a - intended[s]) / intended[s])
    end
    @printf("    max |err| = %.2f %%\n",
        100 * maximum(abs.(ef.segment_tension .- intended) ./ intended))
    @printf("    first-segment twist = %.3f deg\n", ef.segment_twist_deg[1])

    # ── is the asin clamp saturating?  If sin(dA) > 1 the requested torque is not
    # realisable at ANY twist, and `_matched_place_twist` silently returns 90 deg.
    # That is a second silent-truncation path, structurally like the tau_carry<=0
    # no-op: it hides an unreachable target behind a clamp.
    println("\n[E] asin-clamp audit (clamp ceiling = 90.000 deg):")
    EA = p.e_modulus * π * (p.tether_diameter / 2)^2
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    for (label, Fax) in (("first guess", F), ("fixed point", F .+ (T - T0)))
        alpha, _ = KiteTurbineDynamics._matched_place_twist(
            sys, p, Fax, sys.k_mppt_ref[] * base[6N + Nr + 1]^2,
            base[6N + Nr + 1], wf, sd)
        @printf("  %-12s alpha(deg) = %s\n", label,
            join([@sprintf("%7.2f", rad2deg(alpha[i])) for i in 1:Nr], ""))
        for s in 1:(Nr - 1)
            ga, gb = sys.ring_ids[s], sys.ring_ids[s + 1]
            ra = isempty(sys.expansion_rotors) ? (sys.nodes[ga]::RingNode).radius :
                 sys.effective_radii[s]
            rb = isempty(sys.expansion_rotors) ? (sys.nodes[gb]::RingNode).radius :
                 sys.effective_radii[s + 1]
            chord0 = ROPE_SUBSEGS *
                     sys.sub_segs[(s - 1) * p.n_lines * ROPE_SUBSEGS + 1].length_0
            Ts = Fax[s] / p.n_lines
            chord = chord0 * (1 + Ts / EA)
            sinv = sys.k_mppt_ref[] * base[6N + Nr + 1]^2 * chord /
                   (p.n_lines * Ts * ra * rb)
            sinv > 1.0 && @printf("      seg %d: sin(dA) = %.6f  -> CLAMPED (>1)\n", s, sinv)
        end
    end
    println()
end

main()
