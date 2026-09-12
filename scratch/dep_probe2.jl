using Pkg
Pkg.activate(".julia_depot/tethers_env2"; io=devnull)
Pkg.develop(path=".julia_depot/Tethers.jl"; io=devnull)
Pkg.resolve(io=devnull)
man = Pkg.dependencies()
names = sort([v.name for (k,v) in man if v.version !== nothing])
println("TOTAL=", length(names))
println(join(names, ", "))
