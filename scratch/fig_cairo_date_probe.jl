#!/usr/bin/env julia
# scratch/fig_cairo_date_probe.jl — figures seat diagnostic.
# Saves the same tiny CairoMakie PDF twice, ~65 s apart, to see whether
# cairo emits a wall-clock-dependent value outside /CreationDate.
# Run: scripts/ktd-julia scratch/fig_cairo_date_probe.jl
using CairoMakie
out = ARGS[1]
fig = Figure(size=(120, 80), backgroundcolor=RGBf(1, 1, 1))
ax = Axis(fig[1, 1]); hidedecorations!(ax); hidespines!(ax)
text!(ax, 0.5, 0.5; text="probe", align=(:center, :center))
save(joinpath(out, "p1.pdf"), fig)
println("p1 saved: ", time())
sleep(65)
save(joinpath(out, "p2.pdf"), fig)
println("p2 saved: ", time())
