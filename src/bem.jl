module BEM

const ρ_AIR = 1.225  # kg/m³

function cp_bem(n_lines::Int)::Float64
    # Prandtl tip-loss approximation: more blades reduce tip vortex losses
    f_tip = 1.0 - exp(-n_lines / 2.0)
    return clamp((16.0 / 27.0) * f_tip * 0.85, 0.15, 0.55)
end

function rotor_radius_for_power(power_W::Float64, v_rated::Float64, n_lines::Int)::Float64
    Cp = cp_bem(n_lines)
    # P = Cp · ½ρ·π·r²·v³  →  r = √(P / (Cp·½ρ·π·v³))
    return sqrt(max(power_W / (Cp * 0.5 * ρ_AIR * π * v_rated^3), 1e-4))
end

end  # module BEM
