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

# Lift device types and analysis
export LiftDevice, SingleKiteParams, StackedKitesParams, RotaryLifterParams
export single_kite_default, single_kite_sized, stacked_kites_default, rotary_lifter_default
export lift_force_steady, stack_tension_profile, topmost_kite_static_load
export tension_sensitivity, tension_cv, tension_cv_reduction
export required_kite_area, hub_lift_required, lift_margin, lift_area_vs_power

end
