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
include("catenary.jl")
include("dynamics.jl")
include("structural_safety.jl")
include("ring_element_analysis.jl")
include("lift_kite.jl")
include("sim_frame.jl")
include("visualization.jl")
include("trpt_optimization.jl")
include("trpt_axial_profiles.jl")
include("ring_spacing.jl")
include("bem.jl")
include("objective_v5.jl")
include("economics.jl")

export SystemParams, GeometrySpec, MaterialSpec, AeroSpec, ControlSpec, BackLineSpec
export params_10kw, params_50kw, params_v5_10kw, params_v5_50kw, params_v5_safe_10kw
export mass_scale
export cp_at_tsr, ct_at_tsr, tether_drag_force, TETHER_DRAG_CD
export wind_at_altitude, hub_altitude, steady_wind, wind_ramp, gust_event, turbulent_wind
export AbstractNode, RingNode, RopeNode, BearingNode, SkyAnchorNode, HubVertexNode, KiteTurbineSystem
export shaft_perp_basis, attachment_point, rope_helix_pos
export build_kite_turbine_system, build_kite_turbine_system_v5, state_size
export compute_rope_forces!, compute_ring_forces!
export multibody_ode!
export settle_to_equilibrium, simulate
export set_orbital_velocities!, orbital_damp_rope_velocities!
export ring_safety_frame, ring_element_analysis, analyse_ring, TETHER_SWL, FOS_DESIGN, DO_SCALE, E_CFRP,
       G_CFRP, σ_CFRP_COMPR, tube_props, RingElementFrame, BeamResult
export SimFrame, SimPeaks, capture_frame, capture_peaks
export build_dashboard

# Catenary model
export catenary_forces, solve_catenary_a, dyneema_weight_Npm

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

# TRPT v5: BEM-coupled rotor radius (n_lines drives rotor sizing via BEM.rotor_radius_for_power)
export BEM
export TRPTDesignV5
export search_bounds_v5, design_from_vector_v5, objective_v5, evaluate_design_v5

# Lift device types and analysis
export LiftDevice, SingleKiteParams, StackedKitesParams, RotaryLifterParams
export single_kite_default, single_kite_sized, stacked_kites_default, rotary_lifter_default
export lift_force_steady, stack_tension_profile, topmost_kite_static_load
export tension_sensitivity, tension_cv, tension_cv_reduction
export required_kite_area, hub_lift_required, lift_margin, lift_area_vs_power
export autogyro_lift_required, autogyro_radius_for_lift

# Economics
export Economics, CostModel, default_cost_model_2026, compute_capital_cost,
       compute_lcoe, compute_carbon, competitor_comparison,
       compute_cost_breakdown, compute_mass_breakdown,
       compute_annual_energy, compute_annual_revenue

include("simulation.jl")
end
