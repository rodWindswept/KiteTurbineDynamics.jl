# sv_probe_len_winners_decode.jl — software-validator, 2026-10-02
#
# DECIDES: what rotor count does each `v13_5kw_len*` best_vector.csv actually
# decode to — under the legacy bitmask path (what grounded_economics_v13.jl
# used before the fix) AND under `decode_winner` (rotor_count_mode=true, what
# it uses now)?
#
# Context: software-worker reported that len18.0's inputs are 14-D
# rotor_count genomes giving "3", where the old bitmask clamp gave 1.
# Verify or refute — the two eras are distinguishable (rotor_count_mode landed
# 2026-08-25; these dirs are dated 2026-08-15/16).
#
# USAGE: scripts/ktd-julia scratch/sv_probe_len_winners_decode.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))
include(joinpath(ROOT, "scripts", "ode_gate_v13.jl"))

function legacy_bitmask_build(x, L, KW)
    p = params_at_length(params_daisy(), L, KW)
    xv = copy(x)
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
    xv[10] = clamp(xv[10], 0.0, Float64(N_VALID_MASKS))
    dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p; power_W=KW * 1000.0)
    return dec
end

function row(label, csv, L)
    isfile(csv) || (println("MISSING $csv"); return)
    x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    @printf("\n%-42s fields=%2d  x[10]=%.6f\n", label, length(x), x[10])
    for (mode, f) in ("legacy bitmask+no knobs" => (() -> legacy_bitmask_build(x, L, 5.0)),
                      "decode_winner (campaign)" => (() -> decode_winner(x; L=L, KW=5.0).dec))
        dec = f()
        rings = [r.ring_idx for r in dec.rotors]
        banks = [round(r.bank_angle_deg, digits=3) for r in dec.rotors]
        @printf("   %-24s n_active=%d  n_rings=%2d  rings=%s  banks=%s\n",
            mode, dec.n_active, dec.n_rings, string(rings), string(banks))
    end
end

println("=== v13_5kw_len* winners (the dirs grounded_economics_v13.jl reads) ===")
for (d, L) in [("v13_5kw_len18.0", 18.0), ("v13_5kw_len21.2", 21.2), ("v13_5kw_len25.0", 25.0)]
    row("$d/best_vector.csv", joinpath(ROOT, "scripts", "results", d, "best_vector.csv"), L)
    row("$d/island_1_best.csv", joinpath(ROOT, "scripts", "results", d, "island_1_best.csv"), L)
    row("$d/island_2_best.csv", joinpath(ROOT, "scripts", "results", d, "island_2_best.csv"), L)
    row("$d/island_3_best.csv", joinpath(ROOT, "scripts", "results", d, "island_3_best.csv"), L)
end

println("\n=== the bank-derate winner (guard-test subject) ===")
row("bankderate/best_vector.csv",
    joinpath(ROOT, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv"),
    18.8)

println("\n=== VALID_ROTOR_MASKS (actual) ===")
println("  N_VALID_MASKS = ", N_VALID_MASKS)
println("  masks[1:8] = ", VALID_ROTOR_MASKS[1:min(8, end)])
for v in (0.0109, 1.26727299084247, 4.257904254778126, 8.98382000003422, 17.069835727881824)
    m, n, pos = decode_rotor_mask(v)
    @printf("  decode_rotor_mask(%8.4f) -> idx=%2d mask=%3d n_active=%d positions=%s\n",
        v, round(Int, v), m, n, string(pos))
end
