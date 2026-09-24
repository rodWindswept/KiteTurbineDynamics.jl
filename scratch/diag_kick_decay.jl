# scratch/diag_kick_decay.jl
#
# 2026-09-16.  Is the first-frame kick a one-frame initialisation artefact that
# decays, or a persistent force imbalance?
#
# Context: at handoff the worst node is a RopeNode (mass 0.00297 kg) carrying
# 36.04 N unbalanced, giving acc = 12_123 m/s^2.  The rings are at
# omega = 12.98347 rad/s uniform, so the rotor is NOT initiated stationary.
#
# Method: settle, then run a short ODE window and record max node acceleration,
# cyan tension and back-line tension vs time.  A transient artefact decays within
# a few steps; a real imbalance persists.
#
# Self-checking: asserts finite values and that the window actually advanced.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

sys, u0, p, lift, wf = build_case(nothing, nothing)
u = settle_to_operational_state(sys, u0, p, 60.0; lift_device=lift, wind_fn=wf, n_op=50_000)
N, Nr = sys.n_total, sys.n_ring

max_acc(u) = begin
    d = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(d, u, (sys, p, wf, lift), 0.0)
    maximum(norm(d[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
end

function cyan_back(u)
    T_cy = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        (
            (na == sys.sky_anchor_id && nb == sys.bearing_id) ||
            (na == sys.bearing_id && nb == sys.sky_anchor_id)
        ) || continue
        L = norm(u[(3 * (nb - 1) + 1):(3 * nb)] .- u[(3 * (na - 1) + 1):(3 * na)])
        T_cy += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return T_cy
end

println("=== acc and line tensions after handoff ===")
println("  ", lpad("step", 7), lpad("t s", 9), lpad("max|acc|", 12), lpad("T_cyan", 10))
a0 = max_acc(u)
@assert isfinite(a0)
println(
    "  ",
    lpad(0, 7),
    lpad("0.0", 9),
    lpad(round(a0; digits=1), 12),
    lpad(round(cyan_back(u); digits=2), 10),
)

dt = 4.0e-5
for k in 1:2_000
    sys_step = u
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), k * dt)
    @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
    @views u[1:3N] .+= dt .* u[(3N + 1):6N]
    @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* du[(6N + Nr + 1):(6N + 2Nr)]
    @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]
    u[1:3] .= 0.0
    u[(3N + 1):(3N + 3)] .= 0.0
    u[6N + 1] = 0.0
    u[6N + Nr + 1] = 0.0
    if k in (1, 10, 100, 500, 1_000, 2_000)
        a = max_acc(u)
        @assert isfinite(a)
        println(
            "  ",
            lpad(k, 7),
            lpad(round(k * dt; digits=4), 9),
            lpad(round(a; digits=1), 12),
            lpad(round(cyan_back(u); digits=2), 10),
        )
    end
end
println("\n=== done ===")
