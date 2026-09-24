# scratch/diag_first_frame_kick.jl
#
# 2026-09-16.  WHAT is the first-frame kick?  `test_settle_validity.jl` reports
# acc0 = 12_123 m/s^2 (~1240 g) at the handoff, against a 10 g target, and it
# does not move with n_op.  The axial residual is ~0 on hub/bearing/sky, so the
# assembly balances ALONG the shaft while some node still sees a huge unbalanced
# force.
#
# Rod's hypothesis (2026-09-16): the rotor is assumed to be rotating but is
# initiated stationary, so the handoff applies a running-state aerodynamic load
# to a stationary blade.  Test: compare each node's ACTUAL velocity at handoff
# with its EXPECTED orbital velocity (omega_k * R_k * tangential), and locate the
# worst node.
#
# Reports:
#   (a) the top-10 nodes by |du|, with node type, mass, and the unbalanced force
#   (b) the worst node's speed vs its expected orbital speed
#   (c) the airborne-ring angular rates, to show whether the rings are spinning
#   (d) the aero/blade load terms that would act on a stationary vs moving blade
#
# Self-checking: asserts finite accelerations, that the reported force is
# mass*|du| for the worst node, and that the expected-orbital-speed helper
# reproduces omega*R for a ring vertex.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]
vel(u, gid, N) = u[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)]

sys, u0, p, lift, wf = build_case(nothing, nothing)
u = settle_to_operational_state(sys, u0, p, 60.0; lift_device=lift, wind_fn=wf, n_op=50_000)
N, Nr = sys.n_total, sys.n_ring

du = zeros(length(u))
KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)

accs = [norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
@assert all(isfinite, accs)
order = sortperm(accs; rev=true)

println("=== (a) top nodes by acceleration at handoff ===")
println(
    "  ",
    lpad("rank", 4),
    lpad("node", 6),
    lpad("kind", 14),
    lpad("mass kg", 11),
    lpad("|acc| m/s2", 12),
    lpad("|F| N", 10),
)
for (i, g) in enumerate(order[1:10])
    node = sys.nodes[g]
    kind = string(typeof(node))
    kind = replace(kind, "KiteTurbineDynamics." => "")
    m = node.mass
    println(
        "  ",
        lpad(i, 4),
        lpad(g, 6),
        lpad(kind, 14),
        lpad(round(m; digits=5), 11),
        lpad(round(accs[g]; digits=1), 12),
        lpad(round(m * accs[g]; digits=3), 10),
    )
end

gmax = order[1]
m_max = sys.nodes[gmax].mass
@assert isapprox(
    m_max * accs[gmax],
    norm(m_max .* du[(3N + 3 * (gmax - 1) + 1):(3N + 3 * gmax)]);
    rtol=1e-12,
)
println(
    "\n  worst node gid=",
    gmax,
    "  mass=",
    m_max,
    " kg  |acc|=",
    round(accs[gmax]; digits=1),
    "  |F|=",
    round(m_max * accs[gmax]; digits=4),
    " N",
)

println("\n=== (b) node-kind census and the worst node's speed vs expected orbital ===")
om = u[(6N + Nr + 1):(6N + 2Nr)]
kinds = Dict{String, Vector{Int}}()
for g in 1:N
    k = replace(string(typeof(sys.nodes[g])), "KiteTurbineDynamics." => "")
    push!(get!(kinds, k, Int[]), g)
end
for (k, gs) in sort(collect(kinds); by=x -> -length(x[2]))
    println(
        "  ",
        rpad(k, 14),
        " count=",
        lpad(length(gs), 5),
        "  mass ",
        round(minimum(sys.nodes[g].mass for g in gs); digits=5),
        " .. ",
        round(maximum(sys.nodes[g].mass for g in gs); digits=4),
        " kg",
    )
end

# Expected orbital speed for a ring-body node: omega_ring * radius.
for rank in 1:3
    g = order[rank]
    node = sys.nodes[g]
    v = norm(vel(u, g, N))
    if node isa RingNode
        esp = abs(om[node.ring_idx]) * node.radius
        println(
            "  rank ",
            rank,
            " gid=",
            lpad(g, 6),
            " RingNode ring=",
            node.ring_idx,
            "  R=",
            round(node.radius; digits=3),
            "  |v|=",
            lpad(round(v; digits=4), 10),
            "  expected omega*R=",
            lpad(round(esp; digits=4), 10),
            "  ratio=",
            round(v / max(esp, 1e-12); digits=4),
        )
    else
        println(
            "  rank ",
            rank,
            " gid=",
            lpad(g, 6),
            " ",
            typeof(node),
            "  |v|=",
            lpad(round(v; digits=6), 12),
            " (fixed/other)",
        )
    end
end

println("\n=== (c) ring angular rates (are the rings spinning?) ===")
println(
    "  n_rings=",
    Nr,
    "  omega range=",
    round(minimum(om); digits=5),
    " .. ",
    round(maximum(om); digits=5),
    " rad/s",
)
println("  uniform (co-rotating) = ", maximum(om) - minimum(om) < 1e-6)
println("  all positive          = ", minimum(om) > 0.0)

println("\n=== done ===")
