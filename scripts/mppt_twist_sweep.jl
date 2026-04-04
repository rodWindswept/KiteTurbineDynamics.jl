"""
MPPT Gain × Wind Speed — Twist Angle Sweep
==========================================
Runs the TRPT kite turbine simulator for 60 simulated seconds at each
combination of MPPT gain multiplier and hub wind speed, recording
structural twist, rotor speed, PTO speed, and output power every 0.5 s.

Research question:
  Does steady-state TRPT twist angle carry useful information for
  controlling blade incidence (Cl/Cd) via hub ring bridling?

The twist angle is the sum of principal-value inter-ring angular offsets
from PTO (ground ring) to rotor (hub ring) — units: degrees.

Outputs (written to scripts/results/mppt_twist_sweep/):
  twist_sweep.csv        — full time series, one row per record step
  twist_sweep_summary.csv — mean settled values (last 10 s) per combination

Usage:
  julia --project=. scripts/mppt_twist_sweep.jl
  # or background:
  # nohup julia --project=. scripts/mppt_twist_sweep.jl \\
  #   > scripts/results/mppt_twist_sweep/sweep.log 2>&1 &

Estimated wall time: ~10 min per combination, ~3.5 h for full 24-point sweep.
Run on a free machine or overnight.
"""

using KiteTurbineDynamics, Printf, CSV, DataFrames
import Statistics: mean, std

# ── Sweep parameters ──────────────────────────────────────────────────────────

# k_mppt multipliers relative to nominal (11.0 N·m·s²/rad²)
#   0.25× → under-braked : hub overspeeds, shaft under-twisted
#   1.0×  → rated MPPT   : nominal operating point
#   4.0×  → over-braked  : hub stalled, shaft over-twisted
K_MPPT_MULTS = [0.25, 0.5, 1.0, 1.5, 2.5, 4.0]

# Hub wind speeds (m/s): below rated, near rated, rated, above rated
V_WIND_CASES = [8.0, 10.0, 11.0, 13.0]

K_MPPT_NOM   = 11.0          # N·m·s²/rad² — default from params_10kw()
DT           = 4e-5           # s — Euler integration step
T_SPINUP     = 5.0            # s — extra spin-up before recording (on top of settle)
T_SIM        = 60.0           # s — recorded simulation duration per combination
T_CHUNK      = 0.5            # s — record one data point per chunk

N_SPINUP     = round(Int, T_SPINUP / DT)
N_CHUNK      = round(Int, T_CHUNK  / DT)
N_CHUNKS     = round(Int, T_SIM    / T_CHUNK)

# ── Output directory ──────────────────────────────────────────────────────────

OUT_DIR = joinpath(@__DIR__, "results", "mppt_twist_sweep")
mkpath(OUT_DIR)

# ── Helper: principal-value TRPT structural twist ─────────────────────────────

function structural_twist_deg(u, N, Nr)
    α = @view u[6N+1 : 6N+Nr]
    rad2deg(sum(i -> mod(α[i+1] - α[i] + π, 2π) - π, 1:Nr-1))
end

# ── Helper: build SystemParams with only k_mppt and v_wind_ref varied ─────────

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
        base.p_rated_w, base.β_min, base.β_max, base.β_rate_max, base.kp_elev
    )
end

# ── Build base system once (geometry is the same for all runs) ────────────────

println("Building base system…")
p_base       = params_10kw()
sys, u0_base = build_kite_turbine_system(p_base)
N, Nr        = sys.n_total, sys.n_ring

# ── Sweep ─────────────────────────────────────────────────────────────────────

ts_rows   = DataFrame(k_mult=Float64[], k_mppt=Float64[], v_wind=Float64[],
                       t=Float64[], twist_deg=Float64[], omega_hub=Float64[],
                       omega_gnd=Float64[], P_kw=Float64[])
sum_rows  = DataFrame(k_mult=Float64[], k_mppt=Float64[], v_wind=Float64[],
                       twist_mean=Float64[], twist_std=Float64[],
                       omega_hub_mean=Float64[], P_kw_mean=Float64[])

n_total = length(K_MPPT_MULTS) * length(V_WIND_CASES)

