# src/aerodynamics.jl
# Rotor aerodynamic coefficient tables from AeroDyn BEM simulations.
# Source: AeroDyn v5.0.0 quasi-steady BEM sweep (2026-06-10), 0° elevation.
# Original MVP input files: ad_primary_MVP.inp, ad_blade_MVP.inp, ad_airfoil_Rigid.inp
#   — NACA4412, 3 blades, R=4.0 m, HubRad=1.0 m, chord=0.5 m, Re=250k.
# Old tables (v5, 20° elev, Beddoes-Leishman) were replaced — these are pure
# aerodynamic coefficients at 0° shaft elevation with no loss calibration baked in.
# Bridle/TRPT/tether losses are modelled explicitly elsewhere.
#
# cp_at_tsr(λ) — power coefficient Cp as a function of tip speed ratio λ = ω·R/v
# ct_at_tsr(λ) — thrust coefficient CT as a function of tip speed ratio λ
#
# λ=0 anchor: Cp=CT=0 (linear extrapolation from standstill).
# Table range: λ = 0.0 to 8.0 in steps of 0.1 (72 points, linearly interpolated
# from 8 AeroDyn cases at TSR 1–8).
# Beyond table: Cp extrapolated (may be negative — freewheeling); CT extrapolated.

const BEM_TSR = [
    0.0, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9,
    2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9,
    3.0, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9,
    4.0, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9,
    5.0, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9,
    6.0, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9,
    7.0, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 8.0
]

# Cp(λ) from AeroDyn v5.0.0 quasi-steady BEM at 0° elevation.
# Peak Cp ≈ 0.309 at λ ≈ 5.2. Broad plateau from λ≈3.5–5.5. Cp stays positive
# through λ=8.0 (no freewheeling cross-over at rated wind — purely aerodynamic table).
const BEM_CP = [
    0.0,       # λ=0.0  (anchor — linear extrapolation to standstill)
    0.012948,  # λ=1.0
    0.020703,  # λ=1.1
    0.028457,  # λ=1.2
    0.036211,  # λ=1.3
    0.043965,  # λ=1.4
    0.051719,  # λ=1.5
    0.059474,  # λ=1.6
    0.067228,  # λ=1.7
    0.074982,  # λ=1.8
    0.082736,  # λ=1.9
    0.090491,  # λ=2.0
    0.098342,  # λ=2.1
    0.110160,  # λ=2.2
    0.121978,  # λ=2.3
    0.133796,  # λ=2.4
    0.145614,  # λ=2.5
    0.157432,  # λ=2.6
    0.169250,  # λ=2.7
    0.181067,  # λ=2.8
    0.192885,  # λ=2.9
    0.204703,  # λ=3.0
    0.216521,  # λ=3.1
    0.225895,  # λ=3.2
    0.233633,  # λ=3.3
    0.241371,  # λ=3.4
    0.249108,  # λ=3.5
    0.256846,  # λ=3.6
    0.264584,  # λ=3.7
    0.272322,  # λ=3.8
    0.280060,  # λ=3.9
    0.287798,  # λ=4.0  ← near-peak
    0.295535,  # λ=4.1
    0.303001,  # λ=4.2
    0.303570,  # λ=4.3
    0.304140,  # λ=4.4
    0.304710,  # λ=4.5
    0.305279,  # λ=4.6
    0.305849,  # λ=4.7
    0.306418,  # λ=4.8
    0.306988,  # λ=4.9
    0.307557,  # λ=5.0
    0.308127,  # λ=5.1
    0.308697,  # λ=5.2  ← peak Cp ≈ 0.309
    0.306513,  # λ=5.3
    0.301947,  # λ=5.4
    0.297381,  # λ=5.5
    0.292815,  # λ=5.6
    0.288249,  # λ=5.7
    0.283683,  # λ=5.8
    0.279116,  # λ=5.9
    0.274550,  # λ=6.0
    0.269984,  # λ=6.1
    0.265418,  # λ=6.2
    0.260489,  # λ=6.3
    0.254080,  # λ=6.4
    0.247671,  # λ=6.5
    0.241262,  # λ=6.6
    0.234854,  # λ=6.7
    0.228445,  # λ=6.8
    0.222036,  # λ=6.9
    0.215627,  # λ=7.0
    0.209219,  # λ=7.1
    0.202810,  # λ=7.2
    0.196401,  # λ=7.3
    0.188836,  # λ=7.4
    0.180295,  # λ=7.5
    0.171753,  # λ=7.6
    0.163211,  # λ=7.7
    0.154670,  # λ=7.8
    0.146128,  # λ=7.9
    0.137586,  # λ=8.0
]

