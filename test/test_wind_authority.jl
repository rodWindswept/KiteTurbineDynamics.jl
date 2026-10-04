# test/test_wind_authority.jl
#
# Guard: ONE wind authority.  Every runtime shear call reads the exponent from
# the site spec (`site_shear`); none hand-writes it.
#
# Why a source-level pin sits beside the behaviour tests:
# at the anchor site the exponent IS 1/7, so `(z / h_ref)^(1/7)` and
# `v_ref * site_shear(h_ref, z)` agree to the last bit.  A behaviour test
# therefore passes with the literals still live -- and keeps passing after
# `at_site` re-bases a machine on a site whose exponent is not 1/7, which is the
# whole reason the site spec exists.  The literal is harmless on the anchor and
# wrong off it, so only a source assertion fails today for the right reason.
#
# The retired spelling lived in three shipped closures (17 sites):
#   src/sim_runner.jl       6  (batch-rerun wind factories)
#   src/visualization.jl    8  (dashboard wind factories)
#   src/control_map_hunt.jl 3  (settle maps)
# These sat outside the D1 landing, which fixed only the ODE and decoder paths.
#
# Wired into test/runtests.jl (fast unit suite); runs standalone too.

using Test, KiteTurbineDynamics

# Evaluate an exponent written in source, whatever spelling it uses:
# `1/7`, `1.0/7.0`, `1//7` (Julia Rational), `0.142857`, `0.14`, `((1/7))`, `2`.
# Exact-string matching is blind to all but the first two; this is not.  It
# returns NaN for anything it cannot read as a plain numeric exponent, so it
# reports rather than throws: an apparent exponent that is really a division
# (`x^2/(2*g)`, captured as `2/`) must not crash the guard.
function evaluate_exponent(s::AbstractString)::Float64
    t = strip(strip(s, ['(', ')']), ['(', ')'])   # outer parentheses, `^((1/7))`
    t = rstrip(t, ['/', '.'])                     # trailing punctuation, `2/`
    occursin(r"^[0-9][0-9./]*$", t) || return NaN
    if occursin("//", t)
        a, b = split(t, "//")
        return parse(Float64, a) / parse(Float64, b)
    elseif occursin("/", t)
        a, b = split(t, "/")
        return parse(Float64, a) / parse(Float64, b)
    end
    return parse(Float64, t)
end

@testset "one wind authority — the shear exponent comes from the site spec" begin
    D = KiteTurbineDynamics

    # ── 1. The shape is the spec's exponent, on any reference pair ──────────
    for (h_ref, h) in ((9.4117, 5.0), (9.4117, 9.4117), (5.155, 12.0), (20.0, 4.0), (1.0, 60.0))
        @test D.site_shear(h_ref, h) ≈ (h / h_ref)^D.SITE_ANCHOR.shear_exp rtol = 1e-12
        @test D.site_shear(h_ref, h) ≈ (h / h_ref)^(1 / 7) rtol = 1e-12  # anchor is 1/7 today
    end
    @test D.site_shear(9.4117, 9.4117) == 1.0    # at the reference height the factor is 1
    @test D.site_shear(9.4117, 0.0) == 0.0       # non-positive altitude by `wind_at_altitude`
    @test D.site_shear(9.4117, -3.0) == 0.0

    # ── 2. The shape tracks a spec whose exponent is NOT 1/7 ────────────────
    #    Two sites, same heights, different exponents.  A literal cannot do this;
    #    it is exactly what a re-typed `1/7` would get wrong off the anchor.
    site_steep = D.WindSiteSpec("test site (synthetic, steep)", 12.0, 10.0, 0.2)
    @test D.site_wind(site_steep, 20.0) / D.site_wind(site_steep, 10.0) ≈ 2.0^0.2 rtol = 1e-12
    @test 2.0^0.2 > D.site_shear(10.0, 20.0)   # the steeper spec lifts more over 10 m
    @test D.site_shear(10.0, 20.0) ≈ 2.0^D.SITE_ANCHOR.shear_exp rtol = 1e-12

    # ── 3. Source pin: no shipped runtime closure hand-writes the exponent ──
    #    Spelling is the trap.  An exact-string negative (`"^(1/7)"`) is blind
    #    to `^(1/7.0)`, `^(1//7)`, `^(0.142857)` and `^(0.14)` — measured: with
    #    the exact-string form, two live re-typed closures passed 25/25.  So the
    #    negative side is two *generic* clauses: the SHAPE (an exponent applied
    #    to a reference-height ratio — every retired literal had that form) and
    #    the VALUE (any exponent that evaluates to the anchor exponent or the
    #    retired 0.14, however it is written).  The positive clause is counted,
    #    not merely present: a file carrying one `site_shear` call beside twelve
    #    literals would satisfy an `occursin` check.
    root = dirname(@__DIR__)
    expected = Dict(
        "sim_runner.jl" => 6, "visualization.jl" => 8, "control_map_hunt.jl" => 3
    )
    for (f, n) in expected
        flat = replace(read(joinpath(root, "src", f), String), r"\s+" => "")
        # (a) SHAPE — no exponent applied to a reference-height ratio.
        @test !occursin("h_ref)^", flat)
        # (b) VALUE — the token after every `^` is normalised (outer parentheses
        #     stripped, trailing punctuation dropped) and evaluated, so the
        #     spelling carries no weight: `1/7`, `1.0/7.0`, `1//7`, `0.142857`,
        #     `0.14` and `((1/7))` are one value.  Catches a shear written
        #     against a base that is not `h_ref`, which (a) alone would miss.
        for m in eachmatch(r"\^\(*([0-9][0-9./)]*)", flat)
            e = evaluate_exponent(m.captures[1])
            @test !(abs(e - 1 / 7) < 5e-3 || abs(e - 0.14) < 5e-3)
        end
        # (c) POSITIVE — the authority is called the expected number of times.
        @test count("site_shear(", flat) >= n
    end
end
