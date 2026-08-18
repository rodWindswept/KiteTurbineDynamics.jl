#!/usr/bin/env julia --project=.
#= anchor_april29_compare.jl — model-vs-measured for the TRPT-5 mast rig.
Sweeps wind 3.25:0.5:8.75 m/s, settles the rig with the 118 N bucket lift,
runs a window, records P_gen at the ground (PTO). Measured bins come
from scripts/results/april29_anchor.csv (wind-binned plateau ~220 W).
Writes scripts/results/april29_model_curve.csv.

2026-08-16 fix package (see DECISIONS [2026-08-16]):
  - dt = 4e-6 (smoke-verified 2026-08-16: 2 mm rope mode ω·dt ≈ 10 with the
    ζ=0.05 sub-segment damping remains stable; dt=4e-5 was unstable (ω·dt ≈
    103), tripping the rope-break detector at step 7 — the "13.5 W at every
    wind" wind-blind artifact. Fall back to 2e-6 if any wind trips.)
  - Generator load = MEASURED τ(ω) table (12 knots = 30-s steady-block
    means, Quarq power ÷ controller rpm, 22.65→13.11 N·m over
    9.75→12.86 rad/s; flat below/above; the VESC "Too Slow 4 gen" no-regen
    floor at 2.5 rad/s).  set_generator_load!(GeneratorLoadMode(:table,
    omega_pts, tau_pts, 45.0, 2.5)).  Bypasses
    k_mppt and the tau_max_safe clamp (2.25 N·m at p_rated=300 W — ~9×
    below the measured load).  k_mppt_ref = 0 so the semi-implicit MPPT
    block in run_canonical_sim! stays off.
  - Wind shear: rotor at ≈1.65 m sees 0.856× the 5 m anemometer wind
    (Hellmann α=0.14); the model runs at the shear-corrected wind.
  - Warm start: spin to ~6 rad/s (the expansion rotor's provisional post-stall
    drag blocks self-start from low ω — EXP_CD_STALL, marked provisional in
    expansion_rotor.jl) + orbital rope-node velocities.  omega_floor 2.5 rad/s:
    below it (incl. reversal) τ=0 — the VESC "Too Slow 4 gen" behaviour;
    prevents the reversed-ring lock seen with the earlier cap-only load.
=#

using KiteTurbineDynamics, Printf, Statistics
include(joinpath(@__DIR__, "build_april29_rig.jl"))

const P_SET  = 225.0     # W — measured plateau (Quarq ÷ rpm, 216-228 W)
const TAU_CAP = 45.0     # N·m — startup cap, well above operating torque

# Measured generator torque table — REBUILT 2026-08-16 (pass-2 audit):
# the 12 knots are 30-s steady-block means (con rpm > 60) from the merged
# workbook — wind 5.57-6.94 m/s, P 168-267 W, tau = P/omega.  The earlier
# low-omega knots (27.5 @ 3.5 rad/s etc.) came from startup-transient rows
# and are dropped; below 9.75 rad/s the table is flat (22.65 N·m) and the
# VESC no-regen floor (omega_floor = 2.5) still governs the start.
const TAU_OMEGA = [9.75, 10.62, 10.71, 10.78, 11.09, 11.21, 11.34, 11.67, 11.78, 11.94, 12.25, 12.86]
const TAU_TABLE  = [22.65, 19.35, 20.06, 17.91, 23.73, 23.85, 16.86, 20.16, 19.17, 21.41, 17.40, 13.11]

# Wind shear (Rod 2026-08-16): the anemometer sat on a ~5 m mast, the rotor
# hub at ≈1.65 m (9.5 m chain at 10°).  Hellmann α=0.14: v_rotor = 0.856·v_meas
# (power −37%).  The model runs the rotor at the shear-corrected wind; the
# CSV x-axis stays the measured wind.
const H_ROTOR = 9.5 * sind(10.0)   # ≈ 1.65 m
const H_ANEM  = 5.0
const SHEAR_FACTOR = (H_ROTOR / H_ANEM)^0.14

function run_one(v::Float64; window_s::Float64=20.0, dt::Float64=4e-6)
    sys, u0, pc, lifter = build_april29_rig()
    set_generator_load!(GeneratorLoadMode(; mode=:table, omega_pts=TAU_OMEGA,
        tau_pts=TAU_TABLE, tau_cap=TAU_CAP, omega_floor=2.5))
    v_eff = v * SHEAR_FACTOR
    wind_fn(r, t) = [v_eff, 0.0, 0.0]
    u = copy(u0)
    N = sys.n_total
    Nr = sys.n_ring
    for ri in 1:Nr
        u[6N + Nr + ri] = 6.0
    end
    KiteTurbineDynamics.set_orbital_velocities!(u, sys, pc)
    sys.k_mppt_ref[] = 0.0
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
    Ps = Float64[]
    Ws = Float64[]
    for chunk in 1:round(Int, window_s / 5.0)
        run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0 / dt), dt;
            lift_device=lifter, lin_damp=0.05)
        t = chunk * 5.0
        w_gnd = u[6N + Nr + gnd_ri]
        tau_gen, _ = get_generator_torque(u, sys, pc, t, wind_fn;
            brake_engaged=sys.brake_engaged[])
        push!(Ps, tau_gen * max(w_gnd, 0.0))
        push!(Ws, w_gnd)
        sys.any_broken[] && break
    end
    return mean(Ps[max(1, end - 4):end]), Ws[end]
end

function main()
    out = joinpath(@__DIR__, "results", "april29_model_curve.csv")
    open(out, "w") do io
        write(io, "wind_ms,P_model_W,w_gnd_rads\n")
        for v in 3.25:0.5:8.75
            P, wg = run_one(v)
            @printf("  v=%4.2f  P_model=%7.1f W  w_gnd=%5.2f rad/s\n", v, P, wg)
            write(io, "$(v),$(P),$(wg)\n")
            flush(io)
        end
    end
    println("wrote ", out)
end
main()
