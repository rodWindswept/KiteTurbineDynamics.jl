#!/usr/bin/env julia
# scratch/hermes_star_test.jl — isolate 3D marker/line rendering at the exact
# sky-anchor / ground-anchor / kite coordinates from island 3.
using CairoMakie

sw   = [26.15, 0.0, 15.10]   # sky anchor
ga   = [27.28, 0.0, 0.0]     # ground anchor
kite = [34.71, 0.0, 38.59]   # kite

# ── test 1: autoscale only (box clings to the data) ─────────────────────────
fig = Figure(size=(900, 700))
ax = Axis3(fig[1, 1]; title="test 1 — autoscale", xlabel="x", ylabel="y", zlabel="z")
lines!(ax, [sw[1], ga[1]], [sw[2], ga[2]], [sw[3], ga[3]]; color=:grey40, linewidth=1.5)
scatter!(ax, [ga[1]], [ga[2]], [ga[3]]; color=:grey40, marker=:diamond, markersize=16,
         strokewidth=1, strokecolor=:white)
lines!(ax, [sw[1], kite[1]], [sw[2], kite[2]], [sw[3], kite[3]]; color=:deepskyblue, linewidth=1.5)
scatter!(ax, [kite[1]], [kite[2]], [kite[3]]; color=:deepskyblue, marker=:star5,
         markersize=20, strokewidth=1.2, strokecolor=:white)
scatter!(ax, [sw[1]], [sw[2]], [sw[3]]; color=:deepskyblue, markersize=12)
ax.aspect = :data
save("scratch/star_test1.png", fig)

# ── test 2: explicit limits with headroom ───────────────────────────────────
fig2 = Figure(size=(900, 700))
ax2 = Axis3(fig2[1, 1]; title="test 2 — limits with headroom", xlabel="x", ylabel="y", zlabel="z")
lines!(ax2, [sw[1], ga[1]], [sw[2], ga[2]], [sw[3], ga[3]]; color=:grey40, linewidth=1.5)
scatter!(ax2, [ga[1]], [ga[2]], [ga[3]]; color=:grey40, marker=:diamond, markersize=16,
         strokewidth=1, strokecolor=:white)
lines!(ax2, [sw[1], kite[1]], [sw[2], kite[2]], [sw[3], kite[3]]; color=:deepskyblue, linewidth=1.5)
scatter!(ax2, [kite[1]], [kite[2]], [kite[3]]; color=:deepskyblue, marker=:star5,
         markersize=20, strokewidth=1.2, strokecolor=:white)
scatter!(ax2, [sw[1]], [sw[2]], [sw[3]]; color=:deepskyblue, markersize=12)
limits!(ax2, -5.0, 44.0, -20.0, 20.0, 0.0, 44.0)
ax2.aspect = :data
save("scratch/star_test2.png", fig2)

# ── test 3: marker-type sweep at the kite position (does :star5 → :circle help?) ─
fig3 = Figure(size=(900, 700))
ax3 = Axis3(fig3[1, 1]; title="test 3 — marker types", xlabel="x", ylabel="y", zlabel="z")
# offset copies so all render at once, same-ish height
pts = [kite, kite .+ [0.0, 3.0, 0.0], kite .+ [0.0, -3.0, 0.0]]
scatter!(ax3, [pts[1][1]], [pts[1][2]], [pts[1][3]]; color=:red,    marker=:star5,  markersize=22)
scatter!(ax3, [pts[2][1]], [pts[2][2]], [pts[2][3]]; color=:green,  marker=:circle, markersize=22)
scatter!(ax3, [pts[3][1]], [pts[3][2]], [pts[3][3]]; color=:orange, marker=:diamond, markersize=22)
lines!(ax3, [sw[1], kite[1]], [sw[2], kite[2]], [sw[3], kite[3]]; color=:deepskyblue, linewidth=1.5)
limits!(ax3, -5.0, 44.0, -20.0, 20.0, 0.0, 44.0)
ax3.aspect = :data
save("scratch/star_test3.png", fig3)

println("saved 3 test figures")
