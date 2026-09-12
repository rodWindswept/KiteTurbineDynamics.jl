# scratch/r7_settle_chord_fix.jl — VERIFY the root cause of the settle wind-up.
#
# Finding (scratch/r7_preload_audit.jl + r7_tension_settle_vs_run.jl):
#   The settle INTENDS a line tension of 283,280,278,275,234,232,267,265 N
#   (F_ax/n_lines, from the axial preload) but ACHIEVES 1947,...,601 N.
#   Cause: the preload restore sets the ring AXIAL gap for the UNTWISTED
#   configuration, then the twist bisection adds Δα.  The chord is
#       chord² = L_ax² + r_a² + r_b² − 2·r_a·r_b·cos Δα
#   so twisting alone stretches the line by 2r²(1−cos Δα)/chord² ≈ 1.6e-3 at
#   6.6° — SIX TIMES the intended axial preload strain (2.7e-4).  The bisection
#   then sees a 7x-too-stiff segment and lands on 6.6° instead of ~50°.
#
# Fix under test: solve (Δα, L_ax) TOGETHER per segment so the line tension is
# the intended preload AT the final twist:
#   (i)  chord = chord0 · (1 + T_s/EA_single)
#   (ii) n·T_s·r_a·r_b·sin(Δα)/chord = τ_target
# Both are closed form — no Newton, no ODE calls, no per-eval cost.
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
                           tether_length=18.8)
end

p = params_5kw_188()
x = seed_genome(5.0)
x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    k_mppt=K_MPPT_5KW_HONEST)
sizing = size_beams_closed_form(dec, p, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
N = sys.n_total
Nr = sys.n_ring
n_seg = Nr - 1

u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
    lift_device=lift, wind_fn=wf, n_op=150_000)
ω_eq = u[6N + Nr + 1]
τ_gen = K_MPPT_5KW_HONEST * ω_eq^2
α_settle = [u[6N + r] for r in 1:Nr]

# ── the same preload the initialiser intends ─────────────────────────────────
β_r = pc.elevation_angle
T_cyan_des = design_preload_from_sky_anchor(pc, lift)
EA_tot = pc.n_lines * pc.e_modulus * π * (pc.tether_diameter / 2)^2
EA_single = pc.e_modulus * π * (pc.tether_diameter / 2)^2
m_rotor_d = pc.n_blades * pc.m_blade
thrust_r = 0.5 * pc.rho * pc.v_wind_ref^2 * π * pc.rotor_radius^2 * 0.8 * cos(β_r)^2
F_aero_z_r = thrust_r * sin(β_r) + (m_rotor_d + sys.kite.mass) * (-9.81)
F_top_ax_r = max(F_aero_z_r / sin(β_r) + T_cyan_des, 20.0)
g_inc = pc.m_ring * 9.81 / sin(β_r)
F_ax = zeros(n_seg)
F_ax[n_seg] = F_top_ax_r
for i in (n_seg - 1):-1:1
    F_ax[i] = F_ax[i + 1] + g_inc
end

radii = [(sys.nodes[sys.ring_ids[k]]::RingNode).radius for k in 1:Nr]
chord0 = [ROPE_SUBSEGS * sys.sub_segs[(k - 1) * pc.n_lines * ROPE_SUBSEGS + 1].length_0 for k in 1:n_seg]

# τ_target per segment.  Use the settle's own converged chain as the reference
# for the LOWER segments (its rings 1..7 are in exact torque balance — measured
# max|τ_res| = 4 N·m on ring 1, ~0 on 2..8), and τ_gen for segment 1.
τ_target = fill(τ_gen, n_seg)

@printf("ω_eq=%.4f  τ_gen=%.1f N·m   settle first-seg Δα=%.2f°  total=%.2f°\n",
    ω_eq, τ_gen, (α_settle[2] - α_settle[1]) * 180 / π, (α_settle[end] - α_settle[1]) * 180 / π)

