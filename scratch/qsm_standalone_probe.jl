using Pkg
Pkg.activate(".julia_depot/qsm_only_env"; io=devnull)
Pkg.add(["StaticArrays", "ADTypes", "NonlinearSolve", "Parameters", "MAT"]; io=devnull)

using MAT
using LinearAlgebra, StaticArrays
module QSMStandalone
using LinearAlgebra, StaticArrays, ADTypes, NonlinearSolve, MAT, Parameters
include(joinpath(pwd(), ".julia_depot", "Tethers.jl", "src", "Tether_quasisteady.jl"))
end

using .QSMStandalone: QuasiSteady
using .QSMStandalone.QuasiSteady: StaticSettings, Tether, init!, step!, get_initial_conditions
import .QSMStandalone.QuasiSteady as QSM

loaded = [string(k.name) for k in keys(Base.loaded_modules)]
println("ModelingToolkit loaded? ", "ModelingToolkit" in loaded)
println("Symbolics loaded?       ", "Symbolics" in loaded)

data = joinpath(pwd(), ".julia_depot", "Tethers.jl", "test", "data")
sv, kp, kv, wv, tl, se = get_initial_conditions(joinpath(data, "input_basic_test.mat"))
Ns = size(wv, 2)
buffers = [zeros(3, Ns) for _ in 1:5]
param = (kite_pos=kp, kite_vel=kv, wind_vel=wv, tether_length=tl, settings=se,
         buffers=buffers, segments=Ns+1, return_result=true)
Fobj, T0, pj, p0 = QSM.res!(zeros(3), sv, param)
ref = matread(joinpath(data, "basic_test_results.mat"))
println("||p0 - p0_ref|| = ", norm(p0 .- vec(ref["p0"])))
println("||T0 - T0_ref|| = ", norm(T0 .- vec(ref["T0"])))

se2 = StaticSettings(segments=8, elevation=70.0, l_tether=50.0)
te = Tether(se2)
init!(te)
println("init! force_gnd = ", round(te.force_gnd, digits=3), " N, |p0| = ", round(norm(te.p0), digits=3), " m")
step!(te, MVector{3}(te.p0), MVector{3}(0.0, 0.0, 0.0))
println("step! force_gnd = ", round(te.force_gnd, digits=3), " N")
