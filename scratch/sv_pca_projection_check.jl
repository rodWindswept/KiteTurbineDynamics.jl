#!/usr/bin/env julia
# scratch/sv_pca_projection_check.jl — science-validator, 2026-10-13.
#
# Independent reproduction of the PCA projection summary (the levers
# family, rows 20-21; the NR-044 row). One static run: reads the three
# committed island telemetry files, z-scores the 930 x 10 matrix of
# x1..x10, runs one SVD (Julia LinearAlgebra — a different instrument
# than the kit's numpy path), and gates the shares, the pair total and
# the loadings against the kit values. No simulator, no ODE.

using LinearAlgebra
using Printf

const RD = joinpath(pwd(), "scripts", "results",
                    "v13_5kw_masslift_len18.8_rotorcount_bankderate2")
const KIT = joinpath(pwd(), "docs", "reporting", "figures")

function main()
    ok = true
    function chk(name, cond, detail = "")
        ok = ok && cond
        println("[$name] ", cond ? "PASS" : "MISMATCH", " ", detail)
    end

    rows = Vector{Vector{Float64}}()
    statuses = Dict{String,Int}()
    per_isl = Dict{Int,Int}()
    for isl in 1:3
        ls = readlines(joinpath(RD, "island_$(isl)", "telemetry.csv"))
        idx = nothing
        for ln in ls
            s = strip(ln)
            (isempty(s) || startswith(s, "#")) && continue
            if idx === nothing
                header = split(s, ",")
                idx = Dict(c => i for (i, c) in enumerate(header))
                continue
            end
            f = split(s, ",")
            st = f[idx["status"]]
            statuses[st] = get(statuses, st, 0) + 1
            per_isl[isl] = get(per_isl, isl, 0) + 1
            push!(rows, [parse(Float64, f[idx["x$(i)"]]) for i in 1:10])
        end
    end
    n = length(rows)
    @printf("rows: %d  per island: %d/%d/%d\n", n, per_isl[1], per_isl[2], per_isl[3])
    println("statuses: ", join(["$k=$v" for (k, v) in sort(collect(statuses))], " "))

    M = permutedims(reduce(hcat, rows))          # n x 10
    mu = sum(M, dims = 1) ./ n
    sd = [sqrt(sum(abs2, M[:, j] .- mu[j]) / (n - 1)) for j in 1:10]   # ddof = 1
    Z = (M .- mu) ./ permutedims(sd)
    F = svd(Z)
    s2 = F.S .^ 2
    tot = sum(s2)
    shares = 100 .* s2 ./ tot
    @printf("PC1 share  = %.10f -> %.6f\n", shares[1], round(shares[1], digits = 6))
    @printf("PC2 share  = %.10f -> %.6f\n", shares[2], round(shares[2], digits = 6))
    @printf("pair total = %.10f -> %.6f (direct)\n", shares[1] + shares[2],
            round(shares[1] + shares[2], digits = 6))
    @printf("pair total from rounded shares = %.6f\n",
            round(shares[1], digits = 6) + round(shares[2], digits = 6))

    chk("rows 930", n == 930)
    chk("per island 310", per_isl[1] == 310 && per_isl[2] == 310 && per_isl[3] == 310)
    chk("status mix",
        statuses == Dict("ok" => 508, "reject" => 301,
                         "clearance_reject" => 110, "reject_twist" => 11),
        string(sort(collect(statuses))))
    chk("PC1 six dp", round(shares[1], digits = 6) == 22.434667, @sprintf("%.10f", shares[1]))
    chk("PC2 six dp", round(shares[2], digits = 6) == 17.263044, @sprintf("%.10f", shares[2]))
    chk("pair total six dp", round(shares[1] + shares[2], digits = 6) == 39.697710,
        @sprintf("%.10f", shares[1] + shares[2]))
    chk("2 dp vs checks.log",
        round(shares[1], digits = 2) == 22.43 && round(shares[2], digits = 2) == 17.26)

    GENE = ["r_hub", "r_bottom", "target_Lr", "n_lines", "density_profile",
            "rotor_count", "bank_top", "bank_bottom", "blade_scale_top",
            "blade_scale_bottom"]
    V = F.V
    for k in 1:2
        println("\nPC$(k) loadings (by |v|):")
        for j in sort(1:10, by = j -> -abs(V[j, k]))
            @printf("  %-20s %+.4f  (%+.8f)\n", GENE[j], V[j, k], V[j, k])
        end
    end
    load1 = Dict(GENE[j] => V[j, 1] for j in 1:10)
    load2 = Dict(GENE[j] => V[j, 2] for j in 1:10)
    for (name, val) in [("n_lines", -0.5385), ("rotor_count", -0.5222),
                        ("blade_scale_top", 0.5180), ("target_Lr", 0.2517),
                        ("r_bottom", 0.2036)]
        chk("PC1 $name four dp", round(load1[name], digits = 4) == val,
            @sprintf("%+.6f", load1[name]))
    end
    for (name, val) in [("bank_bottom", 0.5621), ("blade_scale_bottom", -0.5605),
                        ("density_profile", -0.5018), ("bank_top", -0.2444)]
        chk("PC2 $name four dp", round(load2[name], digits = 4) == val,
            @sprintf("%+.6f", load2[name]))
    end
    big1 = sort([g for g in GENE if abs(load1[g]) >= 0.2])
    big2 = sort([g for g in GENE if abs(load2[g]) >= 0.2])
    println("\n|v| >= 0.2  PC1: ", big1)
    println("|v| >= 0.2  PC2: ", big2)

    # drawn-form gate: the landscape ledger carries the share strings
    led = readlines(joinpath(KIT, "pca-landscape", "label-ledger.txt"))
    for fn in ["22.4", "17.3"]
        hits = [l for l in led if occursin(fn, l)]
        println("landscape ledger carries \"$fn\": ", isempty(hits) ? "no" : "yes -> " * join(hits, " | "))
    end
    chk("landscape ledger carries 22.4 and 17.3",
        any(occursin("22.4", l) for l in led) && any(occursin("17.3", l) for l in led))
    led2 = readlines(joinpath(KIT, "pca-atlas", "label-ledger.txt"))
    for fn in ["22.4", "17.3"]
        hits = [l for l in led2 if occursin(fn, l)]
        println("atlas ledger carries \"$fn\": ", isempty(hits) ? "no" : "yes -> " * join(hits, " | "))
    end

    println("\nRESULT: ", ok ? "PASS" : "FAIL")
    exit(ok ? 0 : 1)
end
main()
