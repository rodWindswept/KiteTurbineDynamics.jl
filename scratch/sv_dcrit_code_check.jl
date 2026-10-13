#!/usr/bin/env julia
# scratch/sv_dcrit_code_check.jl — science-validator, 2026-10-13.
#
# The δcrit code call for the twist-limit close-out. Calls the authority
# `trpt_twist_limit` (src/trpt_twist_limit.jl) on the extract's own
# segment geometry and gates the result against the stored digits with
# exact Float64 equality. Static; no simulator. Pairs with the plate
# census and hermes's record leg (scratch/hermes_dcrit_record_check.*).

using KiteTurbineDynamics
using Printf

const EX = joinpath(pwd(), "docs", "reporting", "figures", "pair-extract",
                    "extract-winner-operating-point.csv")

function main()
    ok = true
    function chk(name, cond, detail = "")
        ok = ok && cond
        println("[$name] ", cond ? "PASS" : "MISMATCH", " ", detail)
    end

    ls = readlines(EX)
    segs = [l for l in ls if startswith(l, "segment,")]
    for l in segs
        f = split(l, ",")
        id = f[2]
        ra = parse(Float64, f[4])
        rb = parse(Float64, f[5])
        lt = parse(Float64, f[6])
        stored = parse(Float64, f[8])
        lim = trpt_twist_limit(ra, rb, lt)
        @printf("%s: r_a=%.16g r_b=%.16g l_t=%.16g\n", id, ra, rb, lt)
        @printf("    dcrit computed=%.17g stored=%.17g exact=%s has_limit=%s\n",
                lim.dcrit_deg, stored, lim.dcrit_deg == stored, lim.has_limit)
        chk("$id exact Float64 match", lim.dcrit_deg == stored && lim.has_limit == true)
    end

    # boundary probes on the winner's ground radius: the phi = 2 corner and
    # the long-tether floor approach.
    r = 0.8036829846088207
    b1 = trpt_twist_limit(r, r, 2r)
    @printf("\nboundary l_t = 2r (phi = 2): dcrit = %.6f deg\n", b1.dcrit_deg)
    chk("phi = 2 boundary reads 180", isapprox(b1.dcrit_deg, 180.0, atol = 1e-9))
    b2 = trpt_twist_limit(r, r, 20r)
    @printf("long tether l_t = 20r: dcrit = %.6f deg\n", b2.dcrit_deg)

    println("\nRESULT: ", ok ? "PASS" : "FAIL")
    exit(ok ? 0 : 1)
end
main()
