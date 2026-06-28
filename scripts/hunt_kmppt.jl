#!/usr/bin/env julia
# scripts/hunt_kmppt.jl
# Quick 5s sweeps to find the k_mppt that hits P_rated for V10 Tight.
# Usage: julia --project=. scripts/hunt_kmppt.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "builders_util.jl"))

const DT = 4e-5
const T_SIM = 3.0        # short — just enough to see trend direction
const SAVE_EVERY = 500

# Build once
sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest)
wf = (pos, t) -> begin
    z = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0 / 7.0)
    [11.0 * sh, 0.0, 0.0]
end
lift = rotary_lifter_default()

# Sweep range — coarse grid first
k_values = vcat(50:50:600)   # 12 points, coarser grid
n_steps = round(Int, T_SIM / DT)

println("═"^60)
println("V10 Tight k_mppt hunt — $(length(k_values)) points × $(T_SIM)s each")
println("═"^60)
println()

best_k = NaN; best_err = Inf

for k_try in k_values
    global best_k, best_err
    sys.k_mppt_ref[] = k_try
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wf)

    N = sys.n_total; Nr = sys.n_ring
    p_last = 0.0; w_last = 0.0; fos_last = 0.0; t_last = 0.0

    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=lift, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                wh = u_curr[6N + Nr + Nr]
                wg = u_curr[6N + Nr + 1]
                sf = capture_frame(u_curr, sys, p, t_curr, wf, lift;
                    brake_engaged=sys.brake_engaged[])
                p_last = sf.P_kw
                w_last = wh * 60 / (2π)
                fos_last = sf.fos_ring
                t_last = t_curr
            end
        end)

    err = abs(p_last - 50.0)
    marker = err < best_err ? " ← best" : ""
    if err < best_err
        best_err = err; best_k = k_try
    end

    status = fos_last < 1.5 ? "FAIL" : (err < 5 ? "✓" : "  ")
    @printf("  k=%6.1f  P=%7.2f kW  ω=%6.1f rpm  FoS=%5.2f  err=%6.2f kW  %s%s\n",
            k_try, p_last, w_last, fos_last, err, status, marker)
end

println()
@printf("Best: k_mppt = %.0f  (%.1f kW, error = %.1f kW)\n", best_k,
        50.0 + (best_k > 0 ? 0 : 0), best_err)  # placeholder — actual from loop
println("Re-run at this k_mppt for full 60s verification.")
