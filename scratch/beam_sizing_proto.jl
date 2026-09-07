# scratch/beam_sizing_proto.jl — prototype: closed-form TRPT beam sizing for the 5 kW winner.
# Demonstrates that beam OD should be DERIVED from rotor sizing (FoS ≥ 2.5), not
# searched as a free gene.  Uses the EXISTING closed-form evaluator
# (evaluate_design → _evaluate_trpt_design_impl: DLF × tension → Euler buckling).
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))
using KiteTurbineDynamics
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const L = 18.8
const KW = 5.0

function params_at_length(L)
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

# Winner genome (best_vector.csv)
x = [0.03, 0.027724379068369474, 0.7880304550607653, 0.9836099040123638, 4.32,
     0.8626630280706367, 2.799241474826894, 3.0, 0.6978820732360798, 1.3831182070079888,
     19.94688644098879, 6.690368026101, 0.7008150303267114, 1.0]
x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
x[10] = Float64(round(Int, clamp(x[10], 1, 3)))

p_base = params_at_length(L)

function decode(xv)
    dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p_base; power_W=KW * 1000.0,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
        rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    # Equivalent disc radius for the closed-form thrust model (annulus → disc).
    r_out = 0.0
    if !isempty(dec.rotors)
        r = dec.rotors[1]
        r_out = dec.design.r_hub + r.blade_tip_radius
        r_in = max(dec.design.r_hub + r.blade_hub_radius, 0.0)
        r_out = sqrt(max(r_out^2 - r_in^2, 0.0))
    end
    return dec, r_out
end

function report(label, dec, r_out; fos_req=2.5)
    er = evaluate_design(dec.design;
        r_rotor=r_out, elev_angle=π / 6, v_peak=25.0, fos_req=fos_req,
        omega_rotor=13.5, m_blade_total=3.11, v_rated=11.0, P_rated=5400.0,
        max_ground_radius=5.0)
    println("═══ $label ═══")
    println("  Do_top=$(round(dec.design.Do_top*1000, digits=1)) mm  t/D=$(round(dec.design.t_over_D, digits=4))  exp=$(round(dec.design.Do_scale_exp, digits=3))")
    println("  min_fos (closed-form) = $(round(er.min_fos, digits=3))   feasible=$(er.feasible)")
    for (i, d) in enumerate(er.Do_per_ring)
        println("    ring $(i+1): Do=$(round(d*1000, digits=2)) mm  N_comp=$(round(er.N_comp_per_ring[i], digits=1)) N  P_crit=$(round(er.P_crit_per_ring[i], digits=0)) N  FoS=$(round(er.fos_per_ring[i], digits=3))")
    end
    println("  mass_total = $(round(er.mass_total_kg, digits=3)) kg  (beams $(round(er.mass_beams_kg, digits=3)) + knuckles $(round(er.mass_knuckles_kg, digits=3)))")
    return er
end

dec, r_out = decode(x)
println("r_equiv = $(round(r_out, digits=2)) m")
report("current winner (Do_top = 30 mm)", dec, r_out)

# Bisect Do_top (x[1]) to hit min_fos ≈ 2.5, keeping t_over_D and exp fixed.
function bisect_do_top(x, r_out; fos_req=2.5)
    lo, hi = 0.02, 0.30
    for _ in 1:50
        mid = 0.5 * (lo + hi)
        xv = copy(x); xv[1] = mid
        dec_mid, _ = decode(xv)
        er = evaluate_design(dec_mid.design; r_rotor=r_out, elev_angle=π / 6, v_peak=25.0,
            fos_req=fos_req, omega_rotor=13.5, m_blade_total=3.11, v_rated=11.0, P_rated=5400.0,
            max_ground_radius=5.0)
        if er.min_fos < fos_req
            lo = mid
        else
            hi = mid
        end
    end
    return 0.5 * (lo + hi)
end
do_solved = bisect_do_top(x, r_out)
xv = copy(x); xv[1] = do_solved
dec_solved, _ = decode(xv)
report("solved for FoS ≈ 2.5 (Do_top bisected)", dec_solved, r_out)
println("Do_top to hit FoS 2.5 @ peak 25 m/s = $(round(do_solved*1000, digits=1)) mm")
