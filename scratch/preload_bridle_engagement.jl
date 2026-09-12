# scratch/preload_bridle_engagement.jl
#
# READ-ONLY. The bridles (bearing -> hub) are the load path that lets the lift
# chain carry the topmost rotor.  On the SETTLED state they measure slack:
# rest 6.462198 m, achieved 3.992357 m, tension 0.0000 N.
#
# This measures whether they engage during an actual run, i.e. whether the settle
# leaves the machine in a different bridle configuration from the one it runs in.
# If they engage in the first second or two, the settle start state is inconsistent
# with the running state -- a settle<->run mismatch of the same family as the
# wind-up, and it would not be visible in a `t=0` snapshot.
#
#   scripts/ktd-julia scratch/preload_bridle_engagement.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

# total bridle tension: sub-segments joining bearing <-> hub
function bridle_tension(u, sys)
    hub, bear = sys.rotor.node_id, sys.bearing_id
    tot = 0.0
    n = 0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        L = norm(pos(u, nb) .- pos(u, na))
        tot += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        n += 1
    end
    return tot, n
end

function cyan_tension(u, sys)
    bear, sky = sys.bearing_id, sys.sky_anchor_id
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == bear && nb == sky) || (na == sky && nb == bear)) || continue
        L = norm(pos(u, nb) .- pos(u, na))
        return ss.EA * max(0.0, (L - ss.length_0) / ss.length_0), ss.length_0, L
    end
    return 0.0, 0.0, 0.0
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub, bear = sys.rotor.node_id, sys.bearing_id

    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)

    tb, nb = bridle_tension(u, sys)
    tc, L0, L = cyan_tension(u, sys)
    d_hb = norm(pos(u, bear) .- pos(u, hub))
    @printf("SETTLED state:\n")
    @printf("  bridles (%d):  total tension = %10.4f N\n", nb, tb)
    @printf("  cyan:          tension = %10.4f N  (L0=%.6f L=%.6f)\n", tc, L0, L)
    @printf("  |bearing - hub| = %.6f m   (bridle rest length = %.6f m)\n\n",
        d_hb, sys.sub_segs[193].length_0)

    # ── step the canonical loop and watch the bridles engage ──────────────────
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    uu = copy(u)
    du = zeros(length(uu))
    steps_per_report = max(1, round(Int, 0.25 / dt))
    @printf("stepping the canonical loop, dt=%.4e, reporting every 0.25 s:\n", dt)
    @printf("  %8s %14s %14s %14s %14s\n",
        "t_s", "bridle_T_N", "cyan_T_N", "|bear-hub|", "hub_axial_N")
    sd = normalize(pos(uu, hub))
    m_hub = (sys.nodes[hub]::RingNode).mass
    for rep in 0:24
        t = rep * 0.25
        if rep > 0
            for _ in 1:steps_per_report
                fill!(du, 0.0)
                KiteTurbineDynamics.multibody_ode!(du, uu, (sys, p, wf, lift), t)
                @views uu[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
                @views uu[1:3N] .+= dt .* uu[(3N + 1):6N]
            end
        end
        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, uu, (sys, p, wf, lift), t)
        ax = m_hub * dot(du[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)], sd)
        b, _ = bridle_tension(uu, sys)
        c, _, _ = cyan_tension(uu, sys)
        @printf("  %8.2f %14.4f %14.4f %14.6f %14.4f\n",
            t, b, c, norm(pos(uu, bear) .- pos(uu, hub)), ax)
    end
    println()
end

main()
