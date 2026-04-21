#!/usr/bin/env julia
# scripts/power_curve_sweep.jl
#
# Generates a steady-state power curve for the 10 kW TRPT system.
# Sweeps wind speed from 4 to 15 m/s and records mechanical power,
# TSR, hub elevation, and shaft twist.
#
# Usage: julia --project=. scripts/power_curve_sweep.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, LinearAlgebra, Printf, CSV, DataFrames
import Statistics: mean, std

# ── Parameters ────────────────────────────────────────────────────────────────
V_WIND_CASES = [4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0]
DT           = 2e-5     # s — conservative; ring DOF removal raised mode count
T_SPINUP     = 5.0      # s — spin-up from settled u0 before recording
T_SIM        = 10.0     # s — recorded window (settled stats from last 5 s)
T_SETTLE_WIN = 5.0      # s — window for settled statistics
T_CHUNK      = 0.5      # s — recording interval

N_CHUNK   = round(Int, T_CHUNK   / DT)

OUT_DIR = joinpath(@__DIR__, "results", "power_curve")
mkpath(OUT_DIR)

# ── Helpers: tether tension (not exported from package) ────────────────────────
function _mid_tension(u, sys, p, s, j)
    idx = (s - 1) * p.n_lines * 4 + (j - 1) * 4 + 2
    idx > length(sys.sub_segs) && return 0.0
    ss  = sys.sub_segs[idx]
    pa  = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
    pb  = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
    max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
end
function _T_max(u, sys, p)
    T = 0.0
    for s in 1:p.n_rings+1, j in 1:p.n_lines
        T = max(T, _mid_tension(u, sys, p, s, j))
    end
    T
end
function _T_mean(u, sys, p)
    tot = 0.0; n = 0
    for s in 1:p.n_rings+1, j in 1:p.n_lines
        tot += _mid_tension(u, sys, p, s, j); n += 1
    end
    n > 0 ? tot / n : 0.0
end
function _twist_deg(u, N, Nr)
    α = @view u[6N+1:6N+Nr]
    rad2deg(sum(i -> mod(α[i+1]-α[i]+π, 2π)-π, 1:Nr-1))
end

# ── Build base system ──────────────────────────────────────────────────────────
println("Building base system (params_10kw)…")
p_base      = params_10kw()
sys, u0     = build_kite_turbine_system(p_base)
N, Nr       = sys.n_total, sys.n_ring
hub_gid     = sys.rotor.node_id
println("  N=$N nodes, Nr=$Nr rings, hub_gid=$hub_gid")

function make_params(v_wind; k_mppt=p_base.k_mppt)
    SystemParams(
        p_base.rho, v_wind, p_base.h_ref,
        p_base.elevation_angle, p_base.lifter_elevation,
        p_base.rotor_radius, p_base.tether_length,
        p_base.trpt_hub_radius, p_base.trpt_rL_ratio,
        p_base.n_lines, p_base.tether_diameter, p_base.e_modulus,
        p_base.n_rings, p_base.m_ring, p_base.n_blades, p_base.m_blade,
        p_base.cp, p_base.i_pto, k_mppt,
        p_base.p_rated_w, p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev,
        p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x
    )
end

# ── Settle to equilibrium (zero wind, from cold start) ────────────────────────
println("Settling to equilibrium…")
p_settle  = make_params(p_base.v_wind_ref)
u_settled = settle_to_equilibrium(sys, u0, p_settle)
println("  Done. Hub z = $(round(u_settled[3*hub_gid], digits=2)) m")

# Ring angular velocity indices: omega[i] = u[6N+Nr+i]  (i = 1..Nr)
# Ground ring = ring 1, hub ring = ring Nr
hub_ring_idx = Nr   # hub is the last ring

# ── Output schemas ────────────────────────────────────────────────────────────
pc_sum = DataFrame(
    v_wind       = Float64[],
    P_kw_mean    = Float64[],
    P_kw_std     = Float64[],
    omega_hub    = Float64[],
    omega_gnd    = Float64[],
    twist_mean   = Float64[],
    T_max_mean   = Float64[],
    T_mean_mean  = Float64[],
    hub_z_mean   = Float64[],
    hub_elev_deg = Float64[],
    tsr          = Float64[],   # tip speed ratio λ = ω_hub × R / v_hub
    cp_eff       = Float64[],   # effective system Cp = P / (0.5×ρ×A×v³)
)

pc_ts = DataFrame(
    v_wind    = Float64[],
    t         = Float64[],
    P_kw      = Float64[],
    omega_hub = Float64[],
    omega_gnd = Float64[],
    twist_deg = Float64[],
    hub_z     = Float64[],
)

