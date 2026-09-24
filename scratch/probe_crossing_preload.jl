# scratch/probe_crossing_preload.jl
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const KTD = KiteTurbineDynamics

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    τ_eq = sys.k_mppt_ref[] * 13.452^2

    println("Sweeping F_top to find crossing-safe preload:")
    n_seg = Nr - 1
    g_inc = p.m_ring * 9.81 * sin(p.elevation_angle)

    for F_top_candidate in 1250.0:25.0:1450.0
        F_ax = zeros(n_seg)
        F_ax[n_seg] = F_top_candidate
        for i in (n_seg - 1):-1:1
            F_ax[i] = F_ax[i + 1] + g_inc
        end

        place = KTD.trpt_matched_place(
            sys, p, F_ax, τ_eq, 13.452, wf; raise_on_unrealisable=false
        )

        # Build state vector u to check twist_collapse_check
        u = copy(u0)
        for k in 1:Nr
            gid = sys.ring_ids[k]
            u[(3 * (gid - 1) + 1):(3 * gid)] .= place.ctrs[k]
            u[6N + k] = place.α[k]
        end

        tr = KTD.twist_collapse_check(u, sys)
        @printf(
            "  F_top = %7.1f N | max demand = %.4f | max twist = %5.2f° | dastar = %5.2f° | ratio = %6.4f | crossed = %s\n",
            F_top_candidate,
            maximum(place.demand),
            rad2deg(maximum(place.α[2:end] .- place.α[1:(end - 1)])),
            54.25,
            tr.max_ratio,
            tr.crossed ? "YES (FAIL)" : "NO (PASS)"
        )
    end
end

main()
