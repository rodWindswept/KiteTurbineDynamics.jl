# scratch/diag_preload_margins.jl
#
# Purpose (2026-09-13, DSH session): the handover
# `handover-2026-09-13-lift-chain-and-realisability.md` §2 reports the fast suite
# RED with two failures in test_settle_preload_consistency.jl (:79 err=0.673 vs
# 0.15; :107 err=114.0 vs 0.60), and §11 step 3 asks for the :107 failure to be
# diagnosed.  Re-running the suite on the CURRENT tree gives 2086 pass / 0 fail /
# 2 errored / 3 broken — both preload testsets PASS.  This probe measures the
# actual margins so the correction rests on numbers, not on a pass count.
#
# It reuses the test file's own `settled_case` (including the file runs its
# testsets, which pass) so there is NO second copy of the harness to drift.
#
# Self-checking: asserts the invariant the test asserts, and errors out rather
# than printing a number if its own setup is wrong.

using Test, KiteTurbineDynamics, LinearAlgebra

const TESTFILE = joinpath(dirname(@__DIR__), "test", "test_settle_preload_consistency.jl")
include(TESTFILE)   # defines settled_case / build_case in Main

const CASES = [
    ("campaign seed  (nothing, nothing)", nothing, nothing, 0.15),
    ("4 lines / 3 rotors  (4, 3.0)", 4, 3.0, 0.15),
    ("6 lines / 1 rotor   (6, 1.0)", 6, 1.0, 0.60),
]

println("\n=== measured preload margins (current tree) ===")
for (label, nl, rc, thr) in CASES
    sys, pc, u, intended, ef = settled_case(nl, rc)

    # The invariant the probe itself depends on: the instrument and the design
    # vector must be the same length, or the comparison below is meaningless.
    @assert length(ef.segment_tension) == length(intended) == sys.n_ring - 1

    err = maximum(abs.(ef.segment_tension .- intended) ./ intended)
    worst = argmax(abs.(ef.segment_tension .- intended) ./ intended)

    println("\n--- $label  (n_lines=$(pc.n_lines), n_ring=$(sys.n_ring), thr=$thr)")
    println("    err (max rel) = ", round(err; digits=6), "   -> ", err < thr ? "PASS" : "FAIL")
    println("    worst segment = ", worst, "  intended = ", round(intended[worst]; digits=3),
            " N  achieved = ", round(ef.segment_tension[worst]; digits=3), " N")
    println("    twist seg1 = ", round(ef.segment_twist_deg[1]; digits=2), " deg (gate > 30)")
    println("    intended  = ", round.(intended; digits=2))
    println("    achieved  = ", round.(ef.segment_tension; digits=2))
end
println("\n=== done ===")
