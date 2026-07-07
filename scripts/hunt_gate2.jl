#!/usr/bin/env julia
# scripts/hunt_gate2.jl — Phase C: Gate 2 constrained control map
# Single hunt_control_map call per builder. Spoke data post-processed separately.
# Usage: julia --project=. scripts/hunt_gate2.jl [--builder lambda069|reinforced]

using Printf, CSV, DataFrames, Dates
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
using KiteTurbineDynamics

const OUT_DIR = joinpath(@__DIR__, "results", "control_maps")
const WINDS   = [5.0, 7.0, 9.0, 11.0, 13.0, 15.0]
const lift    = KiteTurbineDynamics.rotary_lifter_default()

const BUILDERS = Dict(
    "lambda069" => (fn=ControlMapHunt.v10_tight_builder(blade_scale=0.69),
                    name="gate2_lambda069", desc="λ=0.69"),
    "reinforced" => (fn=ControlMapHunt.v10_tight_builder(
                        r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0),
                    name="gate2_reinforced", desc="V10 Reinforced"),
)

function parse_args()
    filter = nothing; i = 1
    while i <= length(ARGS)
        arg=ARGS[i]
        if startswith(arg,"--builder="); filter=arg[11:end]
        elseif arg=="--builder" && i<length(ARGS); filter=ARGS[i+1]; i+=1; end
        i+=1
    end; return filter
end
builder_filter=parse_args()
to_run = isnothing(builder_filter) ? collect(keys(BUILDERS)) : filter(k->k==builder_filter, keys(BUILDERS))
isempty(to_run) && error("No builder. Valid: lambda069, reinforced")

println("═══════════════════════════════════════════════════════════")
println("Gate 2 — Constrained Control Map")
println("code: $(ControlMapHunt.GIT_HASH)  builders: $(join(to_run,", "))")
println("═══════════════════════════════════════════════════════════")

for bk in to_run
    b = BUILDERS[bk]
    println("\n═══ $(b.desc) ═══")

    # Single hunt call — all winds at once (proven machinery, no recompilation)
    df = ControlMapHunt.hunt_control_map(
        b.fn, 50000.0, WINDS;
        out_dir=OUT_DIR, name="$(b.name)_tmp", lift_device=lift,
        verbose=true, max_power=true)

    # Gate 2 CSV — Gate 1 columns + spoke/drag placeholders
    out = joinpath(OUT_DIR, "$(b.name)_summary.csv")
    open(out, "w") do io
        write(io, "# script:hunt_gate2 @ $(ControlMapHunt.GIT_HASH) · builder:$(b.name) · date:$(Dates.now()) · gate2:true · spokes:7mm_SWL19.8kN · POSTPROCESS_REQUIRED\n")
        write(io, "v_wind,k_mppt,P_kw,P_windowed,ω_rpm,min_fos,cm_deg,n_spokes,max_T_spoke_N,min_fos_spoke,spoke_drag_kW,tip_mach,stability\n")
        for row in eachrow(df)
            # Stability from verify timeseries
            slices = ControlMapHunt.run_verify_timeseries(
                b.fn, row.v_wind, row.k_mppt; verbose=false, lift_device=lift)
            stab = "ok"
            if length(slices) >= 2
                late = filter(s -> s.t_sim >= 40.0, slices)
                if length(late) >= 2
                    pv = [s.P_kw for s in late]
                    nr = (maximum(pv)-minimum(pv))/max(abs(mean(pv)),0.1)
                    if nr > 0.15; stab="unstable"
                    elseif nr > 0.05; stab="marginal"; end
                end
            end
            # Windowed-mean P
            late = filter(s -> s.t_sim >= 40.0, slices)
            P_win = isempty(late) ? row.P_kw : mean(s.P_kw for s in late)
            # Tip Mach estimate
            tm = row.ω_rpm * 2π/60 * 5.5 / 340.0
            write(io, "$(row.v_wind),$(row.k_mppt),$(row.P_kw),$P_win,$(row.ω_rpm),$(row.min_fos),$(row.cm_deg),0,0.0,Inf,0.0,$tm,$stab\n")
        end
    end
    println("  → $out")
end

println("\n═══ Gate 2 complete ═══")
