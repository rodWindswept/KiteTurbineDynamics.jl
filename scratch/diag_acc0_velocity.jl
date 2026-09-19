# scratch/diag_acc0_velocity.jl
#
# 2026-09-16.  Is `acc0` a STATIC force imbalance, or the settle's residual
# VELOCITY showing up through the damper and the drag?
#
# WHY.  scratch/diag_acc0_node.jl showed the argmax is a RopeNode of 2.25 g
# carrying 39.3 N, i.e. acc0 is a light-node artefact, while ring 11 carries a
# real 662 N imbalance.  ACTIVE.md item 3's own discipline says the static force
# path must be "call[ed] with velocities zero, so the rope material damper and
# the aerodynamic drag vanish and the force field is conservative".  The test
# does NOT do that: it calls `multibody_ode!(du, u, ...)` on the SETTLED state,
# whose velocity block may be non-zero.  If so, `acc0` includes damping forces
# that no equilibrium solver can remove.
#
# This measures acc0 three ways on the SAME settled state:
#   (1) as-is                       — what the test measures
#   (2) translational velocities 0  — damper + drag vanish, rotor loads (from ω) stay
#   (3) all velocities 0            — also removes the rotation (changes the load case)
#
# Reports the residual velocity magnitudes too, so the mechanism is read off the
# record rather than assumed.

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

sys, u0, p, lift, wf = build_case(nothing, nothing)
N, Nr = sys.n_total, sys.n_ring
println("=== machine: n_total = ", N, "  n_ring = ", Nr, " ===")

u = settle_to_operational_state(sys, u0, p, 60.0;
    lift_device=lift, wind_fn=wf, n_op=300_000)

# State layout: u[1:3N] positions, u[3N+1:6N] node velocities,
# u[6N+1:6N+Nr] twist angles alpha, u[6N+Nr+1:6N+2Nr] angular rates omega.
vblock = u[(3N + 1):(6N)]
om = u[(6N + Nr + 1):(6N + 2Nr)]

function acc0_of(state)
    du = zeros(length(state))
    KiteTurbineDynamics.multibody_ode!(du, state, (sys, p, wf, lift), 0.0)
    a = [norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    gmax = argmax(a)
    return maximum(a), gmax, sys.nodes[gmax].mass
end

u_a = copy(u)
u_b = copy(u); u_b[(3N + 1):(6N)] .= 0.0                 # translational vel 0
u_c = copy(u); u_c[(3N + 1):(6N)] .= 0.0
u_c[(6N + Nr + 1):(6N + 2Nr)] .= 0.0                     # also omega 0

println("\n=== residual velocities in the settled state ===")
@printf("  node velocity block:  max |v| = %.6e m/s   rms = %.6e m/s\n",
    maximum(abs, vblock), sqrt(sum(abs2, vblock) / length(vblock)))
@printf("  omega block:          min = %.6f   max = %.6f rad/s\n",
    minimum(om), maximum(om))

println("\n=== acc0 on the SAME settled state, three ways ===")
println("  ", lpad("case", 34), lpad("acc0 m/s2", 12), lpad("g", 10),
        lpad("argmax", 8), lpad("mass kg", 10))
for (tag, st) in (("(1) as-is (the test's metric)", u_a),
                  ("(2) translational vel = 0", u_b),
                  ("(3) all vel = 0 (incl. omega)", u_c))
    a0, gmax, m = acc0_of(st)
    @printf("  %-34s %12.2f %10.1f %8d %10.6f\n", tag, a0, a0 / 9.81, gmax, m)
end
println("\n=== done ===")
