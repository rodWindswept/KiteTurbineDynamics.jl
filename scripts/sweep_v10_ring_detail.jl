#!/usr/bin/env julia
# scripts/sweep_v10_ring_detail.jl
# Per-ring FoS sweep — identifies exactly which rings buckle and at what load.
# Results saved with per-ring FoS columns for structural redesign targeting.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, CSV, DataFrames
include(joinpath(@__DIR__, "builders_util.jl"))

const DT = 4e-5; const T_SIM = 60.0; const SAVE_EVERY = 500
OUT_DIR = joinpath(@__DIR__, "results", "ramp_traces", "sweep_2026-06-29")
mkpath(OUT_DIR)

function ring_fos_per_ring(sys::KiteTurbineSystem, u::Vector{Float64}, p::SystemParams, t::Float64, wind_fn)
    """Return per-ring FoS from ring_element_analysis. Lower = more buckled."""
    alpha_vec = @view u[(6*sys.n_total+1):(6*sys.n_total+sys.n_ring)]
    rea = ring_element_analysis(u, collect(alpha_vec), sys, p, t, wind_fn)
    n_rings = length(rea)
    fos = zeros(Float64, n_rings)
    for k in 1:n_rings
        util = isnan(rea[k].max_util) ? 0.0 : rea[k].max_util
        fos[k] = util > 0.0 ? 1.0 / util : Inf
    end
    return fos
end

function line_tensions_per_ring(sys::KiteTurbineSystem, u::Vector{Float64}, p::SystemParams)
    """Return max line tension / SWL. >1 = over SWL."""
    T_max_all, _ = get_max_rope_tension(u, sys, p)
    return [min(T_max_all / KiteTurbineDynamics.TETHER_SWL, 10.0)]
end

function total_twist_deg(u, sys)
    N = sys.n_total; Nr = sys.n_ring
    alpha = @view u[(6N + 1):(6N + Nr)]
    rad2deg(sum(mod(alpha[i+1] - alpha[i] + π, 2π) - π for i in 1:(Nr-1)))
end

function run_one_detailed(sys, u0, p, k_val, controller, wind_fn, lift, label)
    sys.k_mppt_ref[] = k_val
    if controller !== nothing
        reset!(controller); controller.P_target = p.p_rated_w
        init_geometry!(controller, sys, p)
    end
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wind_fn)
    N = sys.n_total; Nr = sys.n_ring
    # Determine actual ring count from ring_element_analysis (excludes ground ring)
    alpha_vec = @view u[(6N+1):(6N+Nr)]
    rea_pre = ring_element_analysis(u, collect(alpha_vec), sys, p, 0.0, wind_fn)
    n_rea_rings = length(rea_pre)

    if controller !== nothing && abs(u[6N+Nr+Nr]) >= controller.ω_idle
        controller.state = RAMPING
    end

    # Build column names
    ring_cols = ["fos_ring$i" for i in 1:n_rea_rings]
    line_cols = ["max_line_T_ratio"]
    cols = [:t, :k_mppt, :P_kw, :omega_hub, :omega_gnd, :delta_omega,
            :min_fos, :collapse_margin_deg, :twist_deg, :T_max_N]
    df = DataFrame([Float64[] for _ in cols], cols)
    df[!, :state] = String[]
    for rc in ring_cols; df[!, rc] = Float64[]; end
    for lc in line_cols; df[!, lc] = Float64[]; end

    n_steps = round(Int, T_SIM / DT); frame_dt = DT * SAVE_EVERY
    t0w = time(); last_report = Ref(0.0)

    run_canonical_sim!(u, sys, p, wind_fn, n_steps, DT;
        lift_device=lift, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            if step % SAVE_EVERY == 0
                sf = capture_frame(u_curr, sys, p, t_curr, wind_fn, lift;
                    brake_engaged=sys.brake_engaged[])
                ω_hub = u_curr[6N+Nr+Nr]; ω_gnd = u_curr[6N+Nr+1]
                state_str = "fixed"
                if controller !== nothing
                    cm = min_collapse_margin(u_curr, sys, controller)
                    update_ramp!(controller, sys, sf, frame_dt;
                        min_fos=sf.fos_ring, collapse_margin_deg=cm)
                    state_str = string(controller.state)
                end
                fos_vec = ring_fos_per_ring(sys, u_curr, p, t_curr, wind_fn)
                line_vec = line_tensions_per_ring(sys, u_curr, p)
                row = [t_curr, sys.k_mppt_ref[], sf.P_kw, ω_hub, ω_gnd,
                       ω_hub - ω_gnd, sf.fos_ring,
                       controller !== nothing ? min_collapse_margin(u_curr, sys, controller) : Inf,
                       total_twist_deg(u_curr, sys), sf.T_max]
                full_row = vcat(row, [state_str], fos_vec, line_vec)
                push!(df, full_row)
                if t_curr - last_report[] >= 15.0 || t_curr >= T_SIM - 0.01
                    last_report[] = t_curr; elapsed = time() - t0w
                    min_f = minimum(fos_vec); min_ring = argmin(fos_vec)
                    max_line = maximum(line_vec); max_seg = argmax(line_vec) + 1
                    @printf("  t=%5.1f k=%.0f P=%.1fkW ω=%.0frpm minFoS=%.2f@ring%d maxT/SWL=%.2f@seg%d [%ds]\n",
                        t_curr, sys.k_mppt_ref[], sf.P_kw, ω_hub*60/(2π),
                        min_f, min_ring, max_line, max_seg, round(Int,elapsed))
                end
            end
        end)
    return df
end

function save_csv(name, df)
    if nrow(df) > 0
        path = joinpath(OUT_DIR, "$name.csv")
        CSV.write(path, df)
        @printf "  %s (%d rows, %d cols)\n" path nrow(df) ncol(df)
    end
end

println("═"^60)
println("V10 Tight per-ring detail sweep — 2026-06-29")
println("═"^60)

sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest)
wf(pos, t) = begin z = max(pos[3], 1.0); [11.0 * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0] end
lift = rotary_lifter_default()

# k=62 instant — overspeed case
println("\n── k=62 instant ──")
df = run_one_detailed(sys, u0, p, 62.0, nothing, wf, lift, "k62")
save_csv("v10_tight_k062_ring_detail", df)

# k=200 instant — middle of the power curve
println("\n── k=200 instant ──")
sys2, u02, _ = Base.invokelatest(build_v10_tight_no_lowest)
df = run_one_detailed(sys2, u02, p, 200.0, nothing, wf, lift, "k200")
save_csv("v10_tight_k200_ring_detail", df)

# k=550 instant — heavy braking case
println("\n── k=550 instant ──")
sys3, u03, _ = Base.invokelatest(build_v10_tight_no_lowest)
df = run_one_detailed(sys3, u03, p, 550.0, nothing, wf, lift, "k550")
save_csv("v10_tight_k550_ring_detail", df)

println("\nDone. Results in: $OUT_DIR")
println("Per-ring FoS columns: fos_ring1 .. fos_ringN (N from ring_element_analysis)")
