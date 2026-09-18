# test/test_dt_guard.jl
#
# 2026-09-16.  STATIC guard: no test may hardcode an integration time step.
#
# WHY.  `stable_dt_for_system` is a function of the BUILT system's shortest TRPT
# sub-segment:
#
#     min(dt_ref, dt_ref * sqrt(Lmin / L_ref) / margin)     # 4e-5, 0.5 m, 1.5
#
# so the canonical `4e-5` is calibrated for 0.5 m sub-segments and is NOT the
# stable step for a finer mesh.  Because of the 1.5 margin it only equals `dt_ref`
# when `Lmin >= margin^2 * L_ref = 1.125 m`, so `4e-5` is not stable for any
# realistically fine-meshed build.  The 5 kW taper builds ~0.29 m sub-segments,
# for which it returns ~2.04e-5 — a factor 1.96 over the stability limit.
#
# This is not hypothetical.  test_rope_break.jl:141-144 records the damage: at the
# fixed 4e-5 "the seed's short transmission sub-segs ... blow the rope tension to
# ~2.76 MN on the settle->run transition (false break)".  It was fixed in `run_r3`
# by switching to `stable_dt_for_system`; the literal survived in neighbouring
# code.  A hardcoded dt therefore pins a test to one geometry and silently rots
# when the geometry changes.
#
# The rule.  A test's `dt` is a FACILITY, not its subject, so it must be derived.
# Stability is asserted where resolution is the subject — the rope-resolution
# guard testset.  Two acceptance files already derive it
# (test_rope_break.jl run_r3, test_jtheta_no_reversal.jl), and
# test_settle_drag_alignment.jl was converted on 2026-09-16.
#
# Self-checking, and deliberately narrow: it scans for `dt`/`DT` assigned a
# numeric literal, or passed as a bare numeric literal to run_canonical_sim!.
# It does not police unrelated numbers, and it does not require any particular
# dt value — only that the value comes from `stable_dt_for_system`.
#
# SCOPE: `test/` only.  `scripts/` is deliberately NOT scanned.  It holds
# exploratory one-off diagnostics for which pinning one geometry is often the
# point, so a blanket rule there would produce noise rather than safety.  The
# scripts that feed published or campaign results are audited by hand and fixed
# as found: `scripts/record_ramp_traces.jl` was converted on 2026-09-16.  The
# PRODUCTION paths are the ones that must never drift, and both now derive the
# step (`objective_evaluator.jl:567`, `objective_evaluator_ramp.jl`).

using Test

const TEST_DIR = @__DIR__

# Files with a known, documented reason to keep a fixed step.  Keep this list
# EMPTY if at all possible: each entry is a test pinned to one geometry.
const ALLOWED_FIXED_DT = Dict{String,String}(
    # The 1 ms dashboard step is the SUBJECT here, not a facility: the testset
    # demonstrates that the explicit brake Euler velocity constraint clamps the
    # PTO without the ~4 us Euler limit the brake model alone would need.  The
    # step size is what is under test, so converting it would destroy the test.
    "test_bearing_alignment.jl" => "1 ms dashboard step is the subject (brake constraint)",
)

"""Return (line number, text) for each hardcoded dt/DT assignment or dt argument."""
function hardcoded_dt_lines(path::AbstractString)
    hits = Tuple{Int,String}[]
    for (i, ln) in enumerate(eachline(path))
        s = strip(ln)
        startswith(s, "#") && continue
        # `dt = 4e-5`, `DT = 4e-5`, `dt = 0.001`, with optional `const`
        m = match(r"\b(?:const\s+)?[dD][tT]\s*=\s*[0-9]", s)
        if m !== nothing
            push!(hits, (i, s))
            continue
        end
        # a bare numeric literal in the dt POSITION of the canonical integrator:
        #   run_canonical_sim!(u, sys, pc, wind, n_steps, dt; ...)
        # The dt is the 6th positional argument, so require exactly five
        # comma-separated arguments before it.  A looser pattern matches
        # `n_steps` and flags correct call sites.
        # dt must START with a digit: a derived `dt3`/`dt` is the correct form.
        # dt must START with a digit (optionally signed): a derived `dt3`/`dt`
        # or a call like `window_steps(...)` is the CORRECT form and must not be
        # flagged.  Permissive about what precedes the digit, because a nested
        # call contains commas.
        m2 = match(r"run_canonical_sim!\(.*,\s*[0-9][0-9.eE+-]*\s*[;)]", s)
    end
    return hits
end

@testset "no hardcoded integration time step in tests" begin
    files = filter(f -> endswith(f, ".jl"), readdir(TEST_DIR; join=true))
    @test !isempty(files)

    offenders = Pair{String,Vector{Tuple{Int,String}}}[]
    for f in files
        base = basename(f)
        base == basename(@__FILE__) && continue          # this file names the pattern
        haskey(ALLOWED_FIXED_DT, base) && continue
        hits = hardcoded_dt_lines(f)
        isempty(hits) || push!(offenders, base => hits)
    end

    if !isempty(offenders)
        for (base, hits) in offenders
            for (ln, s) in hits
                @info "hardcoded dt" file = base line = ln text = s
            end
        end
    end
    @test isempty(offenders)
end
