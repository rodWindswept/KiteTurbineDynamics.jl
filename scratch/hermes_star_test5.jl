#!/usr/bin/env julia
# scratch/hermes_star_test5.jl — kitchen-sink: winner-like autoscale scene,
# print finallimits, magenta drop-line kite→floor to discriminate truncation.
using CairoMakie

sw   = [26.15, 0.0, 15.10]
ga   = [27.28, 0.0, 0.0]
kite = [34.71, 0.0, 38.59]

fig = Figure(size=(1000, 800))
ax = Axis3(fig[1, 1]; title="test 5 — autoscale (winner-like)", xlabel="x", ylabel="y", zlabel="z")
lines!(ax, [sw[1], kite[1]], [sw[2], kite[2]], [sw[3], kite[3]]; color=:deepskyblue, linewidth=1.2)
lines!(ax, [sw[1], ga[1]], [sw[2], ga[2]], [sw[3], ga[3]]; color=:grey40, linewidth=1.2)
# MAGENTA drop line: kite straight down to the floor
lines!(ax, [kite[1], kite[1]], [kite[2], kite[2]], [kite[3], 0.0]; color=:magenta, linewidth=2.0)
# MAGENTA drop for the backline target: sky anchor straight down to z=0
lines!(ax, [sw[1], sw[1]], [sw[2], sw[2]], [sw[3], 0.0]; color=:orange, linewidth=2.0)

kx, ky, kz = kite
ak = 1.4
lines!(ax, [kx - ak, kx + ak], [ky, ky], [kz, kz]; color=:deepskyblue, linewidth=1.6)
lines!(ax, [kx, kx], [ky - ak, ky + ak], [kz, kz]; color=:deepskyblue, linewidth=1.6)
lines!(ax, [kx, kx], [ky, ky], [kz - ak, kz + ak]; color=:deepskyblue, linewidth=1.6)

ag = 0.9
lines!(ax, [ga[1] - ag, ga[1] + ag], [ga[2], ga[2]], [ga[3], ga[3]]; color=:black, linewidth=2.0)
lines!(ax, [ga[1], ga[1]], [ga[2] - ag, ga[2] + ag], [ga[3], ga[3]]; color=:black, linewidth=2.0)
lines!(ax, [ga[1], ga[1]], [ga[2], ga[2]], [ga[3] - ag, ga[3] + ag]; color=:black, linewidth=2.0)

scatter!(ax, [sw[1]], [sw[2]], [sw[3]]; color=:deepskyblue, markersize=9)
scatter!(ax, [kx], [ky], [kz]; color=:red, marker=:star5, markersize=22)  # probe again

ax.aspect = :data
save("scratch/star_test5.png", fig)
println("finallimits after autoscale:")
l = ax.finallimits[]
println("  origin: ", l.origin, "   widths: ", l.widths)
println("saved star_test5.png")
