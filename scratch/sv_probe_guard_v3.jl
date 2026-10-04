# sv_probe_guard_v3.jl — v3's evaluate_exponent against real captures and synthetic forms.
root = dirname(@__DIR__)

# v3 form, copied verbatim from test/test_wind_authority.jl @ 0de1c33
function evaluate_exponent(s::AbstractString)::Float64
    t = strip(strip(s, ['(', ')']), ['(', ')'])
    t = rstrip(t, ['/', '.'])
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

trip(e) = !(abs(e - 1 / 7) < 5e-3 || abs(e - 0.14) < 5e-3)
verdict(e) = isnan(e) ? "NaN(silent)" : string(round(e, digits = 6), trip(e) ? " TRIPS" : " ok")
captures(flat) = [m.captures[1] for m in eachmatch(r"\^\(*([0-9][0-9./)]*)", flat)]

println("=== (A) real source: captures and verdicts under the v3 regex ===")
files = ("sim_runner.jl", "visualization.jl", "control_map_hunt.jl")
tab = [(f, captures(replace(read(joinpath(root, "src", f), String), r"\s+" => ""))) for f in files]
for (f, caps) in tab
    println(rpad(f, 22), " n=", length(caps), "  ",
        join([string(c, "=", verdict(evaluate_exponent(c))) for c in caps], "  "))
end
tot = sum(length(c) for (_, c) in tab)
println("total value-checks = ", tot, "  => file total = 16 + ", tot, " = ", 16 + tot)

println()
println("=== (B) synthetic forms: shape / value verdicts ===")
cases = ["(z/p.h_ref)^(1/7.0)", "(z/p.h_ref)^(1//7)", "(z/p.h_ref)^(0.142857)",
    "(z/p.h_ref)^(0.14)", "(z/9.412)^(1/7)", "(z/9.412)^((1/7))",
    "(z/p.h_ref)^((1/7))", "z^2/(2*9.81)", "x^3/x", "n^0.5", "a^(ALPHA)",
    "(z/9.412)^(7/49)", "(z/9.412)^(2/14)", "(z/9.412)^(0.14286)",
    "(z/9.412)^(1)/(7)", "(z/9.412)^-1"]
for s in cases
    flat = replace(s, r"\s+" => "")
    shape = occursin("h_ref)^", flat)
    parts = [string(c, " -> ", verdict(evaluate_exponent(c))) for c in captures(flat)]
    println(rpad(s, 28), " shape=", shape ? "TRIPS" : "ok   ", "  value={", join(parts, ", "), "}")
end
