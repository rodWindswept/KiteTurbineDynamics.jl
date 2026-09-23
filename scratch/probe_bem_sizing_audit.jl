# scratch/probe_bem_sizing_audit.jl
#
# BEM multi-rotor blade-sizing audit (2026-09-23).
#
# Rod's question: a 3-rotor machine should carry LESS total blade mass than a
# single-rotor machine of the same power (Peter Jamieson: A_total ≈ const,
# span ∝ 1/√N, M_blades ∝ 1/√N).  The campaign shows island 1 (3 rotors) at
# 11.5 kg against island 3 (1 rotor) at 3.0 kg.  This probe decomposes the gap
# into the four candidate defects, MEASURED, not asserted:
#
#   A. disc vs annulus span sizing: span = 0.75·r_disc·λ, where r_disc solves
#      A = π·r_disc², instead of solving the ring annulus
#      A = 2π·R_ring·s + 0.4π·s²  (70/30 split about the ring).
#   B. power_split = 0.6 concentrating load on the top rotor.
#   C. the n_active == 1 branch: a single-rotor machine is sized for 0.6·P.
#   D. the inflow model: shear baseline h_ref = 50 m, then the co-axial wake
#      blocking factor.
#
# Usage: julia --project=. scratch/probe_bem_sizing_audit.jl [island_dir ...]

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KTD = KiteTurbineDynamics
const RESDIR = joinpath(
    @__DIR__, "..", "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_physlift"
)
const M_REF = 0.420      # kg per blade at span 1.0 m (M_BLADE_REF_KG)

"Positive root of 0.4π s² + 2πR s − A = 0  (70/30 ring-anchored annulus)."
function annulus_span(A::Float64, R::Float64)
    b = 2π * R
    return (-b + sqrt(b^2 + 1.6π * A)) / (0.8π)
end

"70/30 annulus area for span s on ring radius R."
annulus_area(s::Float64, R::Float64) = π * ((R + 0.7s)^2 - (R - 0.3s)^2)

"Blade assembly mass under the span³ law (n_blades identical blades)."
blade_mass(s::Float64, n::Int) = n * M_REF * s^3

