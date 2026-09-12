# scratch/bearing_motion_probe.jl
#
# READ-ONLY. Measures the lift bearing's motion in the CANONICAL loop
# (run_canonical_sim!'s body) to see whether it whips about.
#
# Background: bearing transverse damping was added deliberately in e83f6ca
# (2026-05-18) "to suppress off-axis precession", but it was added to
# `simulate()` and NEVER to `run_canonical_sim!` (born later in 12bc91b).
# The canonical loop is the one the evaluator and campaign use, so it currently
# has no bearing damper at all.
#
# This reports:
#   - the bearing's perpendicular distance from the shaft axis over time
#   - its transverse speed
#   - the same for the sky anchor
#   - the bridle and cyan tensions, so we can see the state the bearing is in
#
# At the current (broken) chain the bridles are slack, so this measures the
# bearing hanging on the cyan line alone.  Re-run after the chain is fixed.
#
#   scripts/ktd-julia scratch/bearing_motion_probe.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function shaft_axis(u, sys)
    h = pos(u, sys.rotor.node_id)
    n = norm(h)
    return n > 0.1 ? h ./ n : [cos(0.5236), 0.0, sin(0.5236)]
end

function perp_dist(u, sys, gid)
    p3 = pos(u, gid)
    sd = shaft_axis(u, sys)
    return norm(p3 .- dot(p3, sd) .* sd)
end

function perp_speed(u, sys, gid, N)
    v = u[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)]
    sd = shaft_axis(u, sys)
    return norm(v .- dot(v, sd) .* sd)
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    bear, sky = sys.bearing_id, sys.sky_anchor_id

    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)

    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    @printf("canonical dt = %.6e s ; bearing mass = %.3f kg\n\n", dt,
        (sys.nodes[bear]).mass)

    println("canonical loop (run_canonical_sim! body: rope damper only, NO bearing damper):")
    @printf("  %7s %14s %14s %14s %14s\n",
        "t_s", "bear_perp_m", "bear_vperp", "sky_perp_m", "sky_vperp")
    uu = copy(u)
    du = zeros(length(uu))
    steps = max(1, round(Int, 0.5 / dt))
    for rep in 0:16
        t = rep * 0.5
        if rep > 0
            for _ in 1:steps
                fill!(du, 0.0)
                KiteTurbineDynamics.multibody_ode!(du, uu, (sys, p, wf, lift), t)
                @views uu[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
                @views uu[1:3N] .+= dt .* uu[(3N + 1):6N]
                KiteTurbineDynamics.orbital_damp_rope_velocities!(uu, sys, p, 0.05, dt)
                # extract_omega damping (ang_damp = 1.0 in run_canonical_sim!)
                uu[1:3] .= 0.0
                uu[(3N + 1):(3N + 3)] .= 0.0
                if lift !== nothing
                    KiteTurbineDynamics.update_kite_pos!(sys, uu, lift, p, dt)
                end
            end
        end
        @printf("  %7.2f %14.4f %14.4f %14.4f %14.4f\n", t,
            perp_dist(uu, sys, bear), perp_speed(uu, sys, bear, N),
            perp_dist(uu, sys, sky), perp_speed(uu, sys, sky, N))
    end
    println()
end

main()
