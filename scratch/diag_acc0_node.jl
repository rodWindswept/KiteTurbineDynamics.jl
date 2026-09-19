# scratch/diag_acc0_node.jl
#
# 2026-09-16.  WHICH node carries the 1240 g first-frame acceleration, and is it
# a real force imbalance or a light-node artefact?
#
# WHY.  `test_settle_validity.jl` V6 is the last remaining `@test_broken`:
#
#     @test_broken acc0 < 10.0 * 9.81      # measured ~12_100 m/s^2 (~1240 g)
#
# Its own comment records the puzzle: at the converged settle the AXIAL residual
# is ~0 on hub, bearing and sky, yet some node still sees a huge acceleration,
# and it does not move with `n_op`.  Two very different diagnoses fit that
# sentence, and they need opposite fixes:
#
#   (a) a REAL transverse imbalance on a structural node (the coupled
#       position+twist equilibrium the static solver exists to solve), or
#   (b) a LIGHT node (a rope sub-seg node) carrying a moderate absolute force,
#       so `a = F/m` is large while the force is physically small.
#
# ACTIVE.md item 3 plans a dynamic-relaxation solver.  That is the right answer
# for (a).  For (b) the solver would chase a mass artefact, so measure first.
#
# Reports the top nodes by |a| with their type, mass, |F| = m|a| and the force
# components, so the two cases are distinguishable from the record.
#
# Pre-flight (docs/agents/physics-topology.md §5): item 1 — name the node type
# before interpreting it.  Item 7 — a guard may be silently no-op'ing.

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

node_kind(n) = string(nameof(typeof(n)))

"Describe a node's identity compactly (line/seg/sub for rope nodes)."
function node_desc(n)
    if n isa KiteTurbineDynamics.RopeNode
        return "line=$(n.line_idx) seg=$(n.seg_idx) sub=$(n.sub_idx)"
    elseif n isa KiteTurbineDynamics.RingNode
        return "ring_idx=$(n.ring_idx)"
    else
        return "-"
    end
end

sys, u0, p, lift, wf = build_case(nothing, nothing)
N, Nr = sys.n_total, sys.n_ring
println("=== machine: n_total = ", N, "  n_ring = ", Nr, " ===")

u = settle_to_operational_state(sys, u0, p, 60.0;
    lift_device=lift, wind_fn=wf, n_op=300_000)

du = zeros(length(u))
KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)

# Node acceleration lives in du[3N+1 : 6N]; du[1:3N] is velocity.
acc(g) = du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]

rows = Vector{NamedTuple}()
for g in 1:N
    n = sys.nodes[g]
    a = norm(acc(g))
    m = n.mass
    push!(rows, (; gid=g, a=a, m=m, F=m * a, kind=node_kind(n), desc=node_desc(n),
                 ax=acc(g)[1], ay=acc(g)[2], az=acc(g)[3]))
end
sort!(rows; by=r -> -r.a)

println("\n=== top 15 nodes by |a| (a = F/m) ===")
println("  ", lpad("gid", 5), lpad("kind", 12), lpad("mass kg", 10),
        lpad("|a| m/s2", 11), lpad("|a| g", 8), lpad("|F| N", 9),
        lpad("Fx", 9), lpad("Fy", 9), lpad("Fz", 9), "  ident")
for r in rows[1:min(15, length(rows))]
    @printf("  %5d %-12s %10.5f %11.2f %8.1f %9.4f %9.3f %9.3f %9.3f  %s\n",
        r.gid, r.kind, r.m, r.a, r.a / 9.81, r.F, r.ax * r.m, r.ay * r.m, r.az * r.m,
        r.desc)
end

println("\n=== the test's metric: max over ALL nodes ===")
worst = rows[1]
println("  argmax = node ", worst.gid, " (", worst.kind, " ", worst.desc, ")")
@printf("  |a| = %.2f m/s^2  (%.1f g)   mass = %.6f kg   |F| = %.4f N\n",
    worst.a, worst.a / 9.81, worst.m, worst.F)

# Compare with the structural nodes only: if the worst STRUCTURAL node is far
# below the threshold, the accelerometer is measuring the rope discretisation,
# not an unbalanced machine.
struct_nodes = filter(r -> !(r.kind == "RopeNode"), rows)
println("\n=== max over STRUCTURAL nodes only (ring/bearing/sky) ===")
for r in struct_nodes[1:min(6, length(struct_nodes))]
    @printf("  %5d %-12s mass=%9.5f kg  |a|=%9.2f m/s^2 (%7.2f g)  |F|=%9.4f N  %s\n",
        r.gid, r.kind, r.m, r.a, r.a / 9.81, r.F, r.desc)
end

rope_rows = filter(r -> r.kind == "RopeNode", rows)
println("\n=== rope-node population ===")
if !isempty(rope_rows)
    ms = [r.m for r in rope_rows]
    @printf("  count = %d   mass min/median/max = %.3e / %.3e / %.3e kg\n",
        length(rope_rows), minimum(ms), sort(ms)[cld(length(ms), 2)], maximum(ms))
    @printf("  |a| min/median/max = %.2f / %.2f / %.2f m/s^2\n",
        minimum(r.a for r in rope_rows),
        sort([r.a for r in rope_rows])[cld(length(rope_rows), 2)],
        maximum(r.a for r in rope_rows))
end
println("\n=== done ===")
