#!/usr/bin/env julia
# Stage 1b: FoS instrument reconciliation — static v10 vs dynamic v11 FoS
# Re-runs v10 static evaluator on all 50 anchor genomes, exports paired FoS data.

using KiteTurbineDynamics, Printf, Statistics, LinearAlgebra, DelimitedFiles, SHA

const OUT_FOS = joinpath(@__DIR__, "results", "recampaign", "fos_pairs.csv")
const P_BASE = KiteTurbineDynamics.params_v5_50kw()
const BEAM = KiteTurbineDynamics.PROFILE_ELLIPTICAL

function static_fos_from_genome(x)
    try
        result = KiteTurbineDynamics.design_from_vector_v10(
            x[1:14], BEAM, P_BASE; power_W=50000.0, v_rated=11.0
        )
        if result.n_active == 0
            return (Inf, Inf)
        end
        (; design, rotors, n_rings, zs) = result
        n_lines = design.n_lines

        expansion_params = KiteTurbineDynamics.ExpansionRotorParams[]
        for rotor in rotors
            er = KiteTurbineDynamics.ExpansionRotorParams(
                n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius,
                rotor.blade_chord, KiteTurbineDynamics.EXP_CL_DESIGN,
                KiteTurbineDynamics.EXP_CD0_DESIGN,
                KiteTurbineDynamics.EXP_K_INDUCED,
                rotor.bank_angle_deg,
                KiteTurbineDynamics.expansion_blade_mass(rotor.blade_tip_radius, rotor.blade_scale),
                rotor.ring_idx, 1.0,
            )
            push!(expansion_params, er)
        end

        _, radii, _ = KiteTurbineDynamics.ring_spacing_v4(
            design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
            density_profile=design.density_profile,
        )

        p_scaled = KiteTurbineDynamics.override_params(P_BASE; k_mppt=x[15] > -10 ? 10.0^x[15] : 60.0)

        ω_eq, r_ref = KiteTurbineDynamics.solve_equilibrium_self_consistent(
            design, expansion_params, p_scaled, n_lines, radii, zs;
            P_per_rotor=50000.0 / max(result.n_active, 1),
            v_wind=11.0, elev_rad=π/6,
        )

        if ω_eq === nothing || isnan(ω_eq) || ω_eq <= 0
            return (Inf, Inf)
        end

        eval_result = KiteTurbineDynamics.evaluate_design(
            design;
            r_rotor=r_ref,
            elev_angle=π/6,
            T_elev=11200.0,
            rotors=expansion_params,
            ω_design=ω_eq,
            n_lines=n_lines,
            power_W=50000.0,
            v_rated=11.0,
        )
        return (eval_result.min_fos, eval_result.feasible ? 1.0 : 0.0)
    catch
        return (Inf, Inf)
    end
end

function main()
    # Read anchors
    data = readdlm(
        joinpath(@__DIR__, "results", "recampaign", "anchors.csv"),
        ',', header=true
    )
    headers = data[2]
    rows = data[1]
    hdr = Dict(h => i for (i, h) in enumerate(headers))

    println("=== Stage 1b: FoS Instrument Reconciliation ===\n")
    println("Computing v10 static FoS for $(size(rows,1)) anchor genomes...")

    open(OUT_FOS, "w") do io
        println(io, "genome_hash,static_min_fos,v11_FoS_min,n_lines,chosen_k,static_feasible")
        for i in 1:size(rows, 1)
            gh = rows[i, hdr["genome_hash"]]
            v11_fos = parse(Float64, string(rows[i, hdr["FoS_min"]]))
            n_lines = string(rows[i, hdr["n_lines"]])
            n_lines = try parse(Int, n_lines) catch; 0 end
            k_chosen = parse(Float64, string(rows[i, hdr["chosen_k"]]))
            x = [parse(Float64, string(rows[i, hdr["x$j"]])) for j in 1:15]

            static_fos, static_feasible = static_fos_from_genome(x)
            println(io, "$gh,$static_fos,$v11_fos,$n_lines,$k_chosen,$static_feasible")
            @printf("  [%2d/%d] %s  static=%.3f  v11=%.3f  n_lines=%d\n",
                i, size(rows,1), gh[1:8], static_fos, v11_fos, n_lines)
        end
    end

    # Read back and compute stats
    fos_data = readdlm(OUT_FOS, ',', header=true)
    fos_headers = fos_data[2]; fos_rows = fos_data[1]
    fh = Dict(h => i for (i, h) in enumerate(fos_headers))

    statics = Float64[]; dymos = Float64[]; nls = Int[]
    for i in 1:size(fos_rows, 1)
        s = fos_rows[i, fh["static_min_fos"]]
        d = fos_rows[i, fh["v11_FoS_min"]]
        nl = fos_rows[i, fh["n_lines"]]
        if s < 100 && d < 100  # exclude Inf sentinels
            push!(statics, s); push!(dymos, d); push!(nls, nl)
        end
    end

    n = length(statics)
    println("\nPaired FoS: $n valid pairs")
    if n < 3
        println("  Not enough valid pairs for statistical analysis.")
        println("  Output: $OUT_FOS")
        return
    end

    # Spearman on FoS pairs
    function spearman_rho(xs, ys)
        n = length(xs); n < 3 && return NaN
        rank(arr) = begin
            si = sortperm(arr); r = zeros(n)
            i = 1
            while i <= n
                j = i
                while j <= n && arr[si[j]] == arr[si[i]]; j += 1; end
                avg = (i + j - 1) / 2 + 1
                for k in i:j-1; r[si[k]] = avg; end
                i = j
            end
            return r
        end
        rx = rank(xs); ry = rank(ys)
        mx = sum(rx)/n; my = sum(ry)/n
        num = sum((rx[i]-mx)*(ry[i]-my) for i in 1:n)
        den = sqrt(sum((rx[i]-mx)^2 for i in 1:n) * sum((ry[i]-my)^2 for i in 1:n))
        return den > 0 ? num/den : 0.0
    end

    ρ_fos = spearman_rho(statics, dymos)
    println("Spearman ρ(FoS pairs): $(round(ρ_fos, digits=3))")

    # δ_FoS vs n_lines (simple linear regression)
    deltas = statics .- dymos
    μ_n = mean(nls); μ_δ = mean(deltas)
    num = sum((nls[i] - μ_n) * (deltas[i] - μ_δ) for i in 1:n)
    den = sum((nls[i] - μ_n)^2 for i in 1:n)
    β_n = den > 0 ? num / den : 0.0
    α_n = μ_δ - β_n * μ_n

    println("δ_FoS = static − dynamic: mean=$(round(μ_δ,digits=3))")
    println("  vs n_lines: β=$(round(β_n,digits=3))  (per-line delta)")

    # Summary by n_lines
    println("\nBy n_lines:")
    for nl in sort(unique(nls))
        idx = findall(nls .== nl)
        if length(idx) >= 2
            s = statics[idx]; d = dymos[idx]; δ = s .- d
            ρ = spearman_rho(s, d)
            @printf("  n_lines=%2d  n=%d  δ̅=%.3f  ρ=%.3f  static=[%.2f-%.2f]  v11=[%.2f-%.2f]\n",
                nl, length(idx), mean(δ), ρ, minimum(s), maximum(s), minimum(d), maximum(d))
        end
    end

    println("\nOutput: $OUT_FOS")
end

main()
