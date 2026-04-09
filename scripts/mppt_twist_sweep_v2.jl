"""
MPPT Gain × Wind Speed — Twist Angle Sweep  (v2)
=================================================
Improved version of mppt_twist_sweep.jl.

Changes from v1:
  • T_SIM: 60 → 180 s  (allows high-k cases to fully settle)
  • K_MPPT_MULTS: adds 0.75 and 1.25 for finer resolution around nominal
  • Records T_max tether tension and mean tether tension per chunk
  • Records Δω = ω_hub − ω_gnd (shaft angular slip)
  • Records per-segment twist: lower/middle/upper thirds of stack
  • Settled window: last 20 s (was 10 s)
  • Wind ramp scenario appended after main sweep
  • Analytical twist comparison printed at the end

Research questions:
  1. Does twist settle or continue drifting with improved k resolution?
  2. Does the τ/T ratio at max power hold constant across wind speeds?
     (Analytical prediction: Δα_total ≈ (τ/T) × L_total / (n × r_s²))
  3. Where in the stack does twist concentrate?

Outputs (scripts/results/mppt_twist_sweep/):
  twist_sweep_v2.csv          — full time series
  twist_sweep_v2_summary.csv  — settled stats per combination
  twist_ramp_v2.csv           — wind ramp scenario

Usage:
  julia --project=. scripts/mppt_twist_sweep_v2.jl
  # background overnight:
  # nohup julia --project=. scripts/mppt_twist_sweep_v2.jl \\
  #   > scripts/results/mppt_twist_sweep/sweep_v2.log 2>&1 &

Estimated wall time (at ~10 min/combination for 60 s simulated):
  28 combinations × 30 min each ≈ 14 h  → run overnight
"""

using KiteTurbineDynamics, LinearAlgebra, Printf, CSV, DataFrames
import Statistics: mean, std

# ── Sweep parameters ──────────────────────────────────────────────────────────

K_MPPT_MULTS = [0.5, 0.75, 1.0, 1.25, 1.5, 2.5, 4.0]   # 7 levels
V_WIND_CASES = [8.0, 10.0, 11.0, 13.0]                   # m/s

K_MPPT_NOM   = 11.0          # N·m·s²/rad² — default from params_10kw()
DT           = 4e-5           # s
T_SPINUP     = 5.0            # s — spin-up before recording
T_SIM        = 180.0          # s — recorded duration
T_CHUNK      = 0.5            # s — recording interval
T_SETTLE     = 20.0           # s — window for settled statistics (last T_SETTLE s)

N_SPINUP     = round(Int, T_SPINUP / DT)
N_CHUNK      = round(Int, T_CHUNK  / DT)
N_CHUNKS     = round(Int, T_SIM    / T_CHUNK)

# ── Wind ramp parameters ───────────────────────────────────────────────────────
T_RAMP       = 150.0          # s total ramp time
V_RAMP_LO    = 7.0            # m/s  start
V_RAMP_HI    = 14.0           # m/s  end

# ── Output directory ──────────────────────────────────────────────────────────

OUT_DIR = joinpath(@__DIR__, "results", "mppt_twist_sweep")
mkpath(OUT_DIR)

# ── Helpers: tether tension (not exported from package, inlined here) ─────────

function _mid_tension_v2(u, sys, p, s, j)
    idx = (s - 1) * p.n_lines * 4 + (j - 1) * 4 + 2
    idx > length(sys.sub_segs) && return 0.0
    ss  = sys.sub_segs[idx]
    pa  = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
    pb  = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
    max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
end

function _tether_max_v2(u, sys, p)
    T = 0.0
    for s in 1:p.n_rings+1, j in 1:p.n_lines
        T = max(T, _mid_tension_v2(u, sys, p, s, j))
    end
    T
end

function _tether_mean_v2(u, sys, p)
    total = 0.0; n = 0
    for s in 1:p.n_rings+1, j in 1:p.n_lines
        total += _mid_tension_v2(u, sys, p, s, j); n += 1
    end
    n > 0 ? total / n : 0.0
end

# ── Helper: principal-value TRPT structural twist ─────────────────────────────

