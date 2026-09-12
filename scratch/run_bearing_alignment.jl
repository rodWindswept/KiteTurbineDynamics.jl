using Test, KiteTurbineDynamics
using KiteTurbineDynamics: params_10kw, build_kite_turbine_system, rotary_lifter_default,
    shaft_perp_basis, attachment_point, settle_to_operational_state, get_segment_tension
const TDIR = joinpath(dirname(@__DIR__), "test")
@testset "isolated" begin
    include(joinpath(TDIR, "test_bearing_alignment.jl"))
end
