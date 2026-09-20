# scratch/probe_wired_A.jl
#
# 2026-09-19.  Verify the WIRED drag-included operational-equilibrium polish and
# measure the numbers V6 will gate on:
#   * STRUCTURAL-node max acceleration on the full handoff path
#   * full-network max unbalanced FORCE (N) — mass-robust
#   * V2 drag-inclusive axial residuals at hub/bearing/sky
#   * the drag-free static acc0, for the record
#   * omega and alpha untouched
# Compares against operational_polish=false.

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

function metrics(u, sys, p, wf, lift, N)
    df = zeros(length(u))
    multibody_ode!(df, u, (sys, p, wf, lift), 0.0)
    fs = [norm(@views df[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]  # accelerations
    forces = [sys.nodes[g].mass * fs[g] for g in 1:N]
    structural = [
        g for g in 1:N if
        sys.nodes[g] isa RingNode || g == sys.bearing_id || g == sys.sky_anchor_id
    ]
    struct_acc = maximum(fs[g] for g in structural)
    struct_node = structural[argmax([fs[g] for g in structural])]
    argf = argmax(forces)
    # drag-free structural path (the old V6 metric), for reference only
    us = copy(u)
    @views us[(3N + 1):(6N)] .= 0.0
    ds = zeros(length(us))
    multibody_ode!(ds, us, (sys, p, wf, lift), 0.0)
    static = maximum(norm(@views ds[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
    sd = normalize(@views u[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)])
    ax = Dict{String,Float64}()
    for (nm, gid) in (("hub", sys.rotor.node_id), ("bearing", sys.bearing_id),
                      ("sky", sys.sky_anchor_id))
        m = sys.nodes[gid].mass
        ax[nm] = dot(@views(m .* df[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)]), sd)
    end
    return (; struct_acc, struct_node, maxF=forces[argf], maxF_node=argf,
            maxF_mass=sys.nodes[argf].mass, static, ax, acc_raw=maximum(fs))
end

function show(tag, u, sys, p, wf, lift, N)
    m = metrics(u, sys, p, wf, lift, N)
    @printf("  [%s]\n", tag)
    @printf("     structural full-path acc0 = %8.3f m/s2 (%6.3f g) on node %d (%.5f kg)  [V6 gate < 10 g]\n",
        m.struct_acc, m.struct_acc / 9.81, m.struct_node, sys.nodes[m.struct_node].mass)
    @printf("     network max |F|            = %8.4f N  on node %d (%.5f kg)  [mass-robust]\n",
        m.maxF, m.maxF_node, m.maxF_mass)
    @printf("     network max acc0 (raw)     = %8.3f m/s2 (%6.3f g)\n", m.acc_raw, m.acc_raw / 9.81)
    @printf("     drag-free static acc0      = %8.3f m/s2 (%6.3f g)      [reference only]\n",
        m.static, m.static / 9.81)
    @printf("     V2 axial: hub %8.3f  bearing %7.3f  sky %7.3f N   [gate |.|<50]\n",
        m.ax["hub"], m.ax["bearing"], m.ax["sky"])
    return m
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    println("=== wired settle, campaign seed, n_op = 300_000 ===")

    t0 = @elapsed begin
        uoff = settle_to_operational_state(sys, copy(u0), p, 60.0;
            lift_device=lift, wind_fn=wf, n_op=300_000, operational_polish=false)
    end
    @printf("  polish OFF: %.1f s\n", t0)
    show("operational_polish=false", uoff, sys, p, wf, lift, N)

    t1 = @elapsed begin
        uon = settle_to_operational_state(sys, copy(u0), p, 60.0;
            lift_device=lift, wind_fn=wf, n_op=300_000)
    end
    @printf("  polish ON (default): %.1f s  (+%.1f %%)\n", t1, 100 * (t1 - t0) / t0)
    show("operational_polish=true", uon, sys, p, wf, lift, N)

    @assert uon[(6N + Nr + 1):(6N + 2Nr)] == uoff[(6N + Nr + 1):(6N + 2Nr)] "omega touched"
    @assert uon[(6N + 1):(6N + Nr)] == uoff[(6N + 1):(6N + Nr)] "alpha touched"
    println("  OK: omega and alpha identical")
    println("=== done ===")
end

main()
