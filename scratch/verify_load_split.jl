# scratch/verify_load_split.jl — de-risk the load-model claims for the 5 kW winner.
#
# (a) Axial vs bending split of the worst ring's utilisation (review finding 3):
#     is the FoS axial-dominated (Euler-only sizing suffices) or bending-heavy?
# (b) Effective DLF: measure N_comp/T_line from the ODE and compare to the
#     closed form's DLF=1.2 (review finding 1: "0.095·T vs 0.693·T").
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))
using KiteTurbineDynamics, Printf
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

x = [0.03, 0.027724379068369474, 0.7880304550607653, 0.9836099040123638, 4.32,
     0.8626630280706367, 2.799241474826894, 3.0, 0.6978820732360798, 1.3831182070079888,
     19.94688644098879, 6.690368026101, 0.7008150303267114, 1.0]
x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
x[10] = Float64(round(Int, clamp(x[10], 1, 3)))

p_base = params_at_length(L)
dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p_base; power_W=KW * 1000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)

sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p_base.tether_diameter, base_params=p_base)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST

lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
wf = (r, t) -> [11.0, 0.0, 0.0]
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=30_000)
for _ in 1:2
    run_canonical_sim!(u, sys, pc, wf, round(Int, 5.0 / dt), dt; lift_device=lift, lin_damp=0.05)
end

ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 10.0, wf, lift)

n = pc.n_lines
den = 2.0 * sin(π / n)   # N_comp = F_v / den
println("n_lines=$n  2·sin(π/n)=$(round(den, digits=3))")
println("closed-form DLF assumed = 1.2  →  N_comp/T_line = $(round(1.2/den, digits=3))")
println()
println("ring  |  FoS    | util_ax | util_bend | ax_frac | N_comp(N) | T_line(N) | N_comp/T_line")
println("------|---------|---------|-----------|---------|-----------|-----------|--------------")
worst = argmin(ef.ring_fos)
for k in eachindex(ef.ring_fos)
    ax = ef.ring_util_axial[k]
    be = ef.ring_util_bending[k]
    axf = (ax + be) > 0 ? ax / (ax + be) : 0.0
    Tline = k <= length(ef.segment_tension) ? ef.segment_tension[k] : ef.segment_tension[end]
    ratio = Tline > 0 ? ef.ring_Ncomp[k] / Tline : 0.0
    mark = k == worst ? "  ← worst" : ""
    @printf("%4d  | %6.2f | %7.3f | %9.3f | %7.3f | %9.1f | %9.1f | %12.3f%s\n",
            k, ef.ring_fos[k], ax, be, axf, ef.ring_Ncomp[k], Tline, ratio, mark)
end
println()
ax = ef.ring_util_axial[worst]; be = ef.ring_util_bending[worst]
println("Worst ring: axial share = $(round(ax/(ax+be), digits=3)) of total util (FoS=$(round(ef.ring_fos[worst], digits=3)))")
println("effective DLF at worst ring = $(round(ef.ring_Ncomp[worst]*den/max(ef.segment_tension[worst],1e-9), digits=3))  (closed-form assumed 1.2)")
println()
println("segment | twist_deg | tension(N) | torque(N·m)")
for s in eachindex(ef.segment_twist_deg)
    println(@sprintf("  %3d   |  %7.2f  | %9.1f | %10.2f", s, ef.segment_twist_deg[s], ef.segment_tension[s], ef.segment_torque[s]))
end
