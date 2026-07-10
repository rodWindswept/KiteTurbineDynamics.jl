#!/usr/bin/env julia
# scripts/test_vertex_spoke.jl
# Prototype: ring_vertex_positions() vertex position computation.
# Builds λ=0.69 Reinforced, spins up with motor for 1s, then checks
# vertex positions against design radii (± a few mm).

using KiteTurbineDynamics, Printf, LinearAlgebra, Statistics
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

function main()
    sp = SpokeParams(enabled=true)
    fn = ControlMapHunt.v10_tight_builder(
        r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=0.69)

    sys, u0, p, label = Base.invokelatest(fn)
    @printf("\n=== %s ===\n", label)
    @printf("n_lines=%d  n_ring=%d  n_total=%d\n", p.n_lines, sys.n_ring, sys.n_total)

    N = sys.n_total
    Nr = sys.n_ring
    shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [11.0 * (z / p.h_ref)^(1 / 7), 0.0, 0.0]
    end

    # ── Phase 1: Motor spin-up (1s, k=-200) ─────────────────────────
    sys.k_mppt_ref[] = -200.0
    u = copy(u0)
    print("Motor spin-up (1s, k=-200)... ")
    n1 = round(Int, 1.0 / ControlMapHunt.DT)
    KiteTurbineDynamics.run_canonical_sim!(u, sys, p, wf, n1, ControlMapHunt.DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp)

    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    w_hub = abs(u[6N + Nr + hub_ri])
    @printf("ω_hub=%.1f rad/s (%.0f rpm)\n\n", w_hub, w_hub * 60 / (2π))

    # ── Check ring centers are on-axis ──────────────────────────────
    println("Ring center drift from shaft axis:")
    all_centers_on_axis = true
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        gid === nothing && continue
        rn = (sys.nodes[gid]::RingNode).radius
        pos = u[(3 * (gid - 1) + 1):(3 * gid)]
        proj = dot(pos, shaft) .* shaft
        drift = norm(pos .- proj)
        @printf("  ring %2d: design_R=%6.3f  drift=%.3f mm\n", ri, rn, drift * 1000)
        if drift > 1e-6
            all_centers_on_axis = false
        end
    end
    println(all_centers_on_axis ? "\n✓ All ring centers are on-axis.\n" :
        "\n✗ Some ring centers are off-axis.\n")

    # ── Vertex positions ────────────────────────────────────────────
    alpha = @view u[(6N + 1):(6N + Nr)]

    test_rings = Int[]
    for ri in [2, 3, div(Nr, 2), Nr - 1, Nr]
        gid = sys.ring_ids[ri]
        gid === nothing || push!(test_rings, ri)
    end

    println("Vertex position check (design_R vs actual radii, n=$(p.n_lines) vertices/ring):")
    println("  ring | design_R |  min_R  | mean_R  |  max_R  | max_drift_out_mm")
    println("  -----+----------+---------+---------+---------+------------------")

    max_err_mm = 0.0
    all_pass = true
    for ri in test_rings
        ring_gid = sys.ring_ids[ri]
        node = sys.nodes[ring_gid]::RingNode
        R_design = node.radius

        vertices = KiteTurbineDynamics.ring_vertex_positions(u, sys, ring_gid, p, alpha)

        actual_radii = Float64[]
        for j in 1:size(vertices, 2)
            v = vertices[:, j]
            v_proj = dot(v, shaft) .* shaft
            r = norm(v .- v_proj)
            push!(actual_radii, r)
        end

        drift_out, drift_in = KiteTurbineDynamics.spoke_drift(u, sys, p, alpha, ring_gid)
        max_err_mm = max(max_err_mm, abs(drift_out) * 1000, abs(drift_in) * 1000)

        @printf("   %2d  | %7.3f | %7.3f | %7.3f | %7.3f | %+15.1f\n",
            ri, R_design,
            minimum(actual_radii), mean(actual_radii), maximum(actual_radii),
            drift_out * 1000)

        if max(abs(drift_out), abs(drift_in)) > 0.005
            all_pass = false
        end
    end

    TOL_MM = 5
    println()
    if all_pass
        println("✓ PASS: All vertex positions within ±$(TOL_MM) mm of design radius.")
    else
        println("✗ FAIL: Max vertex drift = $(round(max_err_mm; digits=1)) mm > ±$(TOL_MM) mm.")
    end

    # ── Note on _tilted_ring_basis ──────────────────────────────────
    println()
    println("NOTE: ring_vertex_positions() uses shaft_perp_basis() directly, not")
    println("_tilted_ring_basis(). The latter has TILT_SCALE=0.1 visual amplification")
    println("designed for dashboard rendering, which would introduce non-physical tilt")
    println("(~16° in this test because the bearing sags ~2.9m without lift device).")
    println("For physics computations, use the non-amplified basis from shaft_perp_basis().")

    return all_pass
end

main()
