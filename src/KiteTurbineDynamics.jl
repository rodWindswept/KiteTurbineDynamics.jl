module KiteTurbineDynamics

using LinearAlgebra, Printf, Statistics

include("parameters.jl")
include("aerodynamics.jl")
include("wind_profile.jl")
include("types.jl")
include("geometry.jl")
include("initialization.jl")
include("rope_forces.jl")
include("ring_forces.jl")
include("dynamics.jl")
include("structural_safety.jl")
include("lift_kite.jl")
include("visualization.jl")
include("trpt_optimization.jl")
include("trpt_axial_profiles.jl")
include("ring_spacing.jl")

export SystemParams, params_10kw, params_50kw
export cp_at_tsr, ct_at_tsr
export wind_at_altitude, hub_altitude, steady_wind, wind_ramp, gust_event, turbulent_wind
export AbstractNode, RingNode, RopeNode, KiteTurbineSystem
export shaft_perp_basis, attachment_point, rope_helix_pos
export build_kite_turbine_system, state_size
export compute_rope_forces!, compute_ring_forces!
export multibody_ode!
export settle_to_equilibrium, simulate
export set_orbital_velocities!, orbital_damp_rope_velocities!
export ring_safety_frame, TETHER_SWL, FOS_DESIGN, DO_SCALE, E_CFRP
export build_dashboard

# TRPT sizing optimization (Item B2)
export BeamProfile, PROFILE_CIRCULAR, PROFILE_ELLIPTICAL, PROFILE_AIRFOIL
export BeamSpec, TRPTDesign, EvalResult
export beam_section_properties, ring_radii, segment_axial_lengths, beam_spec_at_ring
export evaluate_design, baseline_design, search_bounds, design_from_vector, objective
export peak_hub_thrust
export OPT_E_CFRP, OPT_RHO_CFRP, OPT_KNUCKLE_MASS_KG, OPT_V_PEAK, OPT_FOS_REQUIRED
export OPT_DESIGN_LOAD_FACTOR

# TRPT v2: enriched axial-profile family + 12-DoF search space (Phase A of cartography)
export AxialProfile, AXIAL_LINEAR, AXIAL_ELLIPTIC, AXIAL_PARABOLIC, AXIAL_TRUMPET, AXIAL_STRAIGHT_TAPER
export AXIAL_PROFILE_COUNT, axial_profile_name, axial_profile_from_index
export TRPTDesignV2, r_of_z, ring_z_positions
export search_bounds_v2, design_from_vector_v2, objective_v2, baseline_design_v2
export TRPT_V2_DIM

# TRPT v4: constant L/r ring spacing (replaces n_rings+taper_ratio with target_Lr+r_bottom)
export ring_spacing_v4
export TRPTDesignV4
export OPT_MAX_GROUND_RADIUS, TRPT_V4_DIM
export search_bounds_v4, design_from_vector_v4, objective_v4, baseline_design_v4

# Lift device types and analysis
export LiftDevice, SingleKiteParams, StackedKitesParams, RotaryLifterParams
export single_kite_default, single_kite_sized, stacked_kites_default, rotary_lifter_default
export lift_force_steady, stack_tension_profile, topmost_kite_static_load
export tension_sensitivity, tension_cv, tension_cv_reduction
export required_kite_area, hub_lift_required, lift_margin, lift_area_vs_power

include("simulation.jl")
end