# ── new geometry: solve (Δα, L_ax) per segment ───────────────────────────────
sd = [cos(β_r), 0.0, sin(β_r)]
newα = zeros(Nr)
newrp = zeros(3)
newpos = zeros(3, Nr)
newpos[:, 1] .= 0.0
Δs = Float64[]
Lax = Float64[]
for s in 1:n_seg
    r_a, r_b = radii[s], radii[s + 1]
    T_s = F_ax[s] / pc.n_lines
    chord = chord0[s] * (1 + T_s / EA_single)
    # (ii) torque balance → sin Δα
    sn = τ_target[s] * chord / (pc.n_lines * T_s * r_a * r_b)
    Δα = asin(clamp(sn, -1.0, 1.0))
    # (i) chord constraint → axial gap
    L2 = chord^2 - (r_a^2 + r_b^2 - 2 * r_a * r_b * cos(Δα))
    L = sqrt(max(L2, 1e-6))
    push!(Δs, Δα)
    push!(Lax, L)
    newα[s + 1] = newα[s] + Δα
    newrp = newpos[:, s] + L .* sd
    newpos[:, s + 1] .= newrp
    @printf("seg %d: T=%.0f  chord0=%.4f→%.4f  sinΔα=%.4f  Δα=%6.2f°  L_ax=%.4f (was %.4f)\n",
        s, T_s, chord0[s], chord, sn, rad2deg(Δα), L,
        sqrt(max(chord0[s]^2 - (r_a^2 + r_b^2 - 2 * r_a * r_b * cos(Δα)), 0.0)))
end
@printf("new total Δα = %.2f°   new shaft length = %.3f m (settle %.3f m)\n",
    sum(Δs) * 180 / π, sum(Lax), norm(u[3 * (sys.rotor.node_id - 1) + 1:3 * sys.rotor.node_id]))

# ── apply, re-interpolate rope nodes, run ────────────────────────────────────
stride = 1 + pc.n_lines * ROPE_NODES_PER_LINE
for k in 1:Nr
    gid = sys.ring_ids[k]
    u[(3 * (gid - 1) + 1):(3 * gid)] .= newpos[:, k]
    u[6N + k] = newα[k]
end
hub_gid = sys.rotor.node_id
hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub_gid, hub_ri)
for s in 1:n_seg
    ctr_a = u[(3 * (sys.ring_ids[s] - 1) + 1):(3 * sys.ring_ids[s])]
    ctr_b = u[(3 * (sys.ring_ids[s + 1] - 1) + 1):(3 * sys.ring_ids[s + 1])]
    na = sys.nodes[sys.ring_ids[s]]::RingNode
    nb = sys.nodes[sys.ring_ids[s + 1]]::RingNode
    for j in 1:pc.n_lines
        pa = KiteTurbineDynamics.attachment_point(ctr_a, na.radius, newα[s], j, pc.n_lines, pp1, pp2)
        pb = KiteTurbineDynamics.attachment_point(ctr_b, nb.radius, newα[s + 1], j, pc.n_lines, pp1, pp2)
        for m in 1:ROPE_NODES_PER_LINE
            frac = m / ROPE_SUBSEGS
            gid = (s - 1) * stride + 2 + (j - 1) * ROPE_NODES_PER_LINE + (m - 1)
            u[(3 * (gid - 1) + 1):(3 * gid)] .= pa .+ frac .* (pb .- pa)
        end
    end
end
u[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
u[(3N + 1):6N] .= 0.0
set_orbital_velocities!(u, sys, pc)

function report(tag, u)
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
    α = [u[6N + r] for r in 1:Nr]
    @printf("%-9s Δα_tot=%7.2f°  first-seg=%6.2f°  T=%s\n", tag,
        (α[end] - α[1]) * 180 / π, ef.segment_twist_deg[1],
        join(round.(ef.segment_tension, digits=0), ","))
end

@printf("\n--- BEFORE the fix (settle as returned) ---\n")
ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
@printf("  T=%s\n", join(round.(ef.segment_tension, digits=0), ","))
@printf("\n--- AFTER the fix (matched-place initial state) ---\n")
report("t=0", u)
for k in 1:6
    run_canonical_sim!(u, sys, pc, wf, round(Int, 10.0 / dt), dt;
        lift_device=lift, lin_damp=0.05)
    report("t=$(10k)s", u)
end
