# scratch/diag_preload_reference.jl
#
# Purpose (2026-09-13, DSH session): `src/initialization.jl:961` reads
#
#     ω = omega_eq > 0.0 ? omega_eq : 12.983466
#
# a hardcoded fallback that is the CAMPAIGN SEED's own equilibrium ω.  The guard
# test `test_settle_preload_consistency.jl` calls `design_axial_preload(sys, pc,
# lift, u0)` with no `omega_eq`, so its `intended` reference is computed at the
# seed's ω for EVERY design.  That would explain why the seed case agrees to
# 1e-6 while the non-seed cases sit 2.3 % / 13.2 % off.
#
# This probe compares the settled tension against TWO references:
#   intended_test = design_axial_preload(...)                (ω → hardcoded fallback)
#   intended_own  = design_axial_preload(...; omega_eq=ω)     (the settle's own ω)
#
# `intended_own` is the reference the settle actually prescribed, so err_own is
# the honest measure of settle↔ODE coherence.  If err_own << err_test, the guard's
# reference is the wrong quantity and its pass is not evidence of consistency.
#
# Self-checking: asserts the two references are equal for the seed (whose ω IS
# the fallback) and differ for the others; errors out rather than printing if not.

using Test, KiteTurbineDynamics, LinearAlgebra

include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

const CASES = [
    ("campaign seed  (nothing, nothing)", nothing, nothing),
    ("4 lines / 3 rotors  (4, 3.0)", 4, 3.0),
    ("6 lines / 1 rotor   (6, 1.0)", 6, 1.0),
]
const OMEGA_FALLBACK = 12.983466

println("\n=== preload consistency against two references ===")
for (label, nl, rc) in CASES
    sys, u0, pc, lift, wf = build_case(nl, rc)
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    N, Nr = sys.n_total, sys.n_ring
    ω = u[6N + Nr + 1]
    ef = capture_extended(u, sys, pc, 0.0, wf, lift)

    F_test = design_axial_preload(sys, pc, lift, u0)
    F_own = design_axial_preload(sys, pc, lift, u0; omega_eq=ω)

    intended_test = F_test ./ pc.n_lines
    intended_own = F_own ./ pc.n_lines
    err_test = maximum(abs.(ef.segment_tension .- intended_test) ./ intended_test)
    err_own = maximum(abs.(ef.segment_tension .- intended_own) ./ intended_own)

    same = isapprox(F_test, F_own; rtol=1e-6)
    # The seed's ω IS the hardcoded fallback (to ~8 s.f.), so for the seed the two
    # references must coincide; for every other design they must differ.
    if nl === nothing
        @assert same "seed references should coincide (ω_eq = $ω vs fallback $OMEGA_FALLBACK)"
    else
        @assert !same "non-seed references should differ (ω_eq = $ω vs fallback $OMEGA_FALLBACK)"
    end

    println("\n--- $label   (n_lines=$(pc.n_lines), n_ring=$Nr)")
    println("    settled ω = ", round(ω; digits=6), "   fallback = ", OMEGA_FALLBACK,
            "   (Δω = ", round(abs(ω - OMEGA_FALLBACK); digits=4), ")")
    println("    references identical? ", same)
    println("    err vs test reference (thr used) = ", round(err_test; digits=6))
    println("    err vs OWN reference  (honest)   = ", round(err_own; digits=6))
    println("    worst |achieved - own| = ",
            round(maximum(abs.(ef.segment_tension .- intended_own)); digits=4), " N")
end
println("\n=== done ===")
