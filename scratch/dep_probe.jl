using Pkg
Pkg.activate(".julia_depot/tethers_env")
Pkg.develop(path=".julia_depot/Tethers.jl")
Pkg.resolve()
Pkg.instantiate()
man = Pkg.dependencies()
names = sort([(v.name, string(v.version)) for (k,v) in man if v.version !== nothing])
println("TOTAL_PACKAGES=", length(names))
for (n,v) in names
    println(n, " ", v)
end
