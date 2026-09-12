# scratch/liftline_taut_check.jl
#
# READ-ONLY. Is the LIFT LINE taut during the settle?
#
# The sky anchor, bearing and kite form a chain that must be in tension for the
# lift to hold the assembly up.  `update_kite_pos!` projects the kite to exactly
# `line_length` from the sky anchor, so the line should always be taut.
#
# This checks whether that holds DURING the settle (not just after), by comparing
# |kite_pos - sky_anchor| against the design line length at several points, and by
# reporting the lift force the ODE actually applies.
#
# If the line reads shorter than its length at any point, the lift is off and the
# airborne assembly free-falls — which matches the collapse seen when the bridle
# rest length is corrected (scratch/chain_fix_probe.jl).
#
#   scripts/ktd-julia scratch/liftline_taut_check.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    sky = sys.sky_anchor_id
    hub, bear = sys.rotor.node_id, sys.bearing_id
    sd0 = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    @printf("lift line length   = %.4f m\n", lift.line_length)
    @printf("lift elevation     = %.2f deg (p.lifter_elevation)\n", rad2deg(p.lifter_elevation))
    @printf("T_ref (sizing)     = %.3f N   const_tension = %s\n\n",
        lift.T_ref, lift.const_tension)

    # as built
    @printf("as built: |kite - sky| = %.6f m\n", norm(sys.kite_pos .- pos(u0, sky)))
    @printf("  kite_pos = [%.3f %.3f %.3f]\n", sys.kite_pos...)
    @printf("  sky_pos  = [%.3f %.3f %.3f]\n\n", pos(u0, sky)...)

    # settle_to_equilibrium first (no kite update in it), then the op settle
    u_eq = settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    @printf("after settle_to_equilibrium:\n")
    @printf("  sky radial |r| = %.4f  ; |kite-sky| = %.6f m\n",
        norm(pos(u_eq, sky)), norm(sys.kite_pos .- pos(u_eq, sky)))

    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    @printf("\nafter settle_to_operational_state:\n")
    @printf("  sky radial |r| = %.4f\n", norm(pos(u, sky)))
    @printf("  |kite-sky| = %.6f m  (line length %.4f) -> %s\n",
        norm(sys.kite_pos .- pos(u, sky)), lift.line_length,
        norm(sys.kite_pos .- pos(u, sky)) < lift.line_length ? "SLACK" : "taut")
    @printf("  kite_pos = [%.3f %.3f %.3f]\n", sys.kite_pos...)
    @printf("  sky_pos  = [%.3f %.3f %.3f]\n", pos(u, sky)...)

    # what lift force does the ODE apply?
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    msky = (sys.nodes[sky]).mass
    Fsky = msky .* du[(3N + 3 * (sky - 1) + 1):(3N + 3 * sky)]
    @printf("\n  sky net force = [%.2f %.2f %.2f] N  |F| = %.2f  mass = %.3f kg\n",
        Fsky..., norm(Fsky), msky)
    # lift line direction as the ODE sees it
    ldir = sys.kite_pos .- pos(u, sky)
    if norm(ldir) > 1e-6
        @printf("  kite-sky direction = [%.4f %.4f %.4f]\n", (ldir ./ norm(ldir))...)
    end
    @printf("  lift_dir from elevation = [%.4f %.4f %.4f]\n",
        cos(p.lifter_elevation), 0.0, sin(p.lifter_elevation)...)
end

main()
