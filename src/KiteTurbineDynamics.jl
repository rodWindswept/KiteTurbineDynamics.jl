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
export ring_safety_frame, RING_SWL, TETHER_SWL
export build_dashboard

end