# CT(λ) from AeroDyn v5.0.0 quasi-steady BEM at 0° elevation.
# CT rises from 0 at standstill, peaks/plateaus above λ≈5 at Ct≈0.82.
# Above λ=8, extrapolation is used — the BEM model remains quasi-steady.
const BEM_CT = [
    0.0,       # λ=0.0  (anchor)
    0.134542,  # λ=1.0
    0.145321,  # λ=1.1
    0.156100,  # λ=1.2
    0.166878,  # λ=1.3
    0.177657,  # λ=1.4
    0.188435,  # λ=1.5
    0.199214,  # λ=1.6
    0.209993,  # λ=1.7
    0.220771,  # λ=1.8
    0.231550,  # λ=1.9
    0.242328,  # λ=2.0
    0.253336,  # λ=2.1
    0.273675,  # λ=2.2
    0.294013,  # λ=2.3
    0.314352,  # λ=2.4
    0.334690,  # λ=2.5
    0.355028,  # λ=2.6
    0.375367,  # λ=2.7
    0.395705,  # λ=2.8
    0.416044,  # λ=2.9
    0.436382,  # λ=3.0
    0.456721,  # λ=3.1
    0.476623,  # λ=3.2
    0.496234,  # λ=3.3
    0.515844,  # λ=3.4
    0.535455,  # λ=3.5
    0.555065,  # λ=3.6
    0.574676,  # λ=3.7
    0.594287,  # λ=3.8
    0.613897,  # λ=3.9
    0.633508,  # λ=4.0
    0.653118,  # λ=4.1
    0.672499,  # λ=4.2
    0.686072,  # λ=4.3
    0.699645,  # λ=4.4
    0.713218,  # λ=4.5
    0.726791,  # λ=4.6
    0.740364,  # λ=4.7
    0.753937,  # λ=4.8
    0.767510,  # λ=4.9
    0.781083,  # λ=5.0
    0.794656,  # λ=5.1
    0.808229,  # λ=5.2
    0.819225,  # λ=5.3
    0.827989,  # λ=5.4
    0.836752,  # λ=5.5
    0.845516,  # λ=5.6
    0.854280,  # λ=5.7
    0.863044,  # λ=5.8
    0.871808,  # λ=5.9
    0.880572,  # λ=6.0
    0.889335,  # λ=6.1
    0.898099,  # λ=6.2
    0.906446,  # λ=6.3
    0.913095,  # λ=6.4
    0.919744,  # λ=6.5
    0.926392,  # λ=6.6
    0.933041,  # λ=6.7
    0.939689,  # λ=6.8
    0.946338,  # λ=6.9
    0.952987,  # λ=7.0
    0.959635,  # λ=7.1
    0.966284,  # λ=7.2
    0.972932,  # λ=7.3
    0.978710,  # λ=7.4
    0.983752,  # λ=7.5
    0.988793,  # λ=7.6
    0.993835,  # λ=7.7
    0.998877,  # λ=7.8
    1.003918,  # λ=7.9
    1.008960,  # λ=8.0
]