"""Total stack twist (°): principal-value sum from ring `r_a` to ring `r_b`."""
function partial_twist_deg(α, r_a, r_b)
    rad2deg(sum(i -> mod(α[i+1] - α[i] + π, 2π) - π, r_a:r_b-1))
end

function structural_twist_deg(u, N, Nr)
    α = @view u[6N+1 : 6N+Nr]
    partial_twist_deg(α, 1, Nr)
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
        base.p_rated_w, base.β_min, base.β_max, base.β_rate_max, base.kp_elev,
        base.EA_back_line, base.c_back_line, base.back_anchor_fwd_x
    )
end

# ── Build base system ─────────────────────────────────────────────────────────

println("Building base system…")
p_base       = params_10kw()
sys, u0_base = build_kite_turbine_system(p_base)
N, Nr        = sys.n_total, sys.n_ring
println("  N=$N nodes, Nr=$Nr rings")

# Stack is split into three equal thirds for per-segment twist
# Nr=16 rings → 15 inter-ring gaps: lower=1..5, middle=6..10, upper=11..15
n_seg   = Nr - 1          # 15
seg3    = n_seg ÷ 3       # 5 gaps per third
r_lo_a  = 1;   r_lo_b  = 1 + seg3          # rings 1..6  → lower 5 gaps
r_mid_a = 1 + seg3;  r_mid_b = 1 + 2*seg3  # rings 6..11 → middle 5 gaps
r_hi_a  = 1 + 2*seg3; r_hi_b = Nr          # rings 11..16 → upper 5 gaps

# ── DataFrame schemas ─────────────────────────────────────────────────────────

ts_rows = DataFrame(
    k_mult    = Float64[],
    k_mppt    = Float64[],
    v_wind    = Float64[],
    t         = Float64[],
    twist_deg = Float64[],   # total stack twist
    twist_lo  = Float64[],   # lower third (rings 1..6)
    twist_mid = Float64[],   # middle third (rings 6..11)
    twist_hi  = Float64[],   # upper third (rings 11..16)
    omega_hub = Float64[],
    omega_gnd = Float64[],
    delta_omega = Float64[], # shaft slip (hub − gnd)
    P_kw      = Float64[],
    T_max_N   = Float64[],   # peak tether tension
    T_mean_N  = Float64[],   # mean tether tension
)

sum_rows = DataFrame(
    k_mult         = Float64[],
    k_mppt         = Float64[],
    v_wind         = Float64[],
    twist_mean     = Float64[],
    twist_std      = Float64[],
    twist_lo_mean  = Float64[],
    twist_mid_mean = Float64[],
    twist_hi_mean  = Float64[],
    omega_hub_mean = Float64[],
    delta_omega_mean = Float64[],
    P_kw_mean      = Float64[],
    T_max_mean     = Float64[],
    T_mean_mean    = Float64[],
    tau_over_T     = Float64[],  # torque:tension ratio (τ = k_mppt × ω_gnd² × ω_gnd / ω_gnd = k×ω²; T=T_mean)
)

# ── Main sweep ────────────────────────────────────────────────────────────────

n_total_runs = length(K_MPPT_MULTS) * length(V_WIND_CASES)

