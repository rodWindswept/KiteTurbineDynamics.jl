# scratch/scenario_sweep.jl — find (Q_max, T_min) by transient scenario search.
#
# Protocol (REV 2 §5.1): settle → relax 2×5 s → assert sane baseline → apply
# fault → track (Q, T) and the torque-helix inward force F_helix ∝ Q²/T.
#
# TODO scenarios (need time-varying lift / pitch-depower, not yet wired):
#   - lifter drop
#   - high-wind feather ramp
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
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
n_lines = pc.n_lines
n_seg = sys.n_ring - 1
L_seg = pc.tether_length / n_seg
ring_r = [(sys.nodes[sys.ring_ids[s]]::KiteTurbineDynamics.RingNode).radius for s in 1:(n_seg + 1)]

function settle_baseline()
    wf = (r, t) -> [11.0, 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=30_000)
    for _ in 1:2
        run_canonical_sim!(u, sys, pc, wf, round(Int, 5.0 / dt), dt; lift_device=lift, lin_damp=0.05)
    end
    return u, wf
end

function assert_sane(u, wf, label)
    @assert !sys.any_broken[] "rope broke during settle: $label"
    @assert all(isfinite, u) "non-finite state: $label"
    N = sys.n_total; Nr = sys.n_ring
    ω_gnd = abs(u[6N + Nr + 1])
    @assert 1.0 < ω_gnd < 100.0 "ω_gnd off productive branch ($(round(ω_gnd,digits=1))): $label"
    Tseg = [sum(KiteTurbineDynamics.get_segment_tension(u, sys, pc, s, j) for j in 1:n_lines) / n_lines for s in 1:n_seg]
    @assert all(>(0.0), Tseg) "non-positive line tension: $label"
    println("  ✓ baseline sane ($label): ω_gnd=$(round(ω_gnd,digits=1)) rad/s  T_line=$(round(Tseg[1],digits=1)) N  n_broken=$(sum(sys.broken_lines))")
end

# Sample (Q, T, twist, F_helix) per segment during a transient window.
function track(u_start, wf; window_s=10.0, save_every=1000, k_mppt=nothing, k_mppt_fn=nothing)
    u = copy(u_start)
    k_mppt === nothing || (sys.k_mppt_ref[] = k_mppt)
    n_steps = round(Int, window_s / dt)
    samples = NamedTuple{(:t, :Q, :T, :twist_deg, :Fhel, :Ncomp),Tuple{Float64,Vector{Float64},Vector{Float64},Vector{Float64},Vector{Float64},Vector{Float64}}}[]
    run_canonical_sim!(u, sys, pc, wf, n_steps, dt; lift_device=lift, lin_damp=0.05,
        callback = (u_c, t_c, step) -> begin
            k_mppt_fn === nothing || (sys.k_mppt_ref[] = k_mppt_fn(t_c))
            if step % save_every == 0
                N = sys.n_total; Nr = sys.n_ring
                alpha = u_c[(6N + 1):(6N + Nr)]
                twist = [abs(alpha[i + 1] - alpha[i]) for i in 1:n_seg]
                Tseg = [sum(KiteTurbineDynamics.get_segment_tension(u_c, sys, pc, s, j) for j in 1:n_lines) / n_lines for s in 1:n_seg]
                Q = Vector{Float64}(undef, n_seg)
                Fhel = Vector{Float64}(undef, n_seg)
                Ncomp = Vector{Float64}(undef, n_seg)
                for s in 1:n_seg
                    r_s = 0.5 * (ring_r[s] + ring_r[s + 1])
                    chord = sqrt(L_seg^2 + 2 * r_s^2 * (1 - cos(twist[s])))
                    Q[s] = n_lines * Tseg[s] * r_s^2 * sin(twist[s]) / max(chord, 1e-9)
                    Fhel[s] = 2.0 * Tseg[s] * r_s * (1 - cos(twist[s])) / max(chord, 1e-9)
                    Ncomp[s] = Fhel[s] / (2.0 * sin(π / n_lines))
                end
                push!(samples, (t=t_c, Q=Q, T=Tseg, twist_deg=rad2deg.(twist), Fhel=Fhel, Ncomp=Ncomp))
            end
        end)
    return samples
