# scratch/av_probe_bank0_blade.jl — aero-validator, 2026-10-02
#
# DECIDES: for the bank-free neighbour the search never tried (bank = 0 with the
# blade shrunk to hold the floor), what blade scale lands on 5.0 kW, and what
# does it buy in MASS?  Decode-level only — the twin levers are geometric:
#
#   sweep area  main_rotor_swept_area = π·(outer² − hub²),  outer = r_ring + 0.7·span,
#               hub = r_ring − 0.3·span  (ring_forces.jl:29, 70/30 ring-anchored split)
#               ⇒ A(s) = π·s·(2·r_ring + 0.4·s)
#   blade mass  span³ law, m = 0.420·span³ per blade, n_blades = n_lines = 3
#               (PROVENANCE: 420 g anchor; pc.m_blade = 0.420·span³)
#   bank        power factor cosd(bank)^2.65  (ring_forces.jl:223)
#
# The control reproduces the campaign's own measured 5.1145 kW at bank 10.739909°,
# λ 0.699446, so the OTHER rows are predictions scaled from a measured anchor —
# they are falsifiable against a settle run, and that is the point.
#
# USAGE: scripts/ktd-julia scratch/av_probe_bank0_blade.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const LENGTH = 18.8
const CSV = joinpath(
    ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv"
)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev
    )
    back = BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout
    )
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const p = params_at_length(LENGTH)
const BASE = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
BASE[4] = Float64(round(Int, clamp(BASE[4], 3, 16)))
BASE[6] = Float64(round(Int, clamp(BASE[6], 1, 3)))

# 10-field CANONICAL layout: x[7] = bank_top, x[9] = blade_scale_top.
const BANK_W = BASE[7]     # 10.739909 deg — the winner's bank
const LAM_W = BASE[9]      # 0.699446     — the winner's blade scale
const P_MEASURED = 5.114485  # kW, tail5, reproduced on the campaign's own path

function probe(bank, lam)
    x = copy(BASE)
    x[7] = bank
    x[9] = lam
    dec = design_from_vector_v10(
        x, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    rot = dec.rotors[1]
    rr = dec.radii[rot.ring_idx]
    span = rot.blade_tip_radius / 0.7
    outer = rr + 0.7 * span
    hubr = rr - 0.3 * span
    A = π * (outer^2 - hubr^2)
    m_blade = 0.420 * span^3
    return (; dec, rot, rr, span, outer, hubr, A, m_blade, bank_derate=cosd(bank)^2.65)
end

const C = probe(BANK_W, LAM_W)
@printf("control (winner): bank %.4f deg  λ %.6f  span %.4f m  area %.4f m²  m_blade %.6f kg\n\n",
    BANK_W, LAM_W, C.span, C.A, C.m_blade)

@printf("%7s  %7s  %8s  %9s  %8s  %10s  %9s  %9s\n",
    "bank", "λ", "span", "area", "A/A₀", "pred P", "over-kg", "Δm_kg")
println("-"^82)

cases = [(BANK_W, LAM_W), (0.0, LAM_W), (0.0, 0.69), (0.0, 0.68),
    (0.0, 0.67), (0.0, 0.66), (0.0, 0.65), (BANK_W, 0.66)]
for (bank, lam) in cases
    q = probe(bank, lam)
    Arat = q.A / C.A
    derat_rat = q.bank_derate / C.bank_derate
    Ppred = P_MEASURED * Arat * derat_rat
    over = 5.0 * max(Ppred - 5.0, 0.0)^2
    dm = 3 * (q.m_blade - C.m_blade)
    @printf("%7.2f  %7.4f  %8.4f  %9.4f  %8.4f  %8.4f kW  %8.4f  %+9.4f\n",
        bank, lam, q.span, q.A, Arat, Ppred, over, dm)
end

println("-"^82)
println("control columns are the measured anchor, not a prediction.")
@printf("winner mass term (measured, seam interception) = 19.450762 kg\n")
@printf("its over-power charge = %.4f kg, twist charge = 0.7627 kg, utilisation = 1.4193 kg\n",
    5.0 * max(P_MEASURED - 5.0, 0.0)^2)

# ── λ that lands the bank-free machine exactly on the 5.0 kW floor ──────────
let
    lo, hi = 0.50, LAM_W
    Pof(lam) = P_MEASURED * (probe(0.0, lam).A / C.A) *
               (probe(0.0, lam).bank_derate / C.bank_derate)
    for _ in 1:60
        mid = 0.5 * (lo + hi)
        # P is INCREASING in λ: above the floor ⇒ the root is below mid.
        (Pof(mid) > 5.0) ? (hi = mid) : (lo = mid)
    end
    lam_star = 0.5 * (lo + hi)
    q = probe(0.0, lam_star)
    @printf("\nbank-free λ that lands exactly on the 5.00 kW floor: λ* = %.6f\n", lam_star)
    @printf("  predicted tail5 = %.4f kW, span %.4f m, blade mass %+.4f kg vs the winner\n",
        Pof(lam_star), q.span, 3 * (q.m_blade - C.m_blade))
    @printf("  total neighbour estimate: %.4f kg mass + ~0 over-power before FoS/twist move\n",
        19.450762 + 3 * (q.m_blade - C.m_blade))
end
