# sv_probe_floor.jl — the feasibility floor's numbers, and the Cp the decoder sizes with.
using KiteTurbineDynamics
const KTD = KiteTurbineDynamics
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))
include(joinpath(dirname(@__DIR__), "scripts", "ode_gate_v13.jl"))

const BEM = KTD.BEM

println("=== Cp values in the pipeline ===")
println("cp_at_tsr(4.1)      = ", cp_at_tsr(4.1))
for n in (3, 5)
    println("cp_bem($n, 4.1)      = ", BEM.cp_bem(n, 4.1))
end

p_scale = mass_scale(params_daisy(), 1.5, 5.0)
println("\n=== scaled-Daisy params (5 kW) ===")
println("p.cp = ", p_scale.cp, "   p.rho = ", p_scale.rho,
        "   v_wind_ref = ", p_scale.v_wind_ref, "   h_ref = ", p_scale.h_ref)

x = [parse(Float64, s) for s in split(strip(read(joinpath(dirname(@__DIR__), "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv"), String)), ",")]
d = decode_winner(x; L=18.8, KW=5.0)
sys, _u, _pc = KTD.build_system_from_v10(d.dec, 1.0, d.k_mp;
    tether_diameter=d.p.tether_diameter, base_params=d.p)

p = d.p
A_proj = KTD.betz_wind_normal_area(sys, p)
A_raw  = KTD.main_rotor_swept_area(sys)
v = 11.0
k = 0.5 * p.rho * v^3 / 1000.0
println("\n=== the betz block's own numbers (v_rated = ", v, ") ===")
println("winner A_raw  = ", A_raw)
println("winner A_proj = ", A_proj, "   (= ", round(100 * A_proj / A_raw, digits=2), "% of raw)")
println("ceiling_kW    = ", 0.593 * k * A_proj, "  (on A_proj)")
println("cp_floor_kW   = ", p.cp * k * A_proj, "  (on A_proj) ; bar = 0.8*p_floor_kw = 4.0")
println("cp_floor/bar  = ", round(100 * p.cp * k * A_proj / 4.0, digits=2), "%")
println("required A_proj for 4.0 kW = ", 4.0 / (p.cp * k))
println("=> required A_raw = ", 4.0 / (p.cp * k) / (A_proj / A_raw))
