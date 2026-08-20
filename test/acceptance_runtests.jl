# test/acceptance_runtests.jl — SLOW ACCEPTANCE SUITE (~18 min, parallel)
#
# The five ODE-heavy acceptance tests. Each builds a genome, settles it
# (30,000 steps) and runs a 5-30 s simulation window at dt=4e-5. These are
# the DYNAMIC checks that a static unit test cannot see:
#
#   test_evaluator_v13.jl        (B1-B7)  evaluator rejects collapse, flywheel
#                                         decay and hub-divergence; accepts
#                                         a healthy seed.
#   test_gate_v13.jl             (A1-A4)  gate reads ground-ring power
#                                         (P_gen = tau_gen*omega_gnd) and the
#                                         twist detector, not the hub freewheel.
#   test_rope_break.jl           (R1-R3)  SK99 3.5% strain rope-break; bounded
#                                         tension; seed lands in its known band.
#   test_rotor_power_realism.jl  (P1-P4)  Betz limit, cp table, no divergence.
#   test_settle_drag_alignment.jl (A-E)   settle omega matches the 20 s ODE
#                                         final (drag-alignment); drag model sane.
#
# WHY NOT IN runtests.jl: these five are ~35 min of the suite when run in
# sequence. They run here as five INDEPENDENT subprocesses in PARALLEL
# (~18 min wall-clock, bounded by the slowest file, test_evaluator_v13.jl),
# so the fast unit suite stays fast.
#
# DO NOT wire these files into test/runtests.jl. If you do, the default suite
# jumps from ~3.5 min to ~40 min. See DECISIONS.md [2026-08-20].
#
# CI runs this file only when the paths below change (see
# .github/workflows/acceptance.yml). The pre-push hook warns on the same paths.
#
# Run:  julia --project=. test/acceptance_runtests.jl

const ACCEPTANCE_FILES = [
    "test_evaluator_v13",
    "test_gate_v13",
    "test_rope_break",
    "test_rotor_power_realism",
    "test_settle_drag_alignment",
]

# Launch each acceptance file as its own julia process. Each file is a
# standalone script (it does `using KiteTurbineDynamics` and includes its own
# dependencies), so separate processes give real parallelism with no shared
# state between tests. Everything lives in main() so the `failed` flag is a
# proper local — a bare top-level `for` would hit Julia's soft-scope rules and
# silently leave the global `failed` as `false` (masking a red run as exit 0).
function main()
    procs = [run(`julia --project=. test/$f.jl`, wait=false) for f in ACCEPTANCE_FILES]

    failed = false
    for (f, p) in zip(ACCEPTANCE_FILES, procs)
        wait(p)
        if p.exitcode == 0
            println("PASS  $f.jl")
        else
            println("FAIL  $f.jl  (exit $(p.exitcode))")
            failed = true
        end
    end
    return failed
end

exit(main() ? 1 : 0)
