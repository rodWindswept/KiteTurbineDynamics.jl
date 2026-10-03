#!/usr/bin/env julia
# scratch/hermes_star_test4.jl — meshscatter vs scatter at the extreme points
using CairoMakie

sw   = [26.15, 0.0, 15.10]   # sky anchor (control: scatter renders here)
ga   = [27.28, 0.0, 0.0]     # ground anchor (scatter failed here)
kite = [34.71, 0.0, 38.59]   # kite (scatter failed here)

fig = Figure(size=(900, 700))
ax = Axis3(fig[1, 1]; title="test 4 — meshscatter vs scatter", xlabel="x", ylabel="y", zlabel="z")
lines!(ax, [sw[1], ga[1]], [sw[2], ga[2]], [sw[3], ga[3]]; color=:grey40, linewidth=1.5)
lines!(ax, [sw[1], kite[1]], [sw[2], kite[2]], [sw[3], kite[3]]; color=:deepskyblue, linewidth=1.5)

# screen-space scatter markers (known-missing at these coords)
scatter!(ax, [kite[1]], [kite[2]], [kite[3]]; color=:red, marker=:star5, markersize=24)
scatter!(ax, [sw[1]], [sw[2]], [sw[3]]; color=:blue, markersize=12)   # control

# 3D-native meshes
meshscatter!(ax, [kite[1]], [kite[2]], [kite[3]];
             marker=Sphere(Point3f(0), 0.8f0), color=:green)
meshscatter!(ax, [ga[1]], [ga[2]], [ga[3]];
             marker=Sphere(Point3f(0), 0.5f0), color=:grey40)
meshscatter!(ax, [sw[1]], [sw[2]], [sw[3]];
             marker=Sphere(Point3f(0), 0.5f0), color=:orange)

limits!(ax, -5.0, 44.0, -20.0, 20.0, 0.0, 44.0)
ax.aspect = :data
save("scratch/star_test4.png", fig)
println("saved star_test4.png")
