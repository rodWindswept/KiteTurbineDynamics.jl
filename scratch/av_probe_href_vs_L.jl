# aero-validator probe: does h_ref (the wind-reference altitude the evaluator
# divides by) track the machine's actual hub altitude as L changes?
#
# Reconstructs the runner's params_at_length body verbatim (run_v13_5kw_masslift.jl:124-138)
# for the Daisy-anchored 5 kW class, then reports h_ref vs hub_altitude(L, elev).
using KiteTurbineDynamics
using Printf
const KTD = KiteTurbineDynamics

const KW = 5.0

function params_at_length(L::Float64)
    p2 = KTD.params_daisy()
    geo = KTD.GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades,
    )
    mat = KTD.MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = KTD.AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = KTD.ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev,
    )
    back = KTD.BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout,
    )
    scaled = KTD.mass_scale(KTD.SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return KTD.override_params(scaled; tether_length=L)
end

p2 = KTD.params_daisy()
elev = p2.elevation_angle
@printf("Daisy anchor: tether=%.3f m  elev=%.3f rad (%.1f deg)  h_ref=%.3f m\n",
    p2.tether_length, elev, rad2deg(elev), p2.h_ref)

# What h_ref the evaluator actually sees at each candidate L
println("\n  L (m)   p.h_ref (m)   hub_alt = L·sin(elev)   v_ref@hub = 11·(hub/h_ref)^(1/7)")
for L in (18.8, 25.0, 30.0, 40.0, 60.0)
    p = params_at_length(L)
    hub = KTD.hub_altitude(L, elev)
    v_hub = 11.0 * (hub / p.h_ref)^(1.0 / 7.0)
    @printf("  %5.1f    %8.3f     %10.3f            %8.3f m/s\n", L, p.h_ref, hub, v_hub)
end

# Ring-count sensitivity to L, holding the transmission-cylinder radius fixed.
r_cyl = p2.trpt_hub_radius * sqrt(KW / 1.5)
println("\n  ring_spacing_v4 cylindrical-section segment count (r_top=$(round(r_cyl,digits=3)) m):")
for L in (18.8, 30.0, 40.0)
    for c in (2.10,)
        zs, rs, n = KTD.ring_spacing_v4(r_cyl, r_cyl, L, c; max_rings=200)
        @printf("    L=%5.1f  target_Lr=%.2f  n_rings=%3d  pack=%.3f m/ring\n",
            L, c, n, L / max(1, n))
    end
end

# Tether mass at 18.8 m, reproduced exactly as the two src sites compute it
L0 = 18.8
m_tether = 3 * L0 * KTD.DYNEEMA_DENSITY * pi * (0.0015)^2
@printf("\n  m_tether(L=18.8, n_lines=3, d=1.5 mm) = %.4f kg\n", m_tether)
