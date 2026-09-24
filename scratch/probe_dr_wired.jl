# scratch/probe_dr_wired.jl
#
# 2026-09-19.  Verify the WIRED static-equilibrium polish in
# `src/initialization.jl` (not the prototype).  Checks the things the prototype
# never checked:
#
#   1. `acc0_static` (the V6 metric) clears 10 g.
#   2. omega and alpha are untouched by the polish.
#   3. The velocity field at handoff is still the settle's convention: rope nodes
#      at their orbital velocity, ring translational velocities zero.
#   4. The LIFT LINE is taut at the handoff (the polish moves the sky anchor, so
#      this is the one physical feedback the prototype ignored).
#   5. The force balance residuals (hub / bearing / sky).
#   6. The preload-consistency invariant that `test_settle_preload_consistency.jl`
#      guards: settled segment tension == intended preload F_ax/n_lines.
#   7. `static_polish=false` reproduces the old 29 g state.

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

function static_acc0(u, sys, p, wf, lift, N)
    u_static = copy(u)
    @views u_static[(3N + 1):(6N)] .= 0.0
    du = zeros(length(u_static))
    KiteTurbineDynamics.multibody_ode!(du, u_static, (sys, p, wf, lift), 0.0)
    return maximum(norm(@views du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
end

function report(tag, u, sys, p, wf, lift)
    N, Nr = sys.n_total, sys.n_ring
    a = static_acc0(u, sys, p, wf, lift, N)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    @printf("  [%s] acc0_static = %.3f m/s2 (%.3f g)\n", tag, a, a / 9.81)
    for (nm, gid) in (
        ("hub", sys.rotor.node_id), ("bearing", sys.bearing_id), ("sky", sys.sky_anchor_id)
    )
        m = sys.nodes[gid].mass
        f = norm(@views m .* du[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)])
        @printf("      residual %-8s %.3f N\n", nm, f)
    end
    # Velocity field at handoff.
    vtrans = maximum(
        norm(@views u[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for
        g in 1:N if sys.nodes[g].mass < 1e29
    )
    @printf("      max |v_trans| over moving nodes = %.4f m/s\n", vtrans)
    for g in 1:N
        sys.nodes[g] isa RingNode || continue
        sys.nodes[g].mass > 1e29 && continue
        vn = norm(@views u[(3N + 3 * (g - 1) + 1):(3N + 3 * g)])
        vn > 1e-9 &&
            @printf("      ring node %d has |v_trans| = %.3e m/s (expected 0)\n", g, vn)
    end
    # Lift line tautness at handoff.
    sa = @views u[(3 * (sys.sky_anchor_id - 1) + 1):(3 * sys.sky_anchor_id)]
    line_dist = norm(sys.kite_pos .- sa)
    @printf(
        "      lift line: |kite - sky| = %.4f m vs line_length = %.4f m  (taut if >= %.4f)\n",
        line_dist,
        lift.line_length,
        0.99 * lift.line_length
    )
    f_lift = lift_force_applied(u, sys, p, wf, lift)
    @printf("      applied lift force on sky = %.3f N\n", norm(f_lift))
    return a
end

"Force applied to the sky anchor by the lift device (test copy)."
function lift_force_applied(u, sys, p, wf, lift)
    N = sys.n_total
    du_on = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du_on, u, (sys, p, wf, lift), 0.0)
    du_off = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du_off, u, (sys, p, wf), 0.0)
    g = sys.sky_anchor_id
    m = sys.nodes[g].mass
    return m .* (@views du_on[(3N + 3 * (g - 1) + 1):(3N + 3 * g)] .-
        du_off[(3N + 3 * (g - 1) + 1):(3N + 3 * g)])
end

function main()
    # ── 1. Campaign seed at the V6 horizon ────────────────────────────────
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    println("=== campaign seed, n_op = 300_000 ===")

    t_old = @elapsed begin
        u_old = settle_to_operational_state(
            sys,
            copy(u0),
            p,
            60.0;
            lift_device=lift,
            wind_fn=wf,
            n_op=300_000,
            static_polish=false,
        )
    end
    @printf("  static_polish=false settle: %.1f s\n", t_old)
    a_old = report("polish OFF", u_old, sys, p, wf, lift)

    t_new = @elapsed begin
        u_new = settle_to_operational_state(
            sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
        )
    end
    @printf(
        "  static_polish=true  settle: %.1f s  (+%.1f %%)\n",
        t_new,
        100 * (t_new - t_old) / t_old
    )
    a_new = report("polish ON", u_new, sys, p, wf, lift)
    @printf(
        "  acc0 %.3f -> %.3f m/s2   (V6 bar 98.1)  -> %s\n",
        a_old,
        a_new,
        a_new < 10.0 * 9.81 ? "PASS" : "FAIL"
    )

    @assert u_new[(6N + Nr + 1):(6N + 2Nr)] == u_old[(6N + Nr + 1):(6N + 2Nr)] "polish touched omega"
    @assert u_new[(6N + 1):(6N + Nr)] == u_old[(6N + 1):(6N + Nr)] "polish touched alpha"
    println("  OK: omega and alpha identical between polish ON and OFF")

    # ── 2. Preload consistency (test/test_settle_preload_consistency.jl) ──
    println("\n=== preload consistency, n_op = 2_000 ===")
    sys2, u02, pc, lift2, wf2 = build_case(nothing, nothing)
    for (tag, polish) in (("OFF", false), ("ON", true))
        u2 = settle_to_operational_state(
            sys2,
            copy(u02),
            pc,
            60.0;
            lift_device=lift2,
            wind_fn=wf2,
            n_op=2_000,
            static_polish=polish,
        )
        ω = u2[6N + Nr + 1]
        F_ax = design_axial_preload(sys2, pc, lift2, u02; omega_eq=ω, wind_fn=wf2)
        intended = F_ax ./ pc.n_lines
        ef = KiteTurbineDynamics.capture_extended(u2, sys2, pc, 0.0, wf2, lift2)
        err = maximum(abs.(ef.segment_tension .- intended) ./ intended)
        @printf(
            "  [%s] max rel tension err vs intended preload = %.5f  (test bar 1e-3)  twist1 = %.2f deg\n",
            tag,
            err,
            ef.segment_twist_deg[1]
        )
    end

    return println("=== done ===")
end

main()
