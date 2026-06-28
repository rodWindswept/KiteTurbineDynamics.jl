#!/usr/bin/env julia
# scripts/record_tuned.jl — V10 Tight at k=550 (tuned from hunt sweep)
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, CSV, DataFrames
include(joinpath(@__DIR__, "builders_util.jl"))

const DT = 4e-5; const SAVE_EVERY = 500
OUT_DIR = joinpath(@__DIR__, "results", "ramp_traces", "tuned")
mkpath(OUT_DIR)

function save_csv(name, df)
    if nrow(df) > 0
        path = joinpath(OUT_DIR, "$name.csv")
        CSV.write(path, df)
        @printf "  ✓ %s (%d rows)\n" path nrow(df)
    end
end

function total_twist_deg(u, sys)
    N = sys.n_total; Nr = sys.n_ring
    alpha = @view u[(6N + 1):(6N + Nr)]
    rad2deg(sum(mod(alpha[i+1] - alpha[i] + π, 2π) - π for i in 1:(Nr-1)))
end

function empty_trace_df()
    DataFrame(
        t=Float64[], k_mppt=Float64[], P_kw=Float64[],
        omega_hub=Float64[], omega_gnd=Float64[], delta_omega=Float64[],
        min_fos=Float64[], collapse_margin_deg=Float64[],
        twist_deg=Float64[], T_max_N=Float64[], state=String[],
    )
end

function run_one(sys, u0, p, label, k_val, controller, t_sim, wind_fn, lift)
    sys.k_mppt_ref[] = k_val
    if controller !== nothing
        reset!(controller)
        controller.P_target = p.p_rated_w
        init_geometry!(controller, sys, p)
    end
    print("  settling… "); flush(stdout)
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wind_fn)
    println("done")

    df = empty_trace_df()
    n_steps = round(Int, t_sim / DT)
    frame_dt = DT * SAVE_EVERY
    t0w = time()
    last_report = Ref(0.0)

    run_canonical_sim!(u, sys, p, wind_fn, n_steps, DT;
        lift_device=lift, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            if step % SAVE_EVERY == 0
                sf = capture_frame(u_curr, sys, p, t_curr, wind_fn, lift;
                    brake_engaged=sys.brake_engaged[])
                N = sys.n_total; Nr = sys.n_ring
                ω_hub = u_curr[6N + Nr + Nr]
                ω_gnd = u_curr[6N + Nr + 1]
                state_str = "fixed"
                if controller !== nothing
                    cm = min_collapse_margin(u_curr, sys, controller)
                    update_ramp!(controller, sys, sf, frame_dt;
                        min_fos=sf.fos_ring, collapse_margin_deg=cm)
                    state_str = string(controller.state)
                end
                push!(df, (t_curr, sys.k_mppt_ref[], sf.P_kw, ω_hub, ω_gnd,
                    ω_hub - ω_gnd, sf.fos_ring,
                    controller !== nothing ? min_collapse_margin(u_curr, sys, controller) : Inf,
                    total_twist_deg(u_curr, sys), sf.T_max, state_str))
                if t_curr - last_report[] >= 10.0 || t_curr >= t_sim - 0.01
                    last_report[] = t_curr
                    elapsed = time() - t0w
                    frac = t_curr / t_sim
                    eta = frac > 0 ? elapsed / frac * (1 - frac) : 0.0
                    @printf("  t=%5.1fs k=%.1f P=%.2fkW ω=%.1frpm FoS=%.2f [%ds ETA %ds]\n",
                        t_curr, sys.k_mppt_ref[], sf.P_kw, ω_hub*60/(2π), sf.fos_ring, round(Int,elapsed), round(Int,eta))
                end
            end
        end)
    println("  → $(nrow(df)) frames in $(round(time()-t0w,digits=1))s")
    return df
end

println("═"^60)
println("V10 Tight tuned — k_mppt = 550")
println("═"^60)

sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest)
wf(pos, t) = begin z=max(pos[3],1.0); [11.0*(z/p.h_ref)^(1.0/7.0), 0.0, 0.0] end
lift = rotary_lifter_default()

println("\n── Tuned instant (k=550) ──")
df_inst = run_one(sys, u0, p, "tuned-instant", 550.0, nothing, 60.0, wf, lift)
save_csv("v10_tight_tuned_instant", df_inst)

println("\n── Tuned soft-ramp (start k=550) ──")
sys2, u02, _ = Base.invokelatest(build_v10_tight_no_lowest)
ctrl = RampController(; k_min=110.0, k_max=1100.0, Kp=1e-4, P_target=50000.0)
df_ramp = run_one(sys2, u02, p, "tuned-ramp", 550.0, ctrl, 60.0, wf, lift)
save_csv("v10_tight_tuned_softramp", df_ramp)

println("\nDone.")
