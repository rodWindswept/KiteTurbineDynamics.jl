#!/usr/bin/env julia --project=.
#= test_trpt_drag_torque_balance.jl — T3 acceptance test (2026-09-26).

The tether drag must reach the ring spin, and it must stay inside the steady-state
bound. A steady state balances torque: the rotor torque equals the load torque plus
the drag torque. A drag torque above the rotor torque would mean the wind drives the
machine, so the drag torque must stay below it. This test measures both.

THE MEASUREMENT. The rope kernel is called twice on the settled state:

  (1) the state as it is, with the real wind;
  (2) the same state with every node translational velocity zeroed and the wind set
      to zero.

In call (2) the relative flow is zero, so the drag is zero. The elastic tension term
depends on positions only, so it is identical in both calls and cancels. The rope
material damping depends on velocity, so it appears in the difference and rides along
with the drag. It is small, and the drag scales with the square of the speed while the
damping scales with the speed.

Baseline measured 2026-09-26 at commit 13a676a: the tether drag torque reads
-21.9 N.m against a rotor torque of 290.7 N.m, so 7.5 percent, at omega 13.452 rad/s
and a tip speed of 32.3 m/s. The full record is
docs/validation/2026-09-26-trpt-drag-torque-measurement.md.

Finding F11 predicts this baseline sits about 25 percent low, because the ring-end
sub-segments use the ring centre velocity. The identical drag torque is expected to
read 29 to 35 N.m once F11 is fixed. The bracket below holds both.
=#

using KiteTurbineDynamics, LinearAlgebra, Printf, Test

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "settle_case_builders.jl"))

const N_OP = 150_000          # 6 s of simulated settle, the horizon of the baseline

failures = String[]

sys, u0, pc, lift, wf = build_case(nothing, nothing)
N, Nr = sys.n_total, sys.n_ring

u = settle_to_operational_state(
    sys, u0, pc, 60.0; lift_device=lift, wind_fn=wf, n_op=N_OP
)
alpha = u[(6N + 1):(6N + Nr)]
omega = u[(6N + Nr + 1):(6N + 2Nr)]

function kernel_torques(u_state, wind_fn; zero_velocities::Bool=false)
    us = copy(u_state)
    if zero_velocities
        @views us[(3N + 1):(6N)] .= 0.0
    end
    f = [zeros(3) for _ in 1:N]
    tau = zeros(Nr)
    compute_rope_forces!(f, tau, us, alpha, sys, pc, wind_fn, 0.0)
    return tau
end

tau_state = kernel_torques(u, wf)
zero_wind = (pos, t) -> [0.0, 0.0, 0.0]
tau_still = kernel_torques(u, zero_wind; zero_velocities=true)
tau_drag = tau_state .- tau_still

# The same difference with the wind out of BOTH calls. The gap between the two is the
# wind's share of the rotational drag, which makes the isolation auditable.
tau_nowind = kernel_torques(u, zero_wind)
tau_drag_nowind = tau_nowind .- tau_still

f_ring = [zeros(3) for _ in 1:N]
tau_ring = zeros(Nr)
compute_ring_forces!(f_ring, tau_ring, u, omega, sys, pc, wf, 0.0)
tau_aero = tau_ring[Nr]
w = omega[1]
hub_r = (sys.nodes[sys.ring_ids[Nr]]::RingNode).radius

total_drag = sum(tau_drag)
large_radius = sum(tau_drag[(Nr - 3):(Nr - 1)])     # rings 10, 11, 12

@printf("\nTRPT drag torque balance\n")
@printf("  omega            %8.3f rad/s\n", w)
@printf("  tip speed        %8.1f m/s\n", w * hub_r)
@printf("  rotor torque     %+9.3f N.m\n", tau_aero)
@printf("  drag torque      %+9.3f N.m\n", total_drag)
@printf("  drag power       %+9.3f kW\n", total_drag * w / 1000)
@printf("  drag / rotor     %8.1f %%\n", 100 * abs(total_drag) / abs(tau_aero))
@printf("  rings 10-12 hold %8.1f %% of the drag\n",
    100 * abs(large_radius) / abs(total_drag))
@printf("  motion-only drag %+9.3f N.m (wind out of both calls)\n", sum(tau_drag_nowind))
@printf("  the wind's share %+9.3f N.m\n", total_drag - sum(tau_drag_nowind))

if total_drag < 0.0
    println("PASS  the drag opposes the rotation")
else
    push!(failures, "the drag torque does not oppose the rotation: $total_drag")
end

if abs(total_drag) < 0.5 * abs(tau_aero)
    println("PASS  the bound holds: the drag torque stays below the rotor torque")
else
    push!(
        failures,
        "the bound fails: drag $total_drag against rotor torque $tau_aero",
    )
end

if 5.0 <= abs(total_drag) <= 60.0
    println("PASS  the drag torque is inside the recorded bracket, 5 to 60 N.m")
else
    push!(
        failures,
        "the drag torque left the bracket: $(abs(total_drag)) N.m, outside 5 to 60",
    )
end

if abs(large_radius) > 0.6 * abs(total_drag)
    println("PASS  the loss sits in the large-radius rings, as the source says")
else
    push!(failures, "the drag is not concentrated at large radius: $large_radius")
end

if tau_aero > 0.0
    println("PASS  the rotor delivers torque at the operating point")
else
    push!(failures, "the rotor torque is not positive: $tau_aero")
end

println()
if isempty(failures)
    println("ALL TRPT DRAG TORQUE BALANCE TESTS PASS")
else
    println("FAILED: ", join(failures, ", "))
    error("FAILED: " * join(failures, ", "))
end
