#!/usr/bin/env julia --project=.
# av_probe_cp_provenance.jl — TEMPORARY. Not to be committed.
# Question: on the EVALUATED path, what does the aero correction actually key on,
# and what are the two Cp values?  Settles the sign of the sizing-vs-ODE gap.
using KiteTurbineDynamics
const KTD = KiteTurbineDynamics
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

cpbem = KTD.BEM.cp_bem

x = seed_genome(5.0)
println("seed genome length          = ", length(x))
println("x[4]  n_lines gene          = ", x[4], "  -> round ", round(Int, x[4]))
println("x[6]  rotor_count gene      = ", x[6])
println("x[9]  blade_scale_top       = ", x[9])
println("x[10] blade_scale_bottom    = ", x[10])

p = params_5kw_188()
println("\np (SystemParams) tether_length = ", p.tether_length, "  v_wind_ref = ", p.v_wind_ref,
        "  h_ref = ", p.h_ref)
println("has p.tsr? ", hasproperty(p, :tsr))

dec = KTD.design_from_vector_v10(copy(x), PROFILE_ELLIPTICAL, p;
    power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)

println("\ndecoded: rotors = ", length(dec.rotors), "   n_rings = ", dec.n_rings,
        "   radii = ", dec.radii)
println("dec.design fields: ", fieldnames(typeof(dec.design)))
n_lines_dec = try
    dec.design.n_lines
catch
    nothing
end
println("dec.design.n_lines = ", n_lines_dec)
println("dec.rotors[1] fields: ", fieldnames(typeof(dec.rotors[1])))
for (i, r) in enumerate(dec.rotors)
    println("   rotor ", i, ": ", r)
end

λ = 4.1
println("\nλ (sizing default tsr)      = ", λ)
println("cp_at_tsr(λ)                = ", KTD.cp_at_tsr(λ))
for n in unique([n_lines_dec === nothing ? 6 : n_lines_dec, 3, 4, 5, 6, 8])
    cb = cpbem(Int(n), λ)
    println("cp_bem(", Int(n), ", λ)              = ", round(cb; digits = 6),
            "   ratio cp_bem/cp_at_tsr = ", round(cb / KTD.cp_at_tsr(λ); digits = 6))
end
println("\nsizing reads cp_bem(n_lines=", n_lines_dec, ") = ",
        n_lines_dec === nothing ? "?" : cpbem(Int(n_lines_dec), λ),
        "   (bem.jl:179, annulus_span_for_power)")
println("the ODE flies cp_at_tsr(λ)                = ", KTD.cp_at_tsr(λ),
        "   (sim_frame.jl:157, ring_forces.jl:221, initialization.jl:1032/:1052)")
