#!/usr/bin/env julia
# scripts/hunt_gate2.jl — Phase C: Gate 2 constrained control map
# 2 builders × 6 winds. Spokes enabled, stability gate, adaptive verify.
# Usage: julia --project=. scripts/hunt_gate2.jl [--builder lambda069|reinforced]

using Printf, CSV, DataFrames, Dates, Statistics
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
using KiteTurbineDynamics; import KiteTurbineDynamics: SpokeParams

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
    filter = nothing
    i = 1
    while i <= length(ARGS)
        arg = ARGS[i]
        if startswith(arg, "--builder=")
            filter = arg[11:end]
        elseif arg == "--builder" && i < length(ARGS)
            filter = ARGS[i+1]; i += 1
        end
        i += 1
    end
    return filter
end
builder_filter = parse_args()
to_run = isnothing(builder_filter) ? collect(keys(BUILDERS)) : filter(k->k==builder_filter, keys(BUILDERS))
isempty(to_run) && error("No builder. Valid: lambda069, reinforced")

const spoke = SpokeParams(; enabled=true)

println("═══════════════════════════════════════════════════════════")
println("Gate 2 — Constrained Control Map")
println("code: $(ControlMapHunt.GIT_HASH)  spokes: $(spoke.d_line*1000)mm SWL=$(spoke.SWL_N/1000)kN")
println("═══════════════════════════════════════════════════════════")

for bk in to_run
    b = BUILDERS[bk]
    println("\n═══ $(b.desc) ═══")
    results = []

    for wind in WINDS
        t0 = time()
        print("  v=$(wind) → ")

        # Run Gate 1 max-power hunt (reuses proven machinery)
        df = ControlMapHunt.hunt_control_map(
            b.fn, 50000.0, [wind];
            out_dir=OUT_DIR, name="$(b.name)_tmp", lift_device=lift,
            verbose=false, max_power=true)

        if nrow(df) == 0 || occursin("power_deficit", string(df[1, :status]))
            println("no viable k (power_deficit)")
            push!(results, (v_wind=wind, k_mppt=NaN, P_kw=0.0, ω_rpm=0.0,
                min_fos=Inf, cm_deg=0.0, n_spokes=0, max_T_spoke_N=0.0,
                min_fos_spoke=Inf, spoke_drag_kW=0.0, tip_mach=0.0, stability="deficit"))
            continue
        end

        k = df[1, :k_mppt]
        P_g1 = df[1, :P_kw]
        ω_g1 = df[1, :ω_rpm]

        # Verify at 60s with Gate 1 columns
        slices = ControlMapHunt.run_verify_timeseries(
            b.fn, wind, k; verbose=false, lift_device=lift)
        s = slices[end]
        P_v = s.P_kw; ω_v = s.ω_rpm; fos_v = s.min_fos; cm_v = s.collapse_margin_deg

        # Windowed-mean P (final 20s)
        late = filter(x -> x.t_sim >= 40.0, slices)
        P_win = isempty(late) ? P_v : mean(x.P_kw for x in late)

        # Stability (calibrated: stable<5%, marginal<15%, unstable>15%)
        stab = "ok"
        if length(late) >= 2
            pv = [x.P_kw for x in late]
            nr = (maximum(pv)-minimum(pv))/max(abs(mean(pv)),0.1)
            if nr > 0.15; stab = "unstable"
            elseif nr > 0.05; stab = "marginal"; end
        end

        n_sp = 0; T_sp = 0.0; f_sp = Inf; drag_kW = 0.0
        # Spoke engagement: computed post-hoc by postprocess_gate2_spokes.jl
        # The hunt's min_fos IS the authoritative ring compression FoS.
        # Spoke/drag columns are supplementary and added after the hunt.

        # Tip Mach (caveat column) — approximation from Gate 1 radii
        tip_mach = ω_v * 2π / 60 * 5.5 / 340.0  # r_tip ≈ 5.5m for 2.7m ring + 2.8m span

        elapsed = round(time()-t0; digits=0)
        @printf("k=%.1f P=%.0fkW ω=%.0frpm FoS=%.2f spokeFoS=%.1f drag=%.1fkW stab=%s (%ds)\n",
            k, P_v, ω_v, fos_v, f_sp, drag_kW, stab, elapsed)

        push!(results, (v_wind=wind, k_mppt=k, P_kw=P_v, P_windowed=P_win,
            ω_rpm=ω_v, min_fos=fos_v, cm_deg=cm_v, n_spokes=n_sp,
            max_T_spoke_N=T_sp, min_fos_spoke=f_sp, spoke_drag_kW=drag_kW,
            tip_mach=tip_mach, stability=stab))
    end

    # Write CSV
    out = joinpath(OUT_DIR, "$(b.name)_summary.csv")
    open(out, "w") do io
        write(io, "# script:hunt_gate2 @ $(ControlMapHunt.GIT_HASH) · builder:$(b.name) · date:$(Dates.now()) · gate2:true · spokes:7mm_SWL$(spoke.SWL_N/1000)kN\n")
        write(io, "v_wind,k_mppt,P_kw,P_windowed,ω_rpm,min_fos,cm_deg,n_spokes,max_T_spoke_N,min_fos_spoke,spoke_drag_kW,tip_mach,stability\n")
        for r in results
            write(io, join([getfield(r, Symbol(c)) for c in
                ["v_wind","k_mppt","P_kw","P_windowed","ω_rpm","min_fos","cm_deg",
                 "n_spokes","max_T_spoke_N","min_fos_spoke","spoke_drag_kW","tip_mach","stability"]], ",") * "\n")
        end
    end

    println("\n  Wind   k      P_kW    ω_rpm  FoS   spokeFoS  dragkW  stab")
    for r in results
        k_s = isnan(r.k_mppt) ? "  —" : @sprintf("%5.1f", r.k_mppt)
        @printf("  %4.0f  %s  %6.0f  %5.0f  %4.2f  %6.1f  %5.1f  %s\n",
            r.v_wind, k_s, r.P_kw, r.ω_rpm, r.min_fos, r.min_fos_spoke,
            r.spoke_drag_kW, r.stability)
    end
    println("  → $out")
end

println("\n═══ Gate 2 complete ═══")
