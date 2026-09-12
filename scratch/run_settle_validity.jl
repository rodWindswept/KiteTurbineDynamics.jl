using Test, KiteTurbineDynamics, LinearAlgebra
const TDIR = joinpath(dirname(@__DIR__), "test")
include(joinpath(TDIR, "test_settle_validity.jl"))
