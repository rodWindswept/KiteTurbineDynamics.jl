"""
Lift Kite Equilibrium Analysis
================================
Characterises the three lift device architectures (SingleKite, StackedKites,
RotaryLifter) across the TRPT operational wind speed range.

Outputs:
  scripts/results/lift_kite/lift_equilibrium.csv   — force balance table
  scripts/results/lift_kite/tension_variability.csv — tension CV comparison
  scripts/results/lift_kite/stack_tension_profile.csv — stacked kite profiles
  scripts/results/lift_kite/scaling_bottleneck.csv  — kite area vs rated power

Usage:
  julia --project=. scripts/lift_kite_equilibrium.jl
"""

using KiteTurbineDynamics, Printf, CSV, DataFrames
import Statistics: mean

OUT_DIR = joinpath(@__DIR__, "results", "lift_kite")
mkpath(OUT_DIR)

const RHO  = 1.225
const V_RATED = 11.0

# ── Lift devices — sized to achieve lift_margin ≥ 1.1 at rated conditions ──────
p10     = params_10kw()
single  = single_kite_sized(p10, RHO, V_RATED; margin = 1.1)  # auto-sized single kite
stack3  = stacked_kites_default(n_kites = 3, total_area = single.area)
stack5  = stacked_kites_default(n_kites = 5, total_area = single.area)
rotary  = rotary_lifter_default()   # fixed-omega rotary lifter

println("Sized single kite area: $(round(single.area, digits=1)) m² for 10 kW TRPT")

# ── 1. Required lift vs wind speed ─────────────────────────────────────────────
println("── 1. Hub lift requirement ──────────────────────────────────────────")
V_RANGE = 6.0:1.0:16.0

println("\n  v(m/s)  F_req(N)  M_airborne(kg)  lift_margin_single")
for v in V_RANGE
    F_req = hub_lift_required(p10, RHO, v)
    lm    = lift_margin(single, p10, RHO, v)
    m_t   = p10.n_lines * p10.tether_length *
            (970.0 * π * (p10.tether_diameter/2)^2)
    m_air = p10.n_blades * p10.m_blade + p10.n_rings * p10.m_ring + m_t
    @printf "  %5.1f  %8.1f  %14.2f  %17.2f\n" v F_req m_air lm
end

# ── 2. Force comparison across all devices ─────────────────────────────────────
println("\n── 2. Lift force comparison at each wind speed ──────────────────────")
eq_rows = DataFrame(
    v_wind      = Float64[],
    device      = String[],
    T_line_N    = Float64[],
    elevation   = Float64[],
    F_vertical  = Float64[],
    lift_margin = Float64[],
)

devices = [
    ("SingleKite",    single),
    ("Stack×3",       stack3),
    ("Stack×5",       stack5),
    ("RotaryLifter",  rotary),
]

for v in [6.0, 8.0, 10.0, 11.0, 13.0, 16.0]
    F_req = hub_lift_required(p10, RHO, v)
    for (name, dev) in devices
        F_hub, T, elev = lift_force_steady(dev, RHO, v)
        F_vert = T * sin(deg2rad(elev))
        lm     = F_vert / F_req
        push!(eq_rows, (v, name, T, elev, F_vert, lm))
    end
end

CSV.write(joinpath(OUT_DIR, "lift_equilibrium.csv"), eq_rows)

println("\n  v(m/s)  device           T_line(N)  elev(°)  F_vert(N)  margin")
println("  " * "─"^66)
for r in eachrow(eq_rows)
    @printf "  %5.1f  %-16s  %8.1f  %6.1f°  %8.1f  %6.2f\n" r.v_wind r.device r.T_line_N r.elevation r.F_vertical r.lift_margin
end

# ── 3. Tension variability comparison ─────────────────────────────────────────
println("\n── 3. Tension coefficient of variation (turbulence I=0.15) ──────────")
cv_rows = DataFrame(
    v_wind      = Float64[],
    device      = String[],
    T_mean_N    = Float64[],
    cv_pct      = Float64[],
    cv_rel_to_single = Float64[],
)

for v in [8.0, 10.0, 11.0, 13.0]
    _, T_single, _ = lift_force_steady(single, RHO, v)
    cv_single = tension_cv(single, RHO, v, 0.15) * 100.0

    for (name, dev) in devices
        _, T_mean, _ = lift_force_steady(dev, RHO, v)
        cv    = tension_cv(dev, RHO, v, 0.15) * 100.0
        cv_rel = cv / cv_single
        push!(cv_rows, (v, name, T_mean, cv, cv_rel))
    end