for (run_idx, (k_mult, v_wind)) in enumerate(
        (k, v) for k in K_MPPT_MULTS for v in V_WIND_CASES)
    k_mppt = K_MPPT_NOM * k_mult
    p      = make_params(p_base; k_mppt=k_mppt, v_wind=v_wind)
    wfn    = (pos, t) -> [v_wind, 0.0, 0.0]

    @printf "\n[%2d/%d]  k×%.2f  v=%.0f m/s  (k_mppt=%.1f)\n" run_idx n_total k_mult v_wind k_mppt

    # 1. Settle geometry
    print("  settling gravity sag… ")
    flush(stdout)
    u = settle_to_equilibrium(sys, copy(u0_base), p)
    println("done")

    # 2. Extra spin-up at simulation conditions before we start recording
    @printf "  spin-up %.0f s… " T_SPINUP
    flush(stdout)
    t0w = time()
    u = simulate(sys, u, p, wfn; n_steps=N_SPINUP, dt=DT)
    @printf "done (%.0f s wall)\n" (time()-t0w)
    flush(stdout)

    # 3. Record T_SIM seconds in T_CHUNK-second chunks
    t_sim  = T_SPINUP
    t0w    = time()

    for chunk in 1:N_CHUNKS
        u     = simulate(sys, u, p, wfn; n_steps=N_CHUNK, dt=DT)
        t_sim += T_CHUNK

        ω_hub  = u[6N + Nr + Nr]
        ω_gnd  = u[6N + Nr + 1]
        twist  = structural_twist_deg(u, N, Nr)
        P_kw   = p.k_mppt * ω_gnd^2 * abs(ω_gnd) / 1000.0

        push!(ts_rows, (k_mult, k_mppt, v_wind, t_sim, twist, ω_hub, ω_gnd, P_kw))

        if chunk % 20 == 0 || chunk == N_CHUNKS
            elapsed = time() - t0w
            eta = elapsed / chunk * (N_CHUNKS - chunk)
            @printf "  t=%5.1f s  twist=%6.1f°  ω_hub=%5.2f  P=%5.2f kW  [wall %.0f s  ETA %.0f s]\n" t_sim twist ω_hub P_kw elapsed eta
            flush(stdout)
        end
    end

    # 4. Summary stats from last 10 s (settled region)
    settled = filter(r -> r.k_mult == k_mult && r.v_wind == v_wind &&
                          r.t >= T_SPINUP + T_SIM - 10.0, ts_rows)
    if !isempty(settled)
        push!(sum_rows, (k_mult, k_mppt, v_wind,
                         mean(settled.twist_deg), std(settled.twist_deg),
                         mean(settled.omega_hub), mean(settled.P_kw)))
        @printf "  → settled: twist = %.1f ± %.1f °  |  P = %.2f kW\n" last(sum_rows).twist_mean last(sum_rows).twist_std last(sum_rows).P_kw_mean
    end
end

# ── Save results ──────────────────────────────────────────────────────────────

ts_path  = joinpath(OUT_DIR, "twist_sweep.csv")
sum_path = joinpath(OUT_DIR, "twist_sweep_summary.csv")
CSV.write(ts_path,  ts_rows)
CSV.write(sum_path, sum_rows)

@printf "\nSaved: %s  (%d rows)\n" ts_path  nrow(ts_rows)
@printf "Saved: %s  (%d rows)\n" sum_path nrow(sum_rows)

# ── Print summary table ───────────────────────────────────────────────────────

println("\n── Settled twist (last 10 s) ─────────────────────────────────────────────")
@printf "%-8s  %-8s  %-12s  %-10s  %-8s\n" "k_mult" "v (m/s)" "twist (°)" "P (kW)" "ω_hub"
println("─"^56)
for r in eachrow(sum_rows)
    @printf "%-8.2f  %-8.1f  %6.1f ± %-4.1f  %-10.2f  %-8.2f\n" r.k_mult r.v_wind r.twist_mean r.twist_std r.P_kw_mean r.omega_hub_mean
end

println("\nDone. All results in: $OUT_DIR")
