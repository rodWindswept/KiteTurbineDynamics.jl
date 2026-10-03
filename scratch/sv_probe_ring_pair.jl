# sv_probe_ring_pair.jl — software-validator, 2026-10-02
#
# ANSWERS (Rod, 2026-10-02): on a 2-rotor machine over 10 rings, why do the
# rotors land on rings 10 and 7 instead of the expected 9 and 10?
#
# Measures three things, all from the shipped builders:
#   1. the mask table itself — _generate_valid_rotor_masks(10, 2) — and its
#      minimum-separation rule (does an adjacent pair like 9+10 even exist?)
#   2. what the COUNT-mode path (rotor_count_mode=true) builds for n_rotors = 2
#   3. what the BITMASK path (rotor_count_mode=false, the decoder default)
#      builds for the same genome, and which mask it picks
#
# USAGE: scripts/ktd-julia scratch/sv_probe_ring_pair.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const p = params_at_length(18.8)
const N_RINGS_REF = 10

ring_of_bit(b) = N_RINGS_REF - b + 1   # objective_v10.jl:288 — ring_idx = n_rings - p + 1

# ── 1. the mask table ────────────────────────────────────────────────────────
println("=== 1. the mask table: `_generate_valid_rotor_masks(10, 2)` (objective_v10.jl:37-63) ===")
M = KTD.VALID_ROTOR_MASKS
@printf("N_VALID_MASKS = %d   (min_gap = 2 -> active bit positions must be >= 3 apart)\n", length(M))
@printf("KTD.VALID_ROTOR_MASKS[1:5] (bit patterns, LSB = topmost ring) = %s\n",
    string([Int(m) for m in M[1:5]]))

twos = [m for m in M if count_ones(m) == 2]
@printf("2-rotor masks in the table: %d\n", length(twos))
for m in twos
    bits = [i + 1 for i in 0:9 if (m >> i) & 1 == 1]
    @printf("   mask %5d = 0b%s   table-positions %s   (relative rings from top) %s   separation %d\n",
        Int(m), string(m, base = 2, pad = 10), string(bits),
        string([b - 1 for b in bits]), bits[2] - bits[1])
end
@printf("mask 3 (0b…0011, the adjacent top pair) present in the table?  %s\n",
    string(UInt16(3) in M))
@printf("any 2-rotor mask with ADJACENT positions?                        %s\n",
    string(any(m -> (m & (m >> 1)) != 0, twos)))
@printf("smallest 2nd-rotor offset in any 2-rotor mask (bits) = %d\n", minimum(bits2[2] - bits2[1]
    for bits2 in ([i + 1 for i in 0:9 if (m >> i) & 1 == 1] for m in twos)))

println()
println("=== 2. the count path (rotor_count_mode = true — campaign + gate) ===")
println("   decode: n_rotors = clamp(round(Int, x[6]), 1, 3);  positions_raw = collect(1:n_rotors)")
println("   then positions = [n_rings - p + 1 for p in positions_raw]   (objective_v10.jl:286-292)")
for n in 1:3
    pr = collect(1:n)
    @printf("   n_rotors = %d -> count-positions %s -> rings (n_rings = 10) %s\n",
        n, string(pr), string([ring_of_bit(b) for b in pr]))
end

println()
println("=== 3. the bitmask path (rotor_count_mode = false — the decoder default) ===")
for xproxy in (1.267, 2.0)
    mask, npos, pos = decode_rotor_mask(xproxy)
    @printf("   x[6] = %.3f -> round = %d -> VALID_ROTOR_MASKS[%d] = mask %d -> positions %s -> rings %s\n",
        xproxy, round(Int, xproxy), round(Int, xproxy) + 1, Int(mask),
        string(pos), string([ring_of_bit(b) for b in pos]))
end

# ── 4. build the two candidate 2-rotor machines from ONE genome ──────────────
const BANK = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv")

function canonical(path)
    x = [parse(Float64, s) for s in split(strip(read(path, String)), ",")]
    xr = copy(x)
    if length(xr) >= 14
        xr[8]  = Float64(round(Int, clamp(xr[8],  3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1,  3)))
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
        xr[6] = Float64(round(Int, clamp(xr[6], 1,  3)))
    end
    return xr
end

xr = canonical(BANK)
xr[6] = 2.0                     # ask for TWO rotors on both paths

for rcm in (true, false)
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=rcm, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    @printf("\n=== 4. winner genome with x[6] forced to 2.0, rotor_count_mode = %s ===\n", string(rcm))
    @printf("   n_rings = %d   n_active = %d   length(dec.rotors) = %d   mask = %d   spacing_ok = %s\n",
        dec.n_rings, dec.n_active, length(dec.rotors), Int(dec.mask), string(dec.spacing_ok))
    for (i, r) in enumerate(dec.rotors)
        @printf("      rotors[%d]: ring_idx = %d   bank = %.4f deg   wind_factor = %.4f\n",
            i, r.ring_idx, r.bank_angle_deg, r.wind_factor)
    end
    sys, _u0, _pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p)
    n_exp = try length(sys.expansion_rotors) catch; -1 end
    @printf("   BUILT: main rotor = 1 (ring_forces disc model, node_id %s, bank %.4f)  |  expansion rotors = %d\n",
        string(sys.rotor.node_id), sys.rotor.bank_angle_deg, n_exp)
end