end

CSV.write(joinpath(OUT_DIR, "tension_variability.csv"), cv_rows)

println("\n  v(m/s)  device           T_mean(N)   CV(%)   CV/CV_single")
println("  " * "─"^60)
for r in eachrow(cv_rows)
    @printf "  %5.1f  %-16s  %8.1f  %6.2f%%  %9.3f\n" r.v_wind r.device r.T_mean_N r.cv_pct r.cv_rel_to_single
end

# ── 4. Stacked kite tension profile ───────────────────────────────────────────
println("\n── 4. Stack tension profiles ────────────────────────────────────────")
prof_rows = DataFrame(
    v_wind      = Float64[],
    n_kites     = Int[],
    position    = String[],   # "hub", "kite_1", "kite_2", etc.
    tension_N   = Float64[],
)

for (n_k, dev) in [(3, stack3), (5, stack5)]
    for v in [8.0, 11.0, 13.0]
        profile = stack_tension_profile(dev, RHO, v)
        static_top = topmost_kite_static_load(dev)
        @printf "  Stack×%d at v=%.0f m/s: hub=%.0f N, top_free_end=%.0f N | static top-kite load=%.0f N\n" n_k v profile[1] profile[end-1] static_top
        for (i, T) in enumerate(profile)
            label = i == 1 ? "hub" : (i == n_k+1 ? "above_top" : "above_kite_$(i-1)")
            push!(prof_rows, (v, n_k, label, T))
        end
    end
end

CSV.write(joinpath(OUT_DIR, "stack_tension_profile.csv"), prof_rows)

# ── 5. Kite area scaling bottleneck ───────────────────────────────────────────
println("\n── 5. Required kite area vs rated power ─────────────────────────────")
powers = [5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0]
scale_results = lift_area_vs_power(powers, RHO, V_RATED, single)

scale_rows = DataFrame(P_kw=Float64[], area_m2=Float64[], area_per_kw=Float64[])
println("\n  Power(kW)  Area_req(m²)  Area/kW(m²/kW)")
println("  " * "─"^40)
for (P, A) in scale_results
    @printf "  %8.1f  %12.1f  %14.3f\n" P A (A/P)
    push!(scale_rows, (P, A, A/P))
end

CSV.write(joinpath(OUT_DIR, "scaling_bottleneck.csv"), scale_rows)

# ── 6. Rotary lifter apparent wind advantage ───────────────────────────────────
println("\n── 6. Rotary lifter: apparent wind vs true wind ─────────────────────")
println("\n  v_wind  ω(rad/s)  v_app(m/s)  v_app/v_wind  CV_reduction_vs_single")
println("  " * "─"^66)
for v in [6.0, 8.0, 10.0, 11.0, 13.0, 16.0]
    ω      = rotary.omega_fixed    # fixed RPM — not TSR-following
    r_mean = (rotary.rotor_radius + rotary.hub_radius) / 2.0
    v_app  = sqrt(v^2 + (ω * r_mean)^2)
    cv_red = tension_cv_reduction(rotary, single, RHO, v, 0.15)
    @printf "  %6.1f  %8.2f  %10.2f  %12.2f  %22.3f\n" v ω v_app (v_app/v) cv_red
end

# ── Summary ────────────────────────────────────────────────────────────────────
println("\n── Summary ──────────────────────────────────────────────────────────")
println("Results written to: $OUT_DIR")
println("")
println("Key design numbers at v=11 m/s, 10 kW TRPT:")
v = 11.0
F_req = hub_lift_required(p10, RHO, v)
_, T_s, e_s   = lift_force_steady(single,  RHO, v)
_, T_r, e_r   = lift_force_steady(rotary,  RHO, v)
cv_s = tension_cv(single, RHO, v, 0.15) * 100
cv_r = tension_cv(rotary, RHO, v, 0.15) * 100
static_top3 = topmost_kite_static_load(stack3)
@printf "  Hub lift required       : %.0f N\n"    F_req
@printf "  Single kite (10 m²)     : T=%.0f N, elev=%.1f°, CV=%.1f%%\n"  T_s e_s cv_s
@printf "  Rotary lifter           : T=%.0f N, elev=%.1f°, CV=%.1f%%\n"  T_r e_r cv_r
@printf "  Stack×3 top-kite load   : %.0f N (static, zero wind)\n"   static_top3
@printf "  Rotary tension CV / Single CV: %.3f (%.0f%% reduction)\n" (cv_r/cv_s) ((1-cv_r/cv_s)*100)
println("")
