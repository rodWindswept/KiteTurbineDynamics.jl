# sv_probe_winner_geometry.jl — software-validator, 2026-10-01
#
# Read the ACTUAL pre-derate v13 winner genome through the repo's own decoder and
# builder, and report the geometry both aero agents have been arguing about with
# Daisy placeholders: the hub rotor's bank angle, the active-rotor mask, and the
# banked-area retention under each candidate convention.
#
# No ODE. Decode + build only.

using KiteTurbineDynamics, Printf

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

csv = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")
x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]

p = params_at_length(18.8)
xr = copy(x)
xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p)

println("=== winner genome (pre-derate, ", basename(csv), ") ===")
println("  genes: ", round.(x, digits=4))
println("  n_active rotors in the design: ", length(dec.rotors), "  (dec.n_active=", dec.n_active,
        ", mask=", string(dec.mask, base=2), ")")
println("  design.r_hub = ", round(dec.design.r_hub, digits=4))

println("\n=== per-rotor spec ===")
for (i, r) in enumerate(dec.rotors)
    r_ring = dec.radii[r.ring_idx]
    @printf("  rotor %d: ring_idx=%d  r_ring=%.4f m  bank=%.4f deg  tip_off=%.4f  hub_off=%.4f  wind_factor=%.4f\n",
        i, r.ring_idx, r_ring, r.bank_angle_deg, r.blade_tip_radius, r.blade_hub_radius, r.wind_factor)
end

hub = dec.rotors[argmax([r.ring_idx for r in dec.rotors])]
r_ring = dec.radii[hub.ring_idx]
β = hub.bank_angle_deg
t_off = hub.blade_tip_radius
h_off = hub.blade_hub_radius

println("\n=== what the POWER path sees ===")
@printf("  sys.rotor.bank_angle_deg = %.4f\n", sys.rotor.bank_angle_deg)
@printf("  sys.rotor.radius         = %.4f m   (blade_hub_radius = %.4f)\n",
    sys.rotor.radius, sys.rotor.blade_hub_radius)
@printf("  main_rotor_swept_area(sys) = %.6f m^2\n", KiteTurbineDynamics.main_rotor_swept_area(sys))
@printf("  n expansion rotors = %d\n", length(sys.expansion_rotors))
@printf("  r_hub + tip_off = %.4f   (r_ring + tip_off = %.4f)   r_ring + hub_off = %.4f\n",
    dec.design.r_hub + t_off, r_ring + t_off, r_ring + h_off)

# ── area retention under the candidate conventions, on the REAL geometry ──────
c = cosd(β)
A(a, b) = π * (a^2 - b^2)

disc_side = A(r_ring + t_off, r_ring + h_off)        # unbanked, code's own annulus
proj_both = A((r_ring + t_off) * c, (r_ring + h_off) * c)  # rigid disc: both radii scaled
ring_anch = A(r_ring + t_off * c, r_ring + h_off * c)      # only the span projects
proj_code = A(sys.rotor.radius, sys.rotor.blade_hub_radius)

println("\n=== banked-area retention at the winner's own bank angle ===")
@printf("  bank = %.4f deg   cos = %.6f\n", β, c)
@printf("  unbanked annulus (code)          = %.4f m^2\n", disc_side)
@printf("  A(sys.rotor.radius, hub_radius)  = %.4f m^2\n", proj_code)
@printf("  (a) code today: no area cos      = 1.0000   -> tau_total = 2.650   factor %.6f\n", c^2.65)
@printf("  (b) both radii x cos (rigid disc) ret = %.6f -> tau_total = %.3f  factor %.6f\n",
    proj_both / disc_side, 2.65 + log(proj_both / disc_side) / log(c), c^2.65 * (proj_both / disc_side))
@printf("  (c) ring-anchored (span only)     ret = %.6f -> tau_total = %.3f  factor %.6f\n",
    ring_anch / disc_side, 2.65 + log(ring_anch / disc_side) / log(c), c^2.65 * (ring_anch / disc_side))

# aero-validator's general form: ret = c*(2r_ring + c*(t+h))/(2r_ring + t+h)
gen = c * (2r_ring + c * (t_off + h_off)) / (2r_ring + t_off + h_off)
@printf("  general form ret = %.6f  (= (c) when h_off is a signed offset from the ring)\n", gen)

# ── how much does the exponent choice move the winner, at ITS bank angle? ─────
println("\n=== sensitivity of the bank factor to the exponent, at this bank ===")
for e in (2.65, 3.65, 4.65)
    @printf("  cos^%.2f(%0.2f deg) = %.6f   (vs cos^2.65: %+.2f %%)\n",
        e, β, c^e, 100 * (c^e / c^2.65 - 1))
end
println("\n  (power scales as the factor on the disc power; omega responds as factor^(1/3))")
for e in (3.65, 4.65)
    @printf("  omega shift if the exponent moved 2.65 -> %.2f: %+.2f %%\n",
        e, 100 * ((c^e / c^2.65)^(1 / 3) - 1))
end
