using KiteTurbineDynamics, LinearAlgebra

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
ld = rotary_lifter_default()

# Let's check the lift force magnitude at 11 m/s wind
v_wind = 11.0
_, T_lift, elev = KiteTurbineDynamics.lift_force_steady(ld, p.rho, v_wind)

println("Wind: ", v_wind, " m/s")
println("Rotary Lifter Tension: ", T_lift, " N")
println("Rotary Lifter Elevation: ", elev, " deg")

# Calculate weight of the whole TRPT system to see what it's lifting
m_rotor = p.n_blades * p.m_blade
m_rings = p.n_rings * p.m_ring
m_rope = 0.0 # Will approximate
for ss in sys.sub_segs
    # length * density * area
    m_rope += ss.length_0 * KiteTurbineDynamics.DYNEEMA_DENSITY * π * (ss.diameter/2)^2
end
m_bearing = sys.nodes[sys.bearing_id].mass
m_sky = sys.nodes[sys.sky_anchor_id].mass

total_mass = m_rotor + m_rings + m_rope + m_bearing + m_sky
total_weight = total_mass * 9.81

println("Total System Mass: ", total_mass, " kg")
println("Total System Weight: ", total_weight, " N")

# What happens in the furl scenario?
# In furl, the pitch is boosted. Let's see the force.
base_boost = 1.5 # 1.5x at end of phase 1
ld_furl = RotaryLifterParams(
    ld.rotor_radius,
    ld.hub_radius,
    ld.n_blades,
    ld.blade_chord,
    ld.CL_blade * base_boost,
    ld.CD_blade,
    ld.omega_fixed,
    ld.line_length,
    ld.line_EA,
    ld.m_lifter,
)

_, T_lift_furl, elev_furl = KiteTurbineDynamics.lift_force_steady(ld_furl, p.rho, v_wind)
println("\nFURL PITCH BOOST (1.5x):")
println("Rotary Lifter Tension: ", T_lift_furl, " N")
println("Rotary Lifter Elevation: ", elev_furl, " deg")
