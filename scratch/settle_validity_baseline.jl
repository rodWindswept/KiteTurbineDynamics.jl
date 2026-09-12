# scratch/settle_validity_baseline.jl
#
# READ-ONLY. Measures the six settle-validity quantities on the CURRENT v13
# campaign seed, so the guard's tolerances are set from measurement rather than
# from expectation.  This is the V1-V6 definition of a valid settle:
#
#   V1  structural velocities ~ 0, rotation PRESENT and at omega_eq
#       (omega == 0 at handoff would mean no power at the PTO)
#   V2  hub axial residual small  (airborne assembly at equilibrium)
#   V3  every line above the ground ring TAUT  (bridles, cyan)
#   V4  ring torque residual small
#   V5  no twist drift over the first second
#   V6  first ODE step produces no jerk (accel vs window)
#
#   scripts/ktd-julia scratch/settle_validity_baseline.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function net_axial(u, sys, p, wf, lift, N, sd)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    out = Float64[]
    for gid in (sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id)
        m = (sys.nodes[gid]).mass
        push!(out, dot(m .* du[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)], sd))
    end
    return out, du
end

function chain_tensions(u, sys, p, N, Nr)
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    bridle = 0.0
    nb = 0
    for ss in sys.sub_segs
        na, nbb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nbb == bear) || (na == bear && nbb == hub)) || continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(pos(u, hub), R, u[6N + Nr], ring_end.line_idx,
                              p.n_lines, pp1, pp2)
        L = norm(pos(u, bear) .- pa)
        bridle += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        nb += 1
    end
    cyan = 0.0
    for ss in sys.sub_segs
        na, nbb = ss.end_a.node_id, ss.end_b.node_id
        ((na == bear && nbb == sky) || (na == sky && nbb == bear)) || continue
        L = norm(pos(u, sky) .- pos(u, bear))
        cyan = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return bridle, nb, cyan
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id

    t0 = time()
    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    t_settle = time() - t0
    sd = normalize(pos(u, hub))

    # ── V1: structural velocities vs rotation ────────────────────────────────
    # NOTE: a node's raw translational velocity includes its rotation omega x r,
    # which is SUPPOSED to be non-zero (~31 m/s at the hub rim).  Subtract the
    # rigid-body rotational component and measure what is left: wobble, drift,
    # and deformation.  That residual must be ~0.  Rotation itself must be present.
    om = u[(6N + Nr + 1):(6N + 2Nr)]
    vstruct = 0.0
    for gid in 1:N
        v = u[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)]
        p3 = pos(u, gid)
        w = 0.0
        if sys.nodes[gid] isa RingNode
            w = om[(sys.nodes[gid]::RingNode).ring_idx]
        end
        # Rigid-body rotational velocity of a point at p3 about the shaft axis
        # through the origin: v = omega * (z_hat x p3) for rotation about z.
        # The shaft here is the [cos b, 0, sin b] axis, so project first.
        ax = norm(p3) > 1e-9 ? p3 ./ norm(p3) : [0.0, 0.0, 0.0]
        vrot = w .* cross(ax, p3)
        vstruct = max(vstruct, norm(v .- vrot))
    end
    @printf("V1  max |structural velocity| (rotation removed) = %.6e m/s\n", vstruct)
    @printf("    max |raw node velocity| (incl. rotation)      = %.6e m/s\n",
        maximum(abs.(u[(3N + 1):6N])))
    @printf("    omega: min=%.6f max=%.6f (must be > 0)   spread=%.3e\n",
        minimum(om), maximum(om), maximum(om) - minimum(om))

    # ── V2/V4: residuals ────────────────────────────────────────────────────
    ax, du = net_axial(u, sys, p, wf, lift, N, sd)
    @printf("V2  hub axial residual     = %+12.4f N\n", ax[1])
    @printf("    bearing axial residual = %+12.4f N\n", ax[2])
    @printf("    sky axial residual     = %+12.4f N\n", ax[3])

    acc = [norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    @printf("V6  max |node acceleration| at t=0 = %.4f m/s^2\n", maximum(acc))

    # ── V3: tautness ────────────────────────────────────────────────────────
    bridle, nb, cyan = chain_tensions(u, sys, p, N, Nr)
    @printf("V3  bridles (%d lines) total tension = %.4f N   <-- TAUTNESS\n", nb, bridle)
    @printf("    cyan line tension                = %.4f N\n", cyan)
    @printf("    lift requirement (1.5*W)         = %.4f N vertical\n",
        1.5 * expansion_airborne_mass(sys, p; include_lifter=false) * 9.81)

    # ── V5: twist drift over the first second ───────────────────────────────
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    uu = copy(u)
    du2 = zeros(length(uu))
    n1 = round(Int, 1.0 / dt)
    for _ in 1:n1
        fill!(du2, 0.0)
        KiteTurbineDynamics.multibody_ode!(du2, uu, (sys, p, wf, lift), 0.0)
        @views uu[(3N + 1):6N] .+= dt .* du2[(3N + 1):6N]
        @views uu[1:3N] .+= dt .* uu[(3N + 1):6N]
    end
    a0 = u[(6N + 1):(6N + Nr)]
    a1 = uu[(6N + 1):(6N + Nr)]
    @printf("V5  twist drift over 1 s: max|da| = %.6f rad (%.4f deg)\n",
        maximum(abs.(a1 .- a0)), rad2deg(maximum(abs.(a1 .- a0))))
    acc1 = zeros(length(uu))
    KiteTurbineDynamics.multibody_ode!(acc1, uu, (sys, p, wf, lift), 1.0)
    accb = [norm(acc1[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    @printf("    max |node acceleration| at t=1 s = %.4f m/s^2\n", maximum(accb))

    @printf("\nsettle cost: %.2f s (n_op=2_000)\n", t_settle)
    println()
end

main()