for (run_idx, (k_mult, v_wind)) in enumerate(
        (k, v) for k in K_MPPT_MULTS for v in V_WIND_CASES)

    k_mppt = K_MPPT_NOM * k_mult
    p      = make_params(p_base; k_mppt=k_mppt, v_wind=v_wind)
    wfn    = (pos, t) -> [v_wind, 0.0, 0.0]

    @printf "\n[%2d/%d]  k×%.2f  v=%4.1f m/s  (k_mppt=%.2f)\n" run_idx n_total_runs k_mult v_wind k_mppt

    # 1. Settle geometry to gravity equilibrium
    print("  settling… ")
    flush(stdout)
    u = settle_to_equilibrium(sys, copy(u0_base), p)
    println("done")

    # 2. Spin-up
    @printf "  spin-up %.0f s… " T_SPINUP
    flush(stdout)
    t0w = time()
    u = simulate(sys, u, p, wfn; n_steps=N_SPINUP, dt=DT)
    @printf "done (%.0f s wall)\n" (time()-t0w)
    flush(stdout)

    # 3. Record T_SIM seconds
    t_sim = T_SPINUP
    t0w   = time()

    for chunk in 1:N_CHUNKS
        u      = simulate(sys, u, p, wfn; n_steps=N_CHUNK, dt=DT)
        t_sim += T_CHUNK

        α_vec    = @view u[6N+1 : 6N+Nr]
        ω_hub    = u[6N + Nr + Nr]
        ω_gnd    = u[6N + Nr + 1]
        twist    = partial_twist_deg(α_vec, 1,      Nr)
        tw_lo    = partial_twist_deg(α_vec, r_lo_a,  r_lo_b)
        tw_mid   = partial_twist_deg(α_vec, r_mid_a, r_mid_b)
        tw_hi    = partial_twist_deg(α_vec, r_hi_a,  r_hi_b)
        Δω       = ω_hub - ω_gnd
        P_kw     = p.k_mppt * ω_gnd^2 * abs(ω_gnd) / 1000.0
        T_max    = _tether_max_v2(u, sys, p)
        T_mean   = _tether_mean_v2(u, sys, p)

        push!(ts_rows, (k_mult, k_mppt, v_wind, t_sim,
                        twist, tw_lo, tw_mid, tw_hi,
                        ω_hub, ω_gnd, Δω, P_kw, T_max, T_mean))

        if chunk % 40 == 0 || chunk == N_CHUNKS
            elapsed = time() - t0w
            eta     = elapsed / chunk * (N_CHUNKS - chunk)
            @printf "  t=%6.1f s  twist=%7.2f°  lo=%5.1f° mid=%5.1f° hi=%5.1f°  Δω=%6.3f  T_max=%6.0f N  P=%5.2f kW  [wall %.0f s  ETA %.0f s]\n" t_sim twist tw_lo tw_mid tw_hi Δω T_max P_kw elapsed eta
            flush(stdout)
        end
    end

    # 4. Summary stats from settled region
    settled = filter(r -> r.k_mult == k_mult && r.v_wind == v_wind &&
                          r.t >= T_SPINUP + T_SIM - T_SETTLE, ts_rows)
    if !isempty(settled)
        τ_gen  = k_mppt * mean(settled.omega_gnd)^2 * abs(mean(settled.omega_gnd))  # N·m — approx generator torque
        T_ref  = mean(settled.T_mean_N)                                               # N — mean line tension
        τ_over_T = T_ref > 1.0 ? τ_gen / T_ref : NaN

        push!(sum_rows, (k_mult, k_mppt, v_wind,
                         mean(settled.twist_deg), std(settled.twist_deg),
                         mean(settled.twist_lo),  mean(settled.twist_mid), mean(settled.twist_hi),
                         mean(settled.omega_hub), mean(settled.delta_omega),
                         mean(settled.P_kw),
                         mean(settled.T_max_N), mean(settled.T_mean_N),
                         τ_over_T))

        r = last(sum_rows)
        @printf "  → settled twist = %6.1f ± %.1f °  (lo=%.1f°  mid=%.1f°  hi=%.1f°)\n" r.twist_mean r.twist_std r.twist_lo_mean r.twist_mid_mean r.twist_hi_mean
        @printf "     P = %.2f kW   Δω = %.3f rad/s   T_max = %.0f N   τ/T = %.4f m\n"   r.P_kw_mean r.delta_omega_mean r.T_max_mean r.tau_over_T
    end

    # Checkpoint save after each run
    CSV.write(joinpath(OUT_DIR, "twist_sweep_v2.csv"),  ts_rows)
    CSV.write(joinpath(OUT_DIR, "twist_sweep_v2_summary.csv"), sum_rows)
end

# ── Wind ramp scenario ────────────────────────────────────────────────────────

println("\n\n── Wind ramp scenario  (v = $V_RAMP_LO → $V_RAMP_HI m/s over $(T_RAMP) s, k×1.0) ──")

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

p_ramp  = make_params(p_base; k_mppt=K_MPPT_NOM, v_wind=V_RAMP_LO)
wfn_ramp = (pos, t) -> begin
    frac = clamp(t / T_RAMP, 0.0, 1.0)
    v    = V_RAMP_LO + frac * (V_RAMP_HI - V_RAMP_LO)
    [v, 0.0, 0.0]
end

print("  settling… ")
flush(stdout)
u_ramp = settle_to_equilibrium(sys, copy(u0_base), p_ramp)
println("done")

