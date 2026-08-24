using Test

# Static guard for the campaign-k single source of truth (2026-08-24).
# Fault class: the 5 kW campaign operating point k drifted between the
# runner/evaluator and the gate twice — k=10.0 (trust-log 2026-08-13 row,
# ObjectiveConfig default overload) and k=5.39 (trust-log 2026-08-24 row,
# stale hardcode in ode_gate_v13.jl after the honest-window re-sweep).
# Rule: K_MPPT_5KW_HONEST in compute_seeds.jl is the ONLY k for the 5 kW
# rung.  Any numeric k literal in a consumer script fails the suite.
@testset "campaign k single-source" begin
    scripts = joinpath(@__DIR__, "..", "scripts")

    seeds_src = read(joinpath(scripts, "compute_seeds.jl"), String)
    m = match(r"const\s+K_MPPT_5KW_HONEST\s*=\s*([0-9.]+)", seeds_src)
    @test m !== nothing
    k_honest = m === nothing ? NaN : parse(Float64, m.captures[1])

    consumers = [
        "run_v13_5kw_masslift.jl",
        "smoke_masslift_v13.jl",
        "ode_gate_v13.jl",
        "analyze_campaign_winners.jl",
    ]
    # The k-sweep script is the PRODUCER of the constant's value (it defines
    # the sweep list), so it is deliberately not scanned.

    for f in consumers
        src = read(joinpath(scripts, f), String)
        # (a) every consumer must reference the constant
        @test occursin("K_MPPT_5KW_HONEST", src)
        # (b) no numeric k_mppt kwarg literal may appear
        literal = match(r"k_mppt\s*=\s*[0-9]+\.?[0-9]*", src)
        @test literal === nothing
        # (c) the gate's conditional must not embed a numeric literal
        stale = match(r"k_mp\s*=\s*KW\s*==\s*5\.0\s*\?\s*[0-9]+\.?[0-9]*", src)
        @test stale === nothing
    end

    # Sanity: the constant itself is the honest-window value.
    @test k_honest == 2.24
end
