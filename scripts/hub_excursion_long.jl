"""
Hub Excursion Long Run — Dynamic Lift Kite Analysis
=====================================================
60-second turbulent simulation per device at v_wind = 8, 11, 13 m/s.
Records hub position, elevation angle, power output, and shaft twist
at 0.05-s intervals for spectral and statistical analysis.

Devices compared:
  - SingleKite   (21.4 m² auto-sized for 10 kW at v_rated)
  - Stack×3      (same total area, 3 × 7.1 m²)
  - RotaryLifter (default, omega_fixed = 33 rad/s)
  - NoLift       (baseline: hub force-free, fixed by rope network only)

Outputs (appended per wind speed):
  results/lift_kite/long_timeseries.csv
  results/lift_kite/long_summary.csv
  results/lift_kite/long_psd.csv   ← Welch PSD of hub_z per device

Run time estimate: ~30 min on a single core (7 s wall / 1 s sim)

Usage:
  julia --project=. scripts/hub_excursion_long.jl
"""

using KiteTurbineDynamics, Printf, CSV, DataFrames
import Statistics: mean, std, var, cor
import FFTW: fft, fftfreq

OUT_DIR = joinpath(@__DIR__, "results", "lift_kite")
mkpath(OUT_DIR)

# ── Parameters ──────────────────────────────────────────────────────────────
const RHO        = 1.225
const T_SETTLE   = 10.0      # pre-record settling (with lift device active)
const T_SIM      = 60.0      # recording window — 2× integral time scale (31 s)
const DT         = 4e-5
const REC_EVERY  = 1250      # record every 1250 steps = 0.05 s
const TURB_I     = 0.15      # turbulence intensity (IEC Class A)
const V_WINDS    = [8.0, 11.0, 13.0]

p10     = params_10kw()
sys, u0 = build_kite_turbine_system(p10)
u_base  = settle_to_equilibrium(sys, u0, p10)

single  = single_kite_sized(p10, RHO, 11.0; margin = 1.1)   # size at v_rated
stack3  = stacked_kites_default(n_kites = 3, total_area = single.area)
rotary  = rotary_lifter_default()

hub_id = sys.rotor.node_id
N      = sys.n_total
Nr     = sys.n_ring
gnd_ri = 1   # ground ring index = 1

devices = [
    ("SingleKite",   single),
    ("Stack×3",      stack3),
    ("RotaryLifter", rotary),
    ("NoLift",       nothing),
]

println("="^70)
println("Hub Excursion Long Run")
println("  T_settle=$(T_SETTLE)s  T_sim=$(T_SIM)s  I=$(TURB_I)")
println("  Wind speeds: $V_WINDS m/s")
println("  Devices: ", join(first.(devices), ", "))
@printf "  Est. wall time: %.0f min\n" length(V_WINDS)*length(devices)*T_SIM*7/60
println("="^70)
flush(stdout)

# ── Storage ──────────────────────────────────────────────────────────────────
ts_all   = DataFrame(
    v_wind=Float64[], device=String[],
    t=Float64[],
    hub_x=Float64[], hub_y=Float64[], hub_z=Float64[],
    hub_r_xy=Float64[],   # horizontal displacement from t=0 position
    elev_deg=Float64[],
    omega_hub=Float64[], omega_gnd=Float64[],
    tau_gen=Float64[],    # generator torque (N·m)
    P_kw=Float64[],       # mechanical power output (kW)
    v_wind_inst=Float64[] # instantaneous wind at hub (m/s)
)

smry_all = DataFrame(
    v_wind=Float64[], device=String[],
    hub_z_mean=Float64[], hub_z_std=Float64[], hub_z_p95=Float64[],
    elev_mean=Float64[], elev_std=Float64[],
    P_mean_kw=Float64[], P_std_kw=Float64[], P_cv_pct=Float64[],
    omega_mean=Float64[], corr_time_s=Float64[]   # autocorr time of hub_z
)

psd_all = DataFrame(
    v_wind=Float64[], device=String[],
    freq_hz=Float64[], psd_m2_per_hz=Float64[]
)

# ── Welch PSD helper ─────────────────────────────────────────────────────────
function welch_psd(x::Vector{Float64}, fs::Float64; nperseg::Int = 128)
    n   = length(x)
    step = nperseg ÷ 2
    nwin = max(1, (n - nperseg) ÷ step + 1)
    freqs = fftfreq(nperseg, fs)[1:nperseg÷2+1]
    psd = zeros(length(freqs))
    win = 0.5 .* (1 .- cos.(2π .* (0:nperseg-1) ./ (nperseg - 1)))  # Hann
    win_power = sum(win .^ 2)
    for k in 0:nwin-1
        idx = k*step+1 : k*step+nperseg
        idx[end] > n && break
        seg = (x[idx] .- mean(x[idx])) .* win
        X   = fft(seg)
        psd .+= abs.(X[1:length(freqs)]) .^ 2
    end
    psd ./= (nwin * win_power * fs)
    psd[2:end-1] .*= 2.0   # one-sided
    return freqs, psd
end

# ── Autocorrelation time helper ───────────────────────────────────────────────
function autocorr_time(x::Vector{Float64}, dt::Float64)
    x0 = x .- mean(x)
    v0 = var(x)
    v0 < 1e-20 && return 0.0
    lag = 0
    while lag < length(x) - 1
        lag += 1
        r = mean(x0[1:end-lag] .* x0[lag+1:end]) / v0
        r < 1/ℯ && break
    end
    return lag * dt
end