@printf "  spin-up %.0f s… " T_SPINUP
u_ramp = simulate(sys, u_ramp, p_ramp, wfn_ramp; n_steps=N_SPINUP, dt=DT)
println("done")

t_ramp    = T_SPINUP
N_RAMP    = round(Int, T_RAMP / T_CHUNK)
t0w       = time()

for chunk in 1:N_RAMP
    global u_ramp, t_ramp
    u_ramp   = simulate(sys, u_ramp, p_ramp, wfn_ramp; n_steps=N_CHUNK, dt=DT)
    t_ramp  += T_CHUNK

    frac    = clamp(t_ramp / T_RAMP, 0.0, 1.0)
    v_now   = V_RAMP_LO + frac * (V_RAMP_HI - V_RAMP_LO)
    α_vec   = @view u_ramp[6N+1 : 6N+Nr]
    ω_hub   = u_ramp[6N + Nr + Nr]
    ω_gnd   = u_ramp[6N + Nr + 1]
    twist   = partial_twist_deg(α_vec, 1, Nr)
    Δω      = ω_hub - ω_gnd
    P_kw    = p_ramp.k_mppt * ω_gnd^2 * abs(ω_gnd) / 1000.0
    T_max   = _tether_max_v2(u_ramp, sys, p_ramp)

    push!(ramp_rows, (t_ramp, v_now, twist, ω_hub, ω_gnd, Δω, P_kw, T_max))

    if chunk % 40 == 0 || chunk == N_RAMP
        @printf "  t=%6.1f s  v=%5.1f m/s  twist=%7.2f°  Δω=%6.3f  P=%5.2f kW\n" t_ramp v_now twist Δω P_kw
        flush(stdout)
    end
end

# ── Save all results ──────────────────────────────────────────────────────────

ts_path   = joinpath(OUT_DIR, "twist_sweep_v2.csv")
sum_path  = joinpath(OUT_DIR, "twist_sweep_v2_summary.csv")
ramp_path = joinpath(OUT_DIR, "twist_ramp_v2.csv")

CSV.write(ts_path,   ts_rows)
CSV.write(sum_path,  sum_rows)
CSV.write(ramp_path, ramp_rows)

@printf "\nSaved: %s  (%d rows)\n" ts_path   nrow(ts_rows)
@printf "Saved: %s  (%d rows)\n" sum_path   nrow(sum_rows)
@printf "Saved: %s  (%d rows)\n" ramp_path  nrow(ramp_rows)

# ── Analytical twist validation ───────────────────────────────────────────────
# Prediction: Δα_total ≈ (τ_gen / T_mean) × L_total / (n × r_hub²)
# where L_total = tether_length, n = n_lines, r_hub = trpt_hub_radius

println("\n── Analytical twist prediction vs simulation ─────────────────────────────")
L_total = p_base.tether_length
n_lines = Float64(p_base.n_lines)
r_s     = p_base.trpt_hub_radius
geom_factor = L_total / (n_lines * r_s^2)  # m⁻¹ · m² → rad/m per N·m/N

@printf "Geometry factor L/(n·r_s²) = %.4f  (L=%.0f m, n=%d, r_s=%.2f m)\n" geom_factor L_total Int(p_base.n_lines) r_s
println()
@printf "%-8s  %-8s  %-12s  %-12s  %-10s\n" "k_mult" "v (m/s)" "sim Δα (°)" "pred Δα (°)" "err (%)"
println("─"^60)
for r in eachrow(sum_rows)
    τ_gen     = r.k_mppt * r.omega_hub_mean^2 * abs(r.omega_hub_mean)
    T_ref     = r.T_mean_mean
    Δα_pred   = T_ref > 1.0 ? rad2deg(τ_gen / T_ref * geom_factor) : NaN
    err_pct   = (!isnan(Δα_pred) && abs(r.twist_mean) > 1.0) ?
                100.0 * (Δα_pred - r.twist_mean) / r.twist_mean : NaN
    @printf "%-8.2f  %-8.1f  %10.1f    %10.1f    %8.1f\n" r.k_mult r.v_wind r.twist_mean Δα_pred err_pct
end

println("\nDone. All results in: $OUT_DIR")