TS_V_SHOW = Set([5.0, 8.0, 11.0, 13.0])   # save time series for these wind speeds

# ── Main sweep ────────────────────────────────────────────────────────────────
for (idx, v_wind) in enumerate(V_WIND_CASES)
    t_start = time()
    @printf("\n[%2d/%2d]  v_wind = %.1f m/s … ", idx, length(V_WIND_CASES), v_wind)
    flush(stdout)

    p = make_params(v_wind)
    wf = (pos, t) -> begin
        z = max(pos[3], 1.0)
        [p.v_wind_ref * (z / p.h_ref)^(1/7), 0.0, 0.0]
    end

    u = copy(u_settled)
    # Warm start at expected equilibrium for this wind
    ω_warm = 9.5 * (v_wind / 11.0)
    u = settle_to_operational_state(sys, u, p, ω_warm)

    chunk_P    = Float64[]
    chunk_ω_h  = Float64[]
    chunk_ω_g  = Float64[]
    chunk_tw   = Float64[]
    chunk_Tm   = Float64[]
    chunk_Tmn  = Float64[]
    chunk_hz   = Float64[]

    save_ts    = v_wind in TS_V_SHOW
    n_steps_sim = round(Int, T_SIM / DT)
    n_steps_settle_win = round(Int, (T_SIM - T_SETTLE_WIN) / DT)

    run_canonical_sim!(u, sys, p, wf, n_steps_sim, DT;
        lin_damp = 0.05,
        callback = (u_curr, t_curr, step) -> begin
            if step % N_CHUNK == 0
                ω_h = u_curr[6N + Nr + hub_ring_idx]
                ω_g = u_curr[6N + Nr + 1]
                pk  = p.k_mppt * ω_g^2 * abs(ω_g) / 1000.0
                tw  = _twist_deg(u_curr, N, Nr)
                Tm  = _T_max(u_curr, sys, p)
                Tmn = _T_mean(u_curr, sys, p)
                hz  = u_curr[3*(hub_gid-1)+3]

                if save_ts
                    push!(pc_ts, (v_wind, t_curr, pk, ω_h, ω_g, tw, hz))
                end
                
                # Use only stats from the final settlement window for the summary
                if step > n_steps_settle_win
                    push!(chunk_P,   pk)
                    push!(chunk_ω_h, ω_h)
                    push!(chunk_ω_g, ω_g)
                    push!(chunk_tw,  tw)
                    push!(chunk_Tm,  Tm)
                    push!(chunk_Tmn, Tmn)
                    push!(chunk_hz,  hz)
                end
            end
        end
    )

    # Settled statistics
    P_m   = mean(chunk_P);   P_s = std(chunk_P)
    ω_h_m = mean(chunk_ω_h);  ω_g_m = mean(chunk_ω_g)
    tw_m  = mean(chunk_tw);   Tm_m  = mean(chunk_Tm)
    Tmn_m = mean(chunk_Tmn);  hz_m  = mean(chunk_hz)
    elev  = rad2deg(atan(hz_m, sqrt(max(0, u[3*(hub_gid-1)+1]^2 + u[3*(hub_gid-1)+2]^2))))

    A_disc = π * p.rotor_radius^2
    v_hub  = v_wind * (hz_m / p.h_ref)^(1/7)
    P_avail_kw = 0.5 * p.rho * A_disc * v_hub^3 / 1000
    cp_eff     = P_avail_kw > 0.01 ? P_m / P_avail_kw : 0.0
    tsr        = ω_h_m > 0.01 ? ω_h_m * p.rotor_radius / v_hub : 0.0

    push!(pc_sum, (v_wind, P_m, P_s, ω_h_m, ω_g_m, tw_m, Tm_m, Tmn_m, hz_m, elev, tsr, cp_eff))

    @printf("P=%.2f kW  ω=%.2f rad/s  λ=%.2f  Cp_eff=%.3f  hub_z=%.1f m  (%.0f s wall)\n",
            P_m, ω_h_m, tsr, cp_eff, hz_m, time()-t_start)
end

# ── Save ──────────────────────────────────────────────────────────────────────
CSV.write(joinpath(OUT_DIR, "power_curve.csv"), pc_sum)
CSV.write(joinpath(OUT_DIR, "power_curve_ts.csv"), pc_ts)
println("\nSaved to $(OUT_DIR)")
println("Power curve summary:")
println(pc_sum[:, [:v_wind, :P_kw_mean, :tsr, :cp_eff, :hub_elev_deg]])
