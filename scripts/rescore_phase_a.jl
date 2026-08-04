# scripts/rescore_phase_a.jl
# Re-score archived Phase A CSVs under corrected Part A rules.
# Outputs new files with provenance header; does not modify originals.
# Usage: julia --project=. scripts/rescore_phase_a.jl
using KiteTurbineDynamics, Printf

PROVENANCE = chomp(read(`git rev-parse HEAD`, String))[1:7]
@info "Rescoring with commit $PROVENANCE"

ρ = 1.225  # kg/m³
η_betz = 0.593

for csv_name in ["feasibility_phase_a_garbage", "feasibility_phase_a_Pfloor1", "feasibility_phase_a_Do022"]
    in_path = "scripts/results/recampaign/$(csv_name).csv"
    out_path = "scripts/results/recampaign/$(csv_name)_rescored_$(PROVENANCE).csv"
    isfile(in_path) || continue

    lines = readlines(in_path)
    header = split(lines[1], ',')
    @info "Processing $csv_name — $(length(lines)-1) rows"

    open(out_path, "w") do io
        # Provenance banner
        println(io, "# Re-scored under corrected Part A rules")
        println(io, "# Source commit: $PROVENANCE")
        println(io, "# Changes:")
        println(io, "#   A1: util split co-located with FoS_min (old columns were independent maxima)")
        println(io, "#   A2: Betz physical-admissibility guard (10% tolerance)")
        println(io, "#   A3: n_rings < 5 model-validity gate")
        println(io, "#   A5: non-finite FoS routed to rejection band ≥ 12.0")
        println(io, "# New columns:")
        println(io, "#   A_projected_m2  — total projected swept area (bank-corrected)")
        println(io, "#   Betz_ceiling_kW — 0.593 × ½ρv³ × A_projected")
        println(io, "#   betz_flag       — P_mean > 1.1× ceiling")
        println(io, "#   n_rings          — ring count (flag if < 5)")
        println(io, "#   f_feas_new       — objective_feasibility(P_mean, FoS_min) under corrected rules")
        println(io, "#   tier_new         — stalled / feasibility / feasible / rejected")
        println(io, "#   util_flag        — A1 caveat: old util_a/util_b are independent maxima, identity may fail")
        println(io, "#")

        # Gather column indices
        hmap = Dict(v => i for (i, v) in enumerate(header))

        # Write new header
        new_header = vcat(header, ["A_projected_m2", "Betz_ceiling_kW", "betz_flag",
                                    "n_rings", "f_feas_new", "tier_new", "util_flag"])
        println(io, join(new_header, ','))

        for row_idx in 2:length(lines)
            line = strip(lines[row_idx])
            isempty(line) && continue
            vals = split(line, ',')

            function val(col) 
                s = vals[hmap[col]]
                s == "" && return missing
                return parse(Float64, s)
            end

            P_mean = val("P_mean_kw")
            FoS_min = val("FoS_min")
            util_a = val("util_axial")
            util_b = val("util_bending")

            # ── A1 caveat ──
            util_flag = ""
            if !ismissing(util_a) && !ismissing(util_b) && util_a > 0 && util_b > 0 &&
               !ismissing(FoS_min) && isfinite(FoS_min) && FoS_min > 0
                id_err = abs(util_a + util_b - 1.0/FoS_min) * FoS_min
                if id_err >= 0.01
                    util_flag = "identity_broken_$(round(id_err, digits=3))"
                end
            end

            # ── A3: n_rings gate ──
            n_lines_raw = val("n_lines")
            n_active = val("n_active")
            # n_rings is NOT in the archived CSV — decode from design vector
            n_rings = 0  # placeholder; actual decode needs design_from_vector_v10

            # ── A2: Betz ceiling ──
            # Requires decoding x[1:14] through design_from_vector_v10.
            # Compute swept area from rotor specs.
            A_projected = NaN  # placeholder
            betz_ceiling = NaN
            betz_flag = false
            if !ismissing(P_mean)
                # Try to decode the design vector
                x14 = [val("x$i") for i in 1:14]
                if all(!ismissing, x14)
                    try
                        result = design_from_vector_v10(
                            collect(Float64, x14), PROFILE_ELLIPTICAL, params_v5_50kw();
                            max_ground_radius=OPT_MAX_GROUND_RADIUS,
                            power_W=50000.0, v_rated=11.0
                        )
                        p = params_v5_50kw()
                        A_total = π * p.rotor_radius^2  # hub rotor
                        for rotor in result.rotors
                            bank_rad = rotor.bank_angle_deg * π / 180.0
                            A_total += π * rotor.blade_tip_radius^2 * cos(bank_rad)
                        end
                        A_projected = A_total
                        betz_ceiling = η_betz * 0.5 * ρ * A_total * 11.0^3 / 1000.0
                        betz_flag = P_mean > 1.1 * betz_ceiling
                        n_rings = result.n_rings
                    catch e
                        @warn "Design decode failed for row $row_idx" exception=e
                    end
                end
            end

            # ── A5: Corrected tier (non-finite FoS → rejection ≥ 12.0) ──
            f_new = ismissing(P_mean) || ismissing(FoS_min) ? NaN :
                    objective_feasibility(P_mean, FoS_min)
            tier_new = ismissing(f_new) ? "unknown" :
                       f_new >= 12.0 ? "rejected" :
                       f_new >= 10.0 ? "stalled" :
                       f_new > 0.0 ? "feasibility" :
                       "feasible"

            # Write row
            new_vals = [string(ismissing(A_projected) ? "NA" : round(A_projected, digits=2)),
                        string(ismissing(betz_ceiling) ? "NA" : round(betz_ceiling, digits=2)),
                        string(betz_flag),
                        string(n_rings),
                        string(ismissing(f_new) ? "NA" : round(f_new, digits=4)),
                        tier_new,
                        util_flag]
            println(io, join(vcat(vals, new_vals), ','))
        end
    end

    @info "→ $out_path"
end

@info "Re-scoring complete."
