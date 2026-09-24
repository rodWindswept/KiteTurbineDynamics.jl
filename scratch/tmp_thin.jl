using KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))
p_thin = override_params(params_daisy(); tether_diameter=0.00025)
p = params_at_length(p_thin, 18.8, 5.0)
d = p.tether_diameter
EA = p.e_modulus * pi * (d/2)^2
println("  requested diameter      = 0.00025 m (0.25 mm)")
println("  params_daisy diameter   = ", params_daisy().tether_diameter, " m")
println("  mass_scale factor       = ", p.tether_diameter / params_daisy().tether_diameter)
println("  BUILT diameter          = ", round(d*1000; digits=4), " mm")
println("  line EA                 = ", round(EA; digits=1), " N")
println("  break strain            = ", KiteTurbineDynamics.ROPE_BREAK_STRAIN)
println(
    "  tension at break strain = ",
    round(EA * KiteTurbineDynamics.ROPE_BREAK_STRAIN; digits=1),
    " N/line",
)
