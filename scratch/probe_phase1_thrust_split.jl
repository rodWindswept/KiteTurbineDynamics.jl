# scratch/probe_phase1_thrust_split.jl
#
# Item 4 multi-rotor remediation, Phase 1 evidence probe.
# Quantifies Fix 3 (every rotor's axial thrust in the settle) for a candidate:
#   - main-rotor disc thrust alone (the pre-fix `T_thrust`)
#   - each expansion rotor's axial thrust `Fa`, as the ODE computes it
#   - the resulting `T_top` and the axial preload `F_top` the settle will use
#   - the bridle preload cut `L0` (Fix 3 changes the operating strain)
# Build + `lift_chain_design` only: no settle, no ODE. Fast.
#
# Usage: julia --project=. scratch/probe_phase1_thrust_split.jl <island_dir> [omega_eq]

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const ISLAND = length(ARGS) >= 1 ? ARGS[1] : "island_1"
const OMEGA = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 13.7084
const RESDIR = joinpath(
    @__DIR__, "..", "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_physlift"
)
const CSV = joinpath(RESDIR, ISLAND, "best_vector.csv")

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
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p0.tether_diameter, base_params=p0, min_wall_m=2e-3,
    beam_sizing=sizing)
lift = lift_for(sys, pc)

hub_gid = sys.rotor.node_id
hub_pos = u0[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
d = KiteTurbineDynamics.lift_chain_design(sys, pc, lift, hub_pos; omega_eq=OMEGA)
d === nothing && error("lift_chain_design returned nothing")

# `pc` is the AUTHORITATIVE params for this machine (the settle and the gate use
# it).  `p0` is only the base seed and carries the default `n_lines = 6`, which
# would halve `T_bridle` and double `T_top`.
# Reconstruct the pre-fix main-rotor-only thrust with the same formula the code
# uses (initialization.jl `v_hub`/`λ`), so the delta is attributable to Fix 3.
β = pc.elevation_angle
v_hub = pc.v_wind_ref * sys.rotor.wind_factor
ω = OMEGA
λ = abs(ω) * sys.rotor.radius / max(v_hub, 1e-6)
T_main =
    0.5 * pc.rho * v_hub^2 * KiteTurbineDynamics.main_rotor_swept_area(sys) *
    KiteTurbineDynamics.ct_at_tsr(λ) * cos(β)^2

@printf(
    "=== %s  omega_eq=%.4f rad/s  v_wind_ref=%.3f m/s ===\n", ISLAND, OMEGA, pc.v_wind_ref
)
@printf("n_lines=%d rings=%d expansion_rotors=%d\n", pc.n_lines, sys.n_ring,
    length(sys.expansion_rotors))
@printf("\nmain-rotor disc thrust (pre-fix T_thrust) = %10.3f N\n", T_main)
for er in sys.expansion_rotors
    ring_gid = sys.ring_ids[er.ring_idx]
    r_nom = (sys.nodes[ring_gid]::RingNode).radius
    v_er = pc.v_wind_ref * er.wind_factor
    Fr, Fa, tau, _, _ = KiteTurbineDynamics.expansion_rotor_forces(
        er, pc.rho, v_er, abs(ω), rad2deg(β), r_nom, T_main, pc.n_lines
    )
    @printf(
        "  ring %2d  wind_factor=%.3f  r_nom=%.3f  F_axial=+%8.3f N  F_radial=%8.3f N (rim only)\n",
        er.ring_idx, er.wind_factor, r_nom, Fa, Fr
    )
end
@printf("\nT_thrust (post-fix, all rotors)           = %10.3f N\n", d.T_thrust)
@printf("  expansion contribution                  = %10.3f N  (%.1f %% of total)\n",
    d.T_thrust - T_main, 100.0 * (d.T_thrust - T_main) / max(d.T_thrust, 1e-9))
@printf("T_bridle (per line)                       = %10.3f N\n", d.T_bridle)
@printf("cosθ                                      = %10.4f\n", d.cosθ)
W_rotor = pc.n_blades * pc.m_blade * 9.81
T_top_pre = T_main + pc.n_lines * d.T_bridle * d.cosθ - W_rotor * sin(β)
@printf("T_top pre-fix  (main thrust only)         = %10.3f N\n", T_top_pre)
@printf("T_top post-fix (all rotors)               = %10.3f N\n", d.T_top)
@printf("  preload increase                        = %10.3f N  (%.1f %%)\n",
    d.T_top - T_top_pre, 100.0 * (d.T_top - T_top_pre) / max(abs(T_top_pre), 1e-9))
ea = KiteTurbineDynamics.BRIDLE_EA_DESIGN
@printf("bridle L0 pre-fix                         = %.6f m\n", d.gap / (1.0 + d.T_bridle / ea))
@printf("bridle L0 post-fix (same T_bridle)        = %.6f m  <- Fix 3 does not move L0\n",
    d.gap / (1.0 + d.T_bridle / ea))
@printf("bridle design gap                          = %.6f m\n", d.gap)
@printf("back_taut=%s  T_cyan=%.3f  T_back=%.3f\n", d.back_taut, d.T_cyan, d.T_back)
println("=== done ===")
