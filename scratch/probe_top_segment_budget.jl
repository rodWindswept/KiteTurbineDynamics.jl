# scratch/probe_top_segment_budget.jl
#
# DECISIVE PROBE (2026-09-22): where does each rotor's axial thrust enter the
# TRPT preload profile?
#
# The Item 4 remediation added EVERY rotor's axial thrust to `T_thrust` in
# `lift_chain_design`.  `T_thrust` feeds Section B,
#     T_top = T_thrust + n·T_b·cosθ − W_rotor·sinβ,
# which sizes the TOP segment and, through `design_axial_preload`, every segment
# below it.  That is one of two candidate placements.  The other:
#
#   Free body of ring r (thrust F_r, weight W_r, segment above S_{r}, below S_{r-1}):
#       S_{r-1} = S_r + F_r − W_r·sinβ
#   so each rotor's thrust enters the segment IMMEDIATELY BELOW its own ring, and
#   the TOP segment carries the MAIN rotor only.
#
# This probe measures the ODE's own settled per-segment tensions and reads off the
# steps.  If S_top ≈ T_main + bridle − W·sinβ and the steps below match each
# expansion rotor's thrust, placement 2 is correct and `T_thrust` must stay
# main-rotor-only.
#
# Usage: julia --project=. scratch/probe_top_segment_budget.jl [island_dir]

using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const ISLAND = length(ARGS) >= 1 ? ARGS[1] : "island_1"
const RESDIR = joinpath(
    @__DIR__, "..", "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_physlift"
)
const CSV = joinpath(RESDIR, ISLAND, "best_vector.csv")

pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]

p0 = params_at_length(params_daisy(), 18.8, 5.0)
bf = BLOCKING_WIND_FACTOR_5KW
xv = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p0; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=bf)
cfg = KiteTurbineDynamics.ObjectiveConfig(;
    power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=bf)
sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p0, cfg)
sys, u0, p = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p0.tether_diameter, base_params=p0, min_wall_m=2e-3,
    beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = lift_for(sys, p)
wf = (r, t) -> [p.v_wind_ref, 0.0, 0.0]

u = settle_to_operational_state(sys, copy(u0), p, 60.0;
    lift_device=lift, wind_fn=wf, n_op=300_000)
N, Nr = sys.n_total, sys.n_ring
n_seg = Nr - 1
hub = sys.rotor.node_id
hub_ri = (sys.nodes[hub]::RingNode).ring_idx
ω = u[6N + Nr]
β = p.elevation_angle
sd = normalize(pos(u, hub) .- pos(u, 1))

# ── Predicted thrusts at the settled state, ODE-consistent ────────────────────
v_hub = norm(wf(pos(u, hub), 0.0)) * sys.rotor.wind_factor
λ = abs(ω) * sys.rotor.radius / max(v_hub, 1e-6)
T_main = 0.5 * p.rho * v_hub^2 * KiteTurbineDynamics.main_rotor_swept_area(sys) *
         KiteTurbineDynamics.ct_at_tsr(λ) * cos(β)^2
thrust_at = Dict{Int,Float64}()
for er in sys.expansion_rotors
    gid = sys.ring_ids[er.ring_idx]
    r_nom = (sys.nodes[gid]::RingNode).radius
    vwm = norm(wf(pos(u, gid), 0.0)) * er.wind_factor
    _, Fa, _, _, _ = KiteTurbineDynamics.expansion_rotor_forces(
        er, p.rho, vwm, abs(ω), rad2deg(β), r_nom, T_main, p.n_lines
    )
    thrust_at[er.ring_idx] = Fa
end
W_r(r) = (sys.nodes[sys.ring_ids[r]]::RingNode).mass * 9.81 * sin(β)

@printf("=== %s  settled: omega=%.4f rad/s  rings=%d  segs=%d ===\n", ISLAND, ω, Nr, n_seg)
@printf("main rotor thrust (ring %d)  = %+9.3f N\n", Nr, T_main)
for r in sort(collect(keys(thrust_at)))
    @printf("expansion thrust (ring %d)   = %+9.3f N\n", r, thrust_at[r])
end

# ── Measured per-segment tension (scalar sum over lines) ──────────────────────
S = zeros(n_seg)
Sax = zeros(n_seg)   # axial projection, for comparison with Section B
for s in 1:n_seg
    ga, gb = sys.ring_ids[s], sys.ring_ids[s + 1]
    d = pos(u, gb) .- pos(u, ga)
    L = norm(d)
    dirn = L > 0 ? d ./ L : sd
    for j in 1:p.n_lines
        T = KiteTurbineDynamics.get_segment_tension(u, sys, p, s, j)
        S[s] += T
        Sax[s] += T * dot(dirn, sd)
    end
end

@printf("\n── measured segment tensions (top → bottom) ──\n")
@printf("%5s %12s %12s %12s\n", "seg", "T_sum[N]", "S_axial[N]", "Δ down[N]")
for s in n_seg:-1:1
    Δ = s < n_seg ? S[s] - S[s + 1] : NaN
    @printf("%5d %12.3f %12.3f %12s\n", s, S[s], Sax[s],
        s < n_seg ? @sprintf("%+.3f", Δ) : "—")
end

# ── What does the TOP segment actually carry? ─────────────────────────────────
# Bridle axial contribution at the settled state.
pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
bear = sys.bearing_id
R_hub = (sys.nodes[hub]::RingNode).radius
T_bridle_tot = 0.0
for j in 1:p.n_lines
    pa = attachment_point(pos(u, hub), R_hub, u[6N + Nr], j, p.n_lines, pp1, pp2)
    d = pos(u, bear) .- pa
    L = norm(d)
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        (ss.end_a.is_ring ? ss.end_a.line_idx : ss.end_b.line_idx) == j || continue
        T_bridle_tot += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
end
cθ = 0.0
begin
    d = KiteTurbineDynamics.lift_chain_design(sys, p, lift, pos(u, hub); omega_eq=ω)
    if d !== nothing
        cθ = d.cosθ
        @printf("\n── Section B prediction for the TOP segment (seg %d) ──\n", n_seg)
        P_main = T_main + p.n_lines * d.T_bridle * cθ - W_r(Nr)
        @printf("  main-rotor only      : %+9.3f N\n", P_main)
        @printf("  main + Σ expansion   : %+9.3f N   (Δ %+.3f)\n",
            P_main + sum(values(thrust_at)), sum(values(thrust_at)))
        @printf("  MEASURED S_axial[%d] : %+9.3f N\n", n_seg, Sax[n_seg])
        @printf("  |measured − main|    = %.3f N\n", abs(Sax[n_seg] - P_main))
        @printf("  |measured − all|     = %.3f N\n",
            abs(Sax[n_seg] - (P_main + sum(values(thrust_at)))))
        @printf("  bridle total=%.3f N  cosθ=%.4f  W_top=%.3f N\n", T_bridle_tot, cθ, W_r(Nr))
    end
end

@printf("\n── predicted step just below each rotor ring ──\n")
for r in sort(collect(keys(thrust_at)); rev=true)
    if r - 1 >= 1
        @printf("  S[%d] − S[%d] should be F(%d) − W(%d) = %+9.3f N; measured %+9.3f N\n",
            r - 1, r, r, r, thrust_at[r] - W_r(r), S[r - 1] - S[r])
    end
end
println("=== done ===")
