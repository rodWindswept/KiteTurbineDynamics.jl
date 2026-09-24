using LinearAlgebra, Printf

# Let's inspect the trim balance:
# Trim line length: 25 m
# Elevation: 55 deg
theta = deg2rad(55.0)
u_trim = [cos(theta), 0.0, sin(theta)]
L0 = 25.0
T_ref = 254.2
m_kite = 5.0
g = [0.0, 0.0, -9.81]

# In trim:
# T_line * (-u_trim) + F_aero + m_kite * g = 0
# => F_aero_eq = T_ref * u_trim - m_kite * g
F_aero_eq = T_ref .* u_trim .- m_kite .* g
println("F_aero_eq = ", F_aero_eq)

# Aerodynamic restoring force:
# If the relative position r = P_kite - P_sa deviates from r_eq = L0 * u_trim:
# A trimmed kite has a restoring force toward the trim vector.
# Aerodynamic stiffness k_trim ~ T_ref / L0:
k_trim = T_ref / L0
println("k_trim (N/m) = ", k_trim)

# Characteristic natural period of kite pendulum:
# omega_n = sqrt(k_trim / m_kite)
omega_n = sqrt(k_trim / m_kite)
period = 2*pi / omega_n
println(@sprintf("omega_n = %.2f rad/s, Period = %.2f s", omega_n, period))

# Damping for critical damping of kite pendulum mode:
c_crit = 2 * sqrt(k_trim * m_kite)
println(@sprintf("c_crit = %.2f N*s/m", c_crit))
