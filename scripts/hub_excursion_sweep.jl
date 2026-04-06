"""
Hub Excursion Sweep — Phase 2 Dynamic Lift Kite Analysis
==========================================================
Drives the TRPT hub with turbulent wind and records hub position variance
for three lift device architectures: SingleKite, StackedKites×3, RotaryLifter.

The lift kite force is applied quasi-statically at each ODE step via the
Phase 2 integration in ring_forces.jl.  The hub node is a free translational
state so it will sway under imbalanced forces between the lift line and the
TRPT shaft tension.

Outputs:
  scripts/results/lift_kite/hub_excursion_timeseries.csv
  scripts/results/lift_kite/hub_excursion_summary.csv

Usage:
  julia --project=. scripts/hub_excursion_sweep.jl
"""

using KiteTurbineDynamics, Printf, CSV, DataFrames
import Statistics: mean, std

OUT_DIR = joinpath(@__DIR__, "results", "lift_kite")
mkpath(OUT_DIR)

const RHO       = 1.225
const V_RATED   = 11.0
const T_SIM     = 3.0      # seconds of turbulent simulation per case
const T_SETTLE  = 1.0      # seconds to settle before recording hub position
const DT        = 4e-5     # integration step
const TURB_I    = 0.15     # turbulence intensity

# ── Setup ──────────────────────────────────────────────────────────────────
p10    = params_10kw()
sys, u0 = build_kite_turbine_system(p10)
u_base  = settle_to_equilibrium(sys, u0, p10)

# Sized single kite (margin ≥ 1.1 at v_rated)
single  = single_kite_sized(p10, RHO, V_RATED; margin = 1.1)
stack3  = stacked_kites_default(n_kites = 3, total_area = single.area)
rotary  = rotary_lifter_default()

hub_id  = sys.rotor.node_id
N       = sys.n_total

devices = [
    ("SingleKite",   single),
    ("Stack×3",      stack3),
    ("RotaryLifter", rotary),
    ("NoLift",       nothing),   # baseline: no lift device (static hub)
]

println("Hub excursion sweep — $(T_SIM)s turbulent simulation, I=$(TURB_I)")
println("Hub node global id: $hub_id, nominal elevation: $(round(u_base[3*(hub_id-1)+3], digits=2)) m")

# ── Turbulent wind at v=11 m/s ──────────────────────────────────────────────
# Turbulent wind function: returns a 3D wind vector for each (pos, t) call.
# Uses a pre-generated turbulence time series to ensure all cases see the
# same turbulent wind (reproducible comparison).
t_total   = T_SETTLE + T_SIM
n_steps_total = round(Int, t_total / DT)
t_vec     = range(0.0, t_total, length = n_steps_total + 1)

# Pre-generate a single turbulence realisation shared across all devices
rng_seed  = 42
wind_1d   = turbulent_wind(V_RATED, TURB_I, t_total + 1.0; rng_seed = rng_seed)
# turbulent_wind returns f(t::Float64)::Float64 — wrap to (pos, t) -> Vector
wind_3d(pos, t) = [wind_1d(t), 0.0, 0.0]

# ── Time-series storage ─────────────────────────────────────────────────────
ts_rows = DataFrame(
    device      = String[],
    t_sim       = Float64[],
    hub_x       = Float64[],
    hub_y       = Float64[],
    hub_z       = Float64[],
    hub_r_xy    = Float64[],   # horizontal displacement from nominal
    elev_deg    = Float64[],
    omega_hub   = Float64[],
    omega_gnd   = Float64[],
)

smry_rows = DataFrame(
    device      = String[],
    hub_z_mean  = Float64[],
    hub_z_std   = Float64[],
    hub_r_std   = Float64[],   # std of horizontal excursion
    elev_mean   = Float64[],
    elev_std    = Float64[],
)

# Nominal hub position from settled state (no lift device)
hub_nom_x = u_base[3*(hub_id-1)+1]
hub_nom_y = u_base[3*(hub_id-1)+2]
hub_nom_z = u_base[3*(hub_id-1)+3]
Nr        = sys.n_ring

# ── Run each device ─────────────────────────────────────────────────────────
for (name, dev) in devices
    println("\n── $(name) ──")
    u = copy(u_base)

    # Record interval: every 0.02 s (500 steps) during the main sim phase
    record_every = round(Int, 0.02 / DT)
    t  = 0.0
    dt = DT
    du = zeros(Float64, length(u))

    ode_params = dev === nothing ? (sys, p10, wind_3d) :
                                   (sys, p10, wind_3d, dev)

    n_settle = round(Int, T_SETTLE / DT)
    n_sim    = round(Int, T_SIM / DT)
    step_count = 0

    hz_rec = Float64[]
    hz_all = Float64[]

    for step in 1:(n_settle + n_sim)
        fill!(du, 0.0)
        multibody_ode!(du, u, ode_params, t)
        t += dt

        @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
        @views u[1:3N]            .+= dt .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
        @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]

        orbital_damp_rope_velocities!(u, sys, p10, 0.05)
        @views u[6N+Nr+1:6N+2Nr] .*= 1.0   # ang_damp = 1 (no angular kill)

        u[1:3]       .= 0.0
        u[3N+1:3N+3] .= 0.0

        # Record only during the sim phase (after settle), at record_every interval
        if step > n_settle && mod(step - n_settle, record_every) == 0
            hx  = u[3*(hub_id-1)+1]
            hy  = u[3*(hub_id-1)+2]
            hz  = u[3*(hub_id-1)+3]
            r_xy = sqrt((hx - hub_nom_x)^2 + (hy - hub_nom_y)^2)
            push!(hz_all, hz)

            # Elevation angle from ground position to hub
            hub_pos_now = [hx, hy, hz]
            elev_rad = atan(hz, sqrt(hx^2 + hy^2))
            elev_d   = rad2deg(elev_rad)

            omega_hub = u[6N + Nr + sys.n_ring]
            omega_gnd = u[6N + Nr + 1]

            t_rec = T_SETTLE + (step - n_settle) * dt
            push!(ts_rows, (name, t_rec, hx, hy, hz, r_xy, elev_d,
                            omega_hub, omega_gnd))
        end
    end

    # Summary statistics
    sub = filter(r -> r.device == name, ts_rows)
    hz_vec  = sub.hub_z
    rxy_vec = sub.hub_r_xy
    el_vec  = sub.elev_deg
    push!(smry_rows, (
        name,
        mean(hz_vec),  std(hz_vec),
        std(rxy_vec),
        mean(el_vec),  std(el_vec),
    ))

    @printf "  hub_z: mean=%.2f m  std=%.3f m  elev: mean=%.1f deg  std=%.2f deg\n" mean(hz_vec) std(hz_vec) mean(el_vec) std(el_vec)
end

# ── Write results ────────────────────────────────────────────────────────────
CSV.write(joinpath(OUT_DIR, "hub_excursion_timeseries.csv"), ts_rows)
CSV.write(joinpath(OUT_DIR, "hub_excursion_summary.csv"),   smry_rows)

println("\n── Summary ──────────────────────────────────────────────────────────")
println("\n  device           hub_z_mean(m)  hub_z_std(m)  hub_r_std(m)  elev_std(°)")
println("  " * "─"^72)
for r in eachrow(smry_rows)
    @printf "  %-16s  %13.2f  %12.4f  %12.4f  %10.3f\n" r.device r.hub_z_mean r.hub_z_std r.hub_r_std r.elev_std
end

println("\nResults written to: $OUT_DIR")