function audit(ISLAND)
    CSV = joinpath(RESDIR, ISLAND, "best_vector.csv")
    p0 = params_at_length(params_daisy(), 18.8, 5.0)
    bf = BLOCKING_WIND_FACTOR_5KW
    xv = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
    xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
    dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p0; power_W=5000.0,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=bf)

    d = dec.design
    @printf("\n═══════════════ %s ═══════════════\n", ISLAND)
    @printf(
        "genome n_lines=%d rings=%d r_hub=%.4f tether=%.2f n_active(rotors)=%d\n",
        d.n_lines, dec.n_rings, d.r_hub, d.tether_length, length(dec.rotors)
    )
    @printf("blocking_factor = %.6f  (0.75^(1/3))\n", bf)
    @printf("genome blade_scale per rotor = %s\n",
        join((@sprintf("%.4f", r.blade_scale) for r in dec.rotors), ", "))

    @printf(
        "\n%4s %5s %8s %8s %9s %9s %9s %9s %9s %9s\n",
        "rot", "ring", "R_ring", "P_i[W]", "v_i[m/s]", "r_disc", "span_code",
        "A_req", "A_code", "s_annu"
    )
    n_active = length(dec.rotors)
    tot_code = 0.0
    tot_annu = 0.0
    tot_fixed = 0.0     # annulus + equal share + freestream wind
    for (i, r) in enumerate(dec.rotors)
        R_ring = dec.radii[r.ring_idx]
        A_req = π * r.r_rotor^2                      # what the code sized FOR
        s_code = 0.75 * r.r_rotor * r.blade_scale    # what the code SET
        A_code = annulus_area(s_code, R_ring)        # what it actually sweeps
        s_annu = annulus_span(A_req, R_ring)
        tot_code += blade_mass(s_code, d.n_lines)
        tot_annu += blade_mass(s_annu, d.n_lines)
        @printf(
            "%4d %5d %8.4f %8.1f %9.4f %9.4f %9.4f %9.4f %9.4f %9.4f\n",
            i, r.ring_idx, R_ring, 5000.0 * (i == 1 ? 0.6 : 0.4 / max(n_active - 1, 1)),
            r.v_wind, r.r_rotor, s_code, A_req, A_code, s_annu
        )
    end
    @printf(
        "\ntotal blade mass: code %.4f kg | annulus-sized %.4f kg | ratio %.2fx\n",
        tot_code, tot_annu, tot_code / max(tot_annu, 1e-12)
    )

    # ── three-way decomposition on the TOP rotor ─────────────────────────────
    r1 = dec.rotors[1]
    R_ring = dec.radii[r1.ring_idx]
    v_code = r1.v_wind
    P_top_code = 0.6 * 5000.0
    P_top_equal = 5000.0 / n_active
    Cp = KTD.BEM.cp_bem(d.n_lines, 4.1)
    A_of(P, v) = P / (Cp * 0.5 * 1.225 * v^3)
    sA = annulus_span(A_of(P_top_code, v_code), R_ring)          # annulus fix only
    sB = annulus_span(A_of(P_top_equal, v_code), R_ring)         # + equal sharing
    sD = annulus_span(A_of(P_top_equal, 11.0), R_ring)           # + freestream wind
    s_code = 0.75 * r1.r_rotor * r1.blade_scale
    m(s) = M_REF * s^3
    @printf("\n── top rotor: cumulative fix, span and per-blade mass ──\n")
    @printf("Cp(n_lines=%d, tsr=4.1) = %.5f\n", d.n_lines, Cp)
    @printf("code:                    span %.4f m  m/blade %.4f kg\n", s_code, m(s_code))
    @printf("+ annulus sizing (A):    span %.4f m  m/blade %.4f kg   (%.2fx)\n",
        sA, m(sA), m(s_code) / m(sA))
    @printf("+ equal power share (B): span %.4f m  m/blade %.4f kg   (%.2fx)\n",
        sB, m(sB), m(sA) / m(sB))
    @printf("+ freestream wind (D):   span %.4f m  m/blade %.4f kg   (%.2fx)\n",
        sD, m(sD), m(sB) / m(sD))
    @printf("total code -> fully fixed: %.1fx lighter per blade\n", m(s_code) / m(sD))

    # ── D detail: does the top rotor see MORE wind than the lower ones? ──────
    @printf("\n── inflow per rotor (shear then blocking) ──\n")
    for (i, r) in enumerate(dec.rotors)
        alt = max(dec.zs[r.ring_idx] * sind(30.0), 1.0)
        v_shear = KTD.wind_speed_at_ring(alt, 9.4, 11.0)
        @printf(
            "  rot %d ring %2d  altitude %.2f m  shear %.4f m/s  wind_factor %.4f  ->  v %.4f\n",
            i, r.ring_idx, alt, v_shear, r.wind_factor, r.v_wind
        )
    end
    alt_top = max(dec.zs[dec.rotors[1].ring_idx] * sind(30.0), 1.0)
    @printf("  h_ref used = 50.0 m (wind_speed_at_ring's default; the hub_altitude\n")
    @printf("  argument is IGNORED).  At %.2f m that scales 11 m/s to %.4f m/s\n",
        alt_top, KTD.wind_speed_at_ring(alt_top, 9.4, 11.0))
    @printf("  = a factor %.4f on speed, %.4f on area, ~%.1fx on blade mass.\n",
        KTD.wind_speed_at_ring(alt_top, 9.4, 11.0) / 11.0,
        (11.0 / KTD.wind_speed_at_ring(alt_top, 9.4, 11.0))^3,
        (sB / sD)^3)

    # ── Jamieson check: what SHOULD the totals be? ───────────────────────────
    A_total_needed = A_of(5000.0, 11.0)
    @printf("\n── Jamieson check at 5 kW / 11 m/s (Cp=%.4f) ──\n", Cp)
    @printf("A_total required = %.2f m²  (single rotor r_disc = %.3f m)\n",
        A_total_needed, sqrt(A_total_needed / π))
    for N in (1, 3)
        A_each = A_total_needed / N
        sp = annulus_span(A_each, R_ring)
        @printf(
            "  N=%d: A_each %.2f m² -> annulus span %.4f m -> total blade mass %.4f kg (3 blades each)\n",
            N, A_each, sp, N * blade_mass(sp, 3)
        )
    end
    @printf("  Jamieson: total blade mass should fall as 1/sqrt(N), so N=3 -> %.3f kg\n",
        blade_mass(annulus_span(A_total_needed, R_ring), 3) / sqrt(3))
    return nothing
end

islands = isempty(ARGS) ? ["island_1", "island_2", "island_3"] : ARGS
for isl in islands
    audit(isl)
end
println("\n=== done ===")
