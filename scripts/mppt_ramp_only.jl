"""
Wind ramp scenario — standalone run.
Runs only the 7→14 m/s ramp section from mppt_twist_sweep_v2.jl.
Use this after the main sweep has completed to fill in the missing twist_ramp_v2.csv.

Runtime: ~18 min.

Usage:
  julia --project=. scripts/mppt_ramp_only.jl
"""

using KiteTurbineDynamics, LinearAlgebra, Printf, CSV, DataFrames
import Statistics: mean, std

K_MPPT_NOM   = 11.0
DT           = 4e-5
T_SPINUP     = 5.0
T_CHUNK      = 0.5
T_RAMP       = 150.0
V_RAMP_LO    = 7.0
V_RAMP_HI    = 14.0

N_SPINUP = round(Int, T_SPINUP / DT)
N_CHUNK  = round(Int, T_CHUNK  / DT)
N_RAMP   = round(Int, T_RAMP   / T_CHUNK)

OUT_DIR = joinpath(@__DIR__, "results", "mppt_twist_sweep")
mkpath(OUT_DIR)

# Tether and generator metrics are imported from KiteTurbineDynamics.

function partial_twist_deg(α, r_a, r_b)
    rad2deg(sum(i -> mod(α[i+1] - α[i] + π, 2π) - π, r_a:r_b-1))
end

function make_params(base::SystemParams; k_mppt=base.k_mppt, v_wind=base.v_wind_ref)
    SystemParams(
        base.rho, v_wind, base.h_ref,
        base.elevation_angle, base.lifter_elevation,
        base.rotor_radius, base.tether_length,
        base.trpt_hub_radius, base.trpt_rL_ratio,
        base.n_lines, base.tether_diameter, base.e_modulus,
        base.n_rings, base.m_ring,
        base.n_blades, base.m_blade,
        base.cp, base.i_pto,
        k_mppt,
        base.p_rated_w, base.β_min, base.β_max, base.β_rate_max, base.kp_elev,
        base.EA_back_line, base.c_back_line, base.back_anchor_fwd_x
    )
end

println("Building base system…")
p_base       = params_10kw()
sys, u0_base = build_kite_turbine_system(p_base)
N, Nr        = sys.n_total, sys.n_ring
println("  N=$N nodes, Nr=$Nr rings")
default_lift = rotary_lifter_default()

ramp_rows = DataFrame(
    t         = Float64[],
    v_wind    = Float64[],
    twist_deg = Float64[],
    omega_hub = Float64[],
    omega_gnd = Float64[],
    delta_omega = Float64[],
    P_kw      = Float64[],
    T_max_N   = Float64[],
)

p_ramp   = make_params(p_base; k_mppt=K_MPPT_NOM, v_wind=V_RAMP_LO)
wfn_ramp = (pos, t) -> begin
    frac = clamp(t / T_RAMP, 0.0, 1.0)
    v    = V_RAMP_LO + frac * (V_RAMP_HI - V_RAMP_LO)
    [v, 0.0, 0.0]
end

println("\n── Wind ramp  (v = $(V_RAMP_LO) → $(V_RAMP_HI) m/s over $(T_RAMP) s) ──")
print("  settling… "); flush(stdout)
u_ramp = settle_to_equilibrium(sys, copy(u0_base), p_ramp)
println("done")

@printf "  spin-up %.0f s… " T_SPINUP
u_ramp = simulate(sys, u_ramp, p_ramp, wfn_ramp; n_steps=N_SPINUP, dt=DT)
println("done")

t_ramp = T_SPINUP
t0w    = time()

for chunk in 1:N_RAMP
    global u_ramp, t_ramp
    u_ramp  = simulate(sys, u_ramp, p_ramp, wfn_ramp; n_steps=N_CHUNK, dt=DT)
    t_ramp += T_CHUNK

    frac   = clamp(t_ramp / T_RAMP, 0.0, 1.0)
    v_now  = V_RAMP_LO + frac * (V_RAMP_HI - V_RAMP_LO)
    sf     = capture_frame(u_ramp, sys, p_ramp, t_ramp, wfn_ramp, default_lift; brake_engaged=sys.brake_engaged[])
    twist  = sf.delta_alpha_deg
    ω_hub  = sf.omega_hub
    ω_gnd  = sf.omega_gnd
    Δω     = ω_hub - ω_gnd
    P_kw   = sf.P_kw
    T_mx   = sf.T_max

    push!(ramp_rows, (t_ramp, v_now, twist, ω_hub, ω_gnd, Δω, P_kw, T_mx))

    if chunk % 40 == 0 || chunk == N_RAMP
        @printf "  t=%6.1f s  v=%5.1f m/s  twist=%7.2f°  Δω=%6.3f  P=%5.2f kW\n" t_ramp v_now twist Δω P_kw
        flush(stdout)
    end
end

ramp_path = joinpath(OUT_DIR, "twist_ramp_v2.csv")
CSV.write(ramp_path, ramp_rows)
@printf "\nSaved: %s  (%d rows)\n" ramp_path nrow(ramp_rows)
@printf "Wall time: %.0f s\n" (time() - t0w)