"""
    cp_at_tsr(lambda) -> Float64

Return the rotor power coefficient Cp at tip speed ratio `lambda = ω·R/v_hub`.

Interpolated from the AeroDyn v5.0.0 quasi-steady BEM table at 0° elevation
(NACA4412, 3 blades, R=4.0 m).
- Below λ=0: returns 0.0.
- Within table (0 ≤ λ ≤ 8): linear interpolation.
- Above λ=8: linear extrapolation using the last two table entries.
"""
function cp_at_tsr(lambda::Float64)::Float64
    lambda <= 0.0 && return 0.0
    return _interp_bem(BEM_TSR, BEM_CP, lambda)
end

"""
    ct_at_tsr(lambda) -> Float64

Return the rotor thrust coefficient CT at tip speed ratio `lambda = ω·R/v_hub`.

Interpolated from the AeroDyn v5.0.0 quasi-steady BEM table at 0° elevation
(NACA4412, 3 blades, R=4.0 m).
- Below λ=0: returns 0.0.
- Within table (0 ≤ λ ≤ 8): linear interpolation.
- Above λ=8: clamped to CT(8) ≈ 1.01.
"""
function ct_at_tsr(lambda::Float64)::Float64
    lambda <= 0.0 && return 0.0
    lambda >= BEM_TSR[end] && return BEM_CT[end]
    return _interp_bem(BEM_TSR, BEM_CT, lambda)
end

# Internal: linear interpolation over a sorted TSR table.
function _interp_bem(tsr_table::Vector{Float64}, coeff_table::Vector{Float64},
                     lambda::Float64)::Float64
    i = searchsortedfirst(tsr_table, lambda)
    i > length(tsr_table) && return coeff_table[end]
    i == 1 && return coeff_table[1]
    t = (lambda - tsr_table[i-1]) / (tsr_table[i] - tsr_table[i-1])
    return coeff_table[i-1] + t * (coeff_table[i] - coeff_table[i-1])
end

# ══════════════════════════════════════════════════════════════════════════════
# Tether aerodynamic drag
# ══════════════════════════════════════════════════════════════════════════════

"""
    TETHER_DRAG_CD

Drag coefficient for a cylindrical Dyneema tether in crossflow.
Cd ≈ 1.0 is the standard value for a smooth circular cylinder
at the Reynolds numbers typical of TRPT tethers (Re ~ 10³–10⁴).
"""
const TETHER_DRAG_CD = 1.0

"""
    TUBE_DRAG_CD

Drag coefficient for a cylindrical CFRP structural tube (ring strut) in crossflow.
Cd ≈ 1.2 is standard for cylinders at typical Reynolds numbers.
"""
const TUBE_DRAG_CD = 1.2


"""
    tether_drag_force(rho, cd, diameter, length_0, v_wind, v_node, dir) -> Vector{Float64}

Compute aerodynamic drag force on a tether sub-segment, applied at the
node (end_b).  Drag acts perpendicular to the segment direction; the
component parallel to the segment is assumed negligible.

# Arguments
- `rho`: air density (kg/m³)
- `cd`: drag coefficient (use TETHER_DRAG_CD for Dyneema)
- `diameter`: tether diameter (m)
- `length_0`: unstretched segment length (m)
- `v_wind`: 3D wind velocity vector at segment midpoint (m/s)
- `v_node`: 3D velocity of the rope node (m/s)
- `dir`: unit vector along the segment direction

# Returns
- `drag::Vector{Float64}`: 3D drag force vector (N)
"""
function tether_drag_force(rho::Float64, cd::Float64, diameter::Float64,
                           length_0::Float64, v_wind::AbstractVector,
                           v_node::AbstractVector, dir::AbstractVector)
    v_rel = v_wind .- v_node
    v_perp = v_rel .- dot(v_rel, dir) .* dir
    v_perp_mag = norm(v_perp)
    if v_perp_mag <= 0.01
        return zeros(3)
    end
    # Drag = ½·ρ·Cd·d·L₀·|v⊥|·v⊥  (perpendicular component only)
    return 0.5 * rho * cd * diameter * length_0 * v_perp_mag .* v_perp
end
