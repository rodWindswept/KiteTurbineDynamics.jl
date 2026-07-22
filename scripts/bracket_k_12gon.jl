#!/usr/bin/env julia
# scripts/bracket_k_12gon.jl — k_mppt bracketing for corrected 12-gon geometry
# Find sensible k range before committing to sweep grids.
# The triangle system used k∈{2..14}; 12-gon needs much higher k (k≈62 per dynamic_verification.txt).

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const DT    = ControlMapHunt.DT
const WIND  = 11.0
const SIM_S = 30.0
const SP    = SpokeParams(enabled=true)

# Build 12-gon with corrected builder
function build_12gon(blade_scale::Float64)
    fn = ControlMapHunt.v10_tight_builder(blade_scale=blade_scale)
    return Base.invokelatest(fn)
end

function test_k(blade, k, label)
    sys, u0, p, desc, design = build_12gon(blade)
    sys.k_mppt_ref[] = k
    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [WIND * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; wind_fn=wf)
    n_steps = round(Int, SIM_S / DT)
    local result = (0.0, 0.0, Inf)
    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=nothing, lin_damp=0.05, spoke=SP,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing;
                    brake_engaged=sys.brake_engaged[])
                ω = ef.base.omega_hub * 60 / (2π)
                airborne = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]
                    (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
                end
                fos = isempty(airborne) ? Inf : minimum(airborne)
                result = (ef.base.P_kw, ω, fos)
            end
        end)
    @printf("%s  blade=%.2f k=%.0f  P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", label, blade, k, result[1], result[2], result[3])
    return result
end

println("═════════════════════════════════════════════")
println("12-gon k_mppt bracketing — $(WIND) m/s")
println("═════════════════════════════════════════════")

# Test at blade_scale=1.0 (full scale winner) with progressively higher k
blade = 1.0
k_values = [2, 4, 8, 16, 32, 64, 128, 256]
for k in k_values
    test_k(blade, k, "12gon")
end

# Also test at blade_scale=0.85 (sweep starting point) 
println("\n--- blade_scale=0.85 ---")
blade = 0.85
k_values = [2, 4, 8, 16, 32, 64, 128]
for k in k_values
    test_k(blade, k, "12gon-085")
end

println("\nDone. Sensible k bracket found where P crosses 50 kW.")
