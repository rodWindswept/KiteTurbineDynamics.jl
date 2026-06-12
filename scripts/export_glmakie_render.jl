# scripts/export_glmakie_render.jl
using Pkg;
Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, GLMakie, LinearAlgebra

println("Loading 10 kW system parameters...")
p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
ld = rotary_lifter_default()

println("Settling system to operational state at V=11 m/s, beta=30°...")
wind_fn = (pos, t) -> begin
    z = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0/7.0)
    [p.v_wind_ref * sh, 0.0, 0.0]
end
u_start = settle_to_operational_state(sys, u0, p, 9.5; lift_device=ld, wind_fn=wind_fn)

println("Building visualizer dashboard...")
fig, config_changed = build_dashboard(
    sys,
    p,
    [u_start];
    times=[0.0],
    u_settled=u_start,
    wind_fn=wind_fn,
    config_name="Canonical 5-line",
)

# Set background to white for report integration
println("Modifying figure aesthetics for white-background report export...")
fig.scene.backgroundcolor[] = to_color(:white)

# Save the rendering
out_path = joinpath(dirname(@__DIR__), "figures", "fig_trpt_installed_geometry.png")
println("Saving 3D scene rendering to $out_path...")
save(out_path, fig)
println("GLMakie rendering successfully saved!")
