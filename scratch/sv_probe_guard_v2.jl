# sv_probe_guard_v2.jl — (A) the value/shape regex against real source,
# (B) whether evaluate_exponent is robust to every `^<numeric>` form the three files carry.
root = dirname(@__DIR__)

function evaluate_exponent(s::AbstractString)::Float64
    if occursin("//", s)
        a, b = split(s, "//")
        return parse(Float64, a) / parse(Float64, b)
    elseif occursin("/", s)
        a, b = split(s, "/")
        return parse(Float64, a) / parse(Float64, b)
    end
    return parse(Float64, s)
end

trip(e) = abs(e - 1 / 7) < 5e-3 || abs(e - 0.14) < 5e-3

println("=== (A) every capture the value-regex takes, per file ===")
for f in ("sim_runner.jl", "visualization.jl", "control_map_hunt.jl")
    flat = replace(read(joinpath(root, "src", f), String), r"\s+" => "")
    caps = [m.captures[1] for m in eachmatch(r"\^\(?([0-9][0-9./]*)", flat)]
    vals = String[]
    for c in caps
        try
            push!(vals, string(c, "=", round(evaluate_exponent(c), digits = 6)))
        catch err
            push!(vals, string(c, "=THROWS:", typeof(err)))
        end
    end
    println(rpad(f, 22), " n=", length(caps), "  ", join(vals, "  "))
end

println()
println("=== (B) synthetic forms a future edit could write ===")
cases = ["(z/p.h_ref)^(1/7.0)", "(z/p.h_ref)^(1//7)", "(z/p.h_ref)^(0.142857)",
    "(z/p.h_ref)^(0.14)", "(z/9.412)^(1/7)", "(z/p.h_ref)^((1/7))",
    "a^2/(b+c)", "a^3/x", "n^0.5", "a^(ALPHA)"]
for s in cases
    flat = replace(s, r"\s+" => "")
    shape = occursin("h_ref)^", flat)
    parts = String[]
    for m in eachmatch(r"\^\(?([0-9][0-9./]*)", flat)
        c = m.captures[1]
        try
            e = evaluate_exponent(c)
            push!(parts, string(c, "=", round(e, digits = 6), trip(e) ? "(TRIPS)" : "(ok)"))
        catch err
            push!(parts, string(c, "=THROWS:", typeof(err)))
        end
    end
    println(rpad(s, 26), " shape=", shape ? "TRIPS" : "ok", "  value={", join(parts, ", "), "}")
end
