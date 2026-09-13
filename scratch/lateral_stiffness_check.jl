# scratch/lateral_stiffness_check.jl
#
# !! INVALID -- DO NOT QUOTE OR BUILD ON.  Kept only as a record of the mistake.
#
# The displacement method here re-interpolates the rope nodes along STRAIGHT
# CHORDS between ring centres.  The transmission lines are TWISTED helices, so
# that shortens them and produces a fake restoring force of ~500 kN/m -- wrong by
# ~5 orders of magnitude.  The numbers below are meaningless.
#
# The correct answer is analytic: sin(theta) = F_perp / T = 124/1589 = 0.078, so
# the column hangs ~4.7 deg off the design axis = ~1.5 m at the hub.  Confirmed
# against the real machine ("a bit of bowing, like catenary sag") by Rod.
#
# READ-ONLY. Quantifies the perpendicular (shaft-bowing) restoring force.
#
# Gravity on the tilted shaft: 143.2 N total, of which 71.6 N is along the shaft
# and 124.0 N is PERPENDICULAR to it.  "Perpendicular to the shaft" is the
# down-slope direction in the shaft plane -- it makes the column bow, it is not
# horizontal sideways.
#
# The assembly finds equilibrium by bowing until the transmission's restoring
# force balances that 124 N.  This measures the restoring force vs lateral
# displacement of the hub, to get the effective lateral stiffness and hence how
# far the machine has to bow.
#
# Method: hold everything at the settled state, displace the hub perpendicular to
# the shaft by delta, re-interpolate the rope nodes onto the new chords, and read
# the perpendicular force from the ODE.  No relaxation -- just the force law.
#
#   scripts/ktd-julia scratch/lateral_stiffness_check.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id

    u = KiteTurbineDynamics.settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    axis = normalize(pos(u, hub))
    # a unit vector perpendicular to the shaft, in the shaft plane (down-slope)
    up = [0.0, 0.0, 1.0]
    perp = normalize(up .- dot(up, axis) .* axis)

    mh = (sys.nodes[hub]).mass
    @printf("hub mass %.4f kg ; perpendicular gravity component = %.4f N\n",
        mh, norm(mh .* ([0.0, 0.0, -9.81] .- dot([0.0, 0.0, -9.81], axis) .* axis)))
    @printf("\n  %10s %14s %14s %14s\n", "delta_m", "F_perp_N", "k_N/m", "note")

    prev = nothing
    for delta in (0.0, 0.001, 0.005, 0.01, 0.05, 0.1, 0.25, 0.5, 1.0)
        uu = copy(u)
        # move the hub perpendicular
        uu[(3 * (hub - 1) + 1):(3 * hub)] .+= delta .* perp
        # re-interpolate the rope nodes onto the chords implied by the new ring set
        pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(uu, sys, hub, Nr)
        for node in sys.nodes
            node isa RopeNode || continue
            s, j = node.seg_idx, node.line_idx
            ga, gb = sys.ring_ids[s], sys.ring_ids[s + 1]
            ra = isempty(sys.expansion_rotors) ? (sys.nodes[ga]::RingNode).radius :
                 sys.effective_radii[s]
            rb = isempty(sys.expansion_rotors) ? (sys.nodes[gb]::RingNode).radius :
                 sys.effective_radii[s + 1]
            # segment-length-based attachment must total the chord; keep the same
            # relative interpolation the settle uses
            ca = pos(uu, ga)
            cb = pos(uu, gb)
            frac = node.sub_idx / ROPE_SUBSEGS
            uu[(3 * (node.id - 1) + 1):(3 * node.id)] .= ca .+ frac .* (cb .- ca)
        end
        du = zeros(length(uu))
        KiteTurbineDynamics.multibody_ode!(du, uu, (sys, p, wf, lift), 0.0)
        F = mh .* du[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)]
        Fperp = dot(F, perp)
        k = (prev === nothing || delta == 0.0) ? NaN : (Fperp - prev) / (delta - 0.0)
        @printf("  %10.4f %14.4f %14.4f\n", delta, Fperp, k)
        prev = Fperp
    end

    println("\n(restoring force is the change in F_perp as the hub bows; the assembly")
    println(" finds equilibrium where F_perp = 0, i.e. where the transmission's")
    println(" perpendicular reaction cancels gravity's 124 N)")
end

main()