# ── Main loop ─────────────────────────────────────────────────────────────────
for v_wind in V_WINDS
    println("\n▶  v_wind = $(v_wind) m/s")
    println("   " * "─"^60)
    flush(stdout)

    wind_1d = turbulent_wind(v_wind, TURB_I, T_SETTLE + T_SIM + 1.0; rng_seed = 42)
    wind_fn = (pos, t) -> [wind_1d(t), 0.0, 0.0]

    for (name, dev) in devices
        t_start_wall = time()
        u = copy(u_base)
        du = zeros(Float64, length(u))
        t = 0.0

        ode_params = dev === nothing ? (sys, p10, wind_fn) :
                                       (sys, p10, wind_fn, dev)

        n_settle = round(Int, T_SETTLE / DT)
        n_sim    = round(Int, T_SIM / DT)

        # Hub nominal position at end of settle (used for horizontal excursion)
        for _ in 1:n_settle
            fill!(du, 0.0)
            multibody_ode!(du, u, ode_params, t)
            t += DT
            @views u[3N+1:6N]        .+= DT .* du[3N+1:6N]
            @views u[1:3N]            .+= DT .* u[3N+1:6N]
            @views u[6N+Nr+1:6N+2Nr] .+= DT .* du[6N+Nr+1:6N+2Nr]
            @views u[6N+1:6N+Nr]     .+= DT .* u[6N+Nr+1:6N+2Nr]
            orbital_damp_rope_velocities!(u, sys, p10, 0.05)
            u[1:3] .= 0.0;  u[3N+1:3N+3] .= 0.0
        end

        hub_x0 = u[3*(hub_id-1)+1]
        hub_y0 = u[3*(hub_id-1)+2]

        # Recording loop
        local_ts = Tuple{Float64,Float64,Float64,Float64,Float64,Float64,Float64,Float64,Float64,Float64,Float64}[]

        for step in 1:n_sim
            fill!(du, 0.0)
            multibody_ode!(du, u, ode_params, t)
            t += DT
            @views u[3N+1:6N]        .+= DT .* du[3N+1:6N]
            @views u[1:3N]            .+= DT .* u[3N+1:6N]
            @views u[6N+Nr+1:6N+2Nr] .+= DT .* du[6N+Nr+1:6N+2Nr]
            @views u[6N+1:6N+Nr]     .+= DT .* u[6N+Nr+1:6N+2Nr]
            orbital_damp_rope_velocities!(u, sys, p10, 0.05)
            u[1:3] .= 0.0;  u[3N+1:3N+3] .= 0.0

            if mod(step, REC_EVERY) == 0
                hx = u[3*(hub_id-1)+1]
                hy = u[3*(hub_id-1)+2]
                hz = u[3*(hub_id-1)+3]
                r_xy  = sqrt((hx-hub_x0)^2 + (hy-hub_y0)^2)
                elev  = rad2deg(atan(hz, sqrt(hx^2+hy^2)))
                ω_hub = u[6N + Nr + Nr]           # hub ring (last ring)
                ω_gnd = u[6N + Nr + 1]            # ground ring = PTO input
                τ_gen = p10.k_mppt * ω_gnd^2 * sign(ω_gnd + 1e-9)
                P_kw  = τ_gen * abs(ω_gnd) / 1000.0
                v_inst = wind_1d(t)
                push!(local_ts, (t - T_SETTLE, hx, hy, hz, r_xy, elev,
                                  ω_hub, ω_gnd, τ_gen, P_kw, v_inst))
            end
        end

        # Append to master DataFrame
        for row in local_ts
            push!(ts_all, (v_wind, name, row...))
        end

        # Summary statistics
        sub  = filter(r -> r.v_wind == v_wind && r.device == name, ts_all)
        hz   = sub.hub_z
        el   = sub.elev_deg
        pw   = sub.P_kw
        om   = sub.omega_gnd
        rec_dt = REC_EVERY * DT
        τ_ac = autocorr_time(hz .- mean(hz), rec_dt)
        p95  = sort(hz)[round(Int, 0.95*length(hz))]
        push!(smry_all, (v_wind, name,
              mean(hz), std(hz), p95,
              mean(el), std(el),
              mean(pw), std(pw), std(pw)/max(mean(pw),0.001)*100,
              mean(abs.(om)),
              τ_ac))

        # Welch PSD of hub_z
        fs = 1.0 / rec_dt
        freqs, psd = welch_psd(hz, fs; nperseg = min(256, length(hz)÷4))
        for (f, p) in zip(freqs, psd)
            push!(psd_all, (v_wind, name, f, p))
        end

        wall = time() - t_start_wall
        pcv  = std(pw) / max(mean(pw), 0.001) * 100
        @printf "   %-14s  hub_z std=%.2fmm  P_mean=%.2fkW  P_cv=%.1f%%  wall=%.0fs\n" name (std(hz)*1000) mean(pw) pcv wall
        flush(stdout)
    end

    # Checkpoint after each wind speed
    CSV.write(joinpath(OUT_DIR, "long_timeseries.csv"), ts_all)
    CSV.write(joinpath(OUT_DIR, "long_summary.csv"),   smry_all)
    CSV.write(joinpath(OUT_DIR, "long_psd.csv"),       psd_all)
    println("   ✓ checkpoint written")
    flush(stdout)
end

println("\n" * "="^70)
println("COMPLETE")
println("="^70)
println("\nFull summary:")
println("\n  v(m/s)  device          hub_z_std(mm)  P_mean(kW)  P_cv(%)  corr_t(s)")
println("  " * "─"^68)
for r in eachrow(smry_all)
    @printf "  %6.1f  %-14s  %13.2f  %10.2f  %7.1f  %8.2f\n" r.v_wind r.device (r.hub_z_std*1000) r.P_mean_kw r.P_cv_pct r.corr_time_s
end
println("\nResults: $OUT_DIR/long_*.csv")