end

function report_scenario(label, samples)
    worst = (t=0.0, seg=1, Fhel=0.0, Q=0.0, T=0.0, twist=0.0, Ncomp=0.0)
    for smp in samples
        for s in 1:n_seg
            if smp.Fhel[s] > worst.Fhel
                worst = (t=smp.t, seg=s, Fhel=smp.Fhel[s], Q=smp.Q[s], T=smp.T[s], twist=smp.twist_deg[s], Ncomp=smp.Ncomp[s])
            end
        end
    end
    @printf("  %-28s max F_helix = %7.1f N/vertex  (seg %d, t=%.2f s)\n", label, worst.Fhel, worst.seg, worst.t)
    @printf("      at that instant: Q = %7.1f N·m   T = %7.1f N   twist = %6.2f°   N_comp = %7.1f N\n",
            worst.Q, worst.T, worst.twist, worst.Ncomp)
    return worst
end

u_settled, wf_rated = settle_baseline()
assert_sane(u_settled, wf_rated, "rated settle")

println()
println("scenario (window = 10 s)  |  max torque-helix inward force and (Q, T) at that instant")
println("-"^100)

# 1. Wind lull: rated → 3 m/s at t = 1 s.
wf_lull = (pos, t) -> [t < 1.0 ? 11.0 : 3.0, 0.0, 0.0]
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
s = track(u_settled, wf_lull)
report_scenario("lull (11 → 3 m/s)", s)

# 2. Coherent gust: rated → 25 m/s at t = 1 s.
wf_gust = (pos, t) -> [t < 1.0 ? 11.0 : 25.0, 0.0, 0.0]
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
s = track(u_settled, wf_gust)
report_scenario("gust (11 → 25 m/s)", s)

# 3. Generator load step: k_mppt ×2 from the settled load.
s = track(u_settled, wf_rated; k_mppt=2.0 * K_MPPT_5KW_HONEST)
report_scenario("load step (k_mppt ×2)", s)

# 4. Generator load step: k_mppt ×3 (the "ebrake" the DLF calibration excluded).
s = track(u_settled, wf_rated; k_mppt=3.0 * K_MPPT_5KW_HONEST)
report_scenario("load step (k_mppt ×3) [excluded op.]", s)

# 5. k_mppt EASE (NOT feather) — illustrative negative result. Easing the
#    generator load does NOT cap torque: at 25 m/s the rotor aero torque is huge,
#    so with no load to absorb it the rotor SPINS UP and the twist blows out
#    (87.9° > 78.8° collapse). "Feather" must reduce Cp/Ct, not ease k_mppt.
wf_feather = (pos, t) -> [11.0 + 14.0 * clamp(t / 5.0, 0.0, 1.0), 0.0, 0.0]
k_feather = (t) -> K_MPPT_5KW_HONEST * (11.0 / (11.0 + 14.0 * clamp(t / 5.0, 0.0, 1.0)))^2
s = track(u_settled, wf_feather; k_mppt_fn=k_feather)
report_scenario("k_mppt ease (WRONG feather) → spin-up", s)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST

println("-"^100)
println("FEATHER GAP: high-wind feather (reduce Cp/Ct above rated) is NOT modelled —")
println("the ODE aero uses ct_at_tsr/cp_at_tsr with no pitch/feather term, and the only")
println("stall is backline payout (run_pitch_depower!, a shutdown sequence). A feather")
println("factor (reduce rotor effective wind/Cp/Ct above rated) must be added to the ODE")
println("before the high-wind structural case can be sized. First-order proxy: cap the")
println("effective wind at rated → the feathered state is the rated state (F_helix ≈ 103 N/vertex).")
