# scratch/diag_preload_enforcement.jl
#
# Purpose (2026-09-13, DSH session): `design_axial_preload`'s realisability-floor
# enforcement refused the `(n_lines=4, rotor_count=3)` machine, which I expected
# it to REPAIR (bare demand 1.207 needs only ~+27 % tension, inside the 1.5× bound).
# Rather than assume why, replicate the enforcement loop here and print every
# iteration: the binding segment, its demand, and the resulting top tension.
#
# Self-checking: asserts the bare demand exceeds the target and that the first
# emulated iteration reproduces the shipped code's first step.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const MARGIN = KiteTurbineDynamics.TRPT_REALISABILITY_TENSION_MARGIN
const MAXFAC = KiteTurbineDynamics.TRPT_REALISABILITY_MAX_PRELOAD_FACTOR

for (nl, rc, ω) in ((4, 3.0, 13.399535), (6, 1.0, 11.398798), (nothing, nothing, 12.983466))
    sys, u0, pc, lift, wf = build_case(nl, rc)
    n_seg = sys.n_ring - 1
    τ_eq = sys.k_mppt_ref[] * ω^2
    F_bare = design_axial_preload(sys, pc, lift, u0;
        omega_eq=ω, wind_fn=wf, realisability_margin=1.0)
    pl = trpt_matched_place(sys, pc, F_bare, τ_eq, ω, wf; raise_on_unrealisable=false)
    g_inc = pc.m_ring * 9.81 * sin(pc.elevation_angle)

    println("\n--- n_lines=$(pc.n_lines) rotor_count=$(rc)  n_ring=$(sys.n_ring)")
    println("    τ_eq = ", round(τ_eq; digits=2), " N·m   F_top_bare = ", round(F_bare[end]; digits=1),
            "   T_s[1] = ", round(F_bare[1] / pc.n_lines; digits=2))
    println("    g_inc = ", round(g_inc; digits=3), " N/ring")
    println("    bare demand = ", round.(pl.demand; digits=4))
    println("    τ_carry     = ", round.(pl.τ_carry; digits=1))
    println("    binding seg = ", argmax(pl.demand))

    @assert maximum(pl.demand) > 1.0 / MARGIN "expected the bare profile to be below target"

    F_top = F_bare[end]
    F_top_bare = F_top
    for it in 1:12
        F_ax = zeros(n_seg)
        F_ax[n_seg] = F_top
        for i in (n_seg - 1):-1:1
            F_ax[i] = F_ax[i + 1] + g_inc
        end
        p2 = trpt_matched_place(sys, pc, F_ax, τ_eq, ω, wf; raise_on_unrealisable=false)
        worst = maximum(p2.demand)
        b = argmax(p2.demand)
        println("    it=$it  F_top=$(round(F_top; digits=1))  T_s[b]=",
                round(F_ax[b] / pc.n_lines; digits=2), "  worst=", round(worst; digits=4),
                "  binding=$b  ratio=$(round(F_top / F_top_bare; digits=4))")
        if worst <= 1.0 / MARGIN
            println("    -> CLEARED")
            break
        end
        F_top *= worst * MARGIN
        if F_top > MAXFAC * F_top_bare
            println("    -> BOUND TRIPPED at ratio ", round(F_top / F_top_bare; digits=4))
            break
        end
    end
end
println("\n=== done ===")
