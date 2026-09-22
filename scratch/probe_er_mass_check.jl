# scratch/probe_er_mass_check.jl
#
# Verifies the expansion-rotor mass bookkeeping claim for a candidate:
#   - expansion blade translational mass (expansion_blade_mass)
#   - expansion rotor inertia (expansion_rotor_inertia) as added to I_z
#   - the ring node's actual translational mass_node and inertia_z
# Prints per expansion rotor: ring index, radii, blade mass, inertia; then the
# RingNode masses/inertias for the expansion rings vs neighbours.
#
# Usage: julia --project=. scratch/probe_er_mass_check.jl <island_dir>

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const ISLAND = length(ARGS) >= 1 ? ARGS[1] : "island_1"
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

@printf("=== %s: %d expansion rotors ===\n", ISLAND, length(sys.expansion_rotors))
for er in sys.expansion_rotors
    span = er.blade_tip_radius - er.blade_hub_radius
    bm = KiteTurbineDynamics.expansion_blade_mass(span, er.n_blades)
    J = KiteTurbineDynamics.expansion_rotor_inertia(er, er.blade_tip_radius)
    @printf("ring %d: n_blades=%d  r_hub=%.3f r_tip=%.3f span=%.3f m\n",
        er.ring_idx, er.n_blades, er.blade_hub_radius, er.blade_tip_radius, span)
    @printf("   er.mass = %.3f kg   blade mass (span law) = %.3f kg   rotor inertia J = %.3f kg m2\n",
        er.mass, bm, J)
end
println("── ring nodes ──")
for s in 1:sys.n_ring
    gid = sys.ring_ids[s]
    node = sys.nodes[gid]::RingNode
    @printf("ring %2d: mass=%.4f kg  inertia_z=%.4f kg m2  radius=%.3f\n",
        s, node.mass, node.inertia_z, node.radius)
end
println("=== done ===")
