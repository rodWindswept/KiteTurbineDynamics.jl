#!/usr/bin/env julia
# scripts/run_hunt.jl — canonical design hunt runner
# Encapsulates builder selection, spoke physics, GC management, and output.
#
# Usage:
#   julia --project=. scripts/run_hunt.jl --builder reinforced --winds 5,7,9,11,13,15
#   julia --project=. scripts/run_hunt.jl --builder l069-reinf --spokes --winds 11,13,15
#
# Builders: tight, reinforced, l069, l069-reinf
# Flags: --spokes (enable spoke radial force in ODE), --verbose, --dry-run

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

# ── Builder registry ──────────────────────────────────
const BUILDERS = Dict{String, Function}(
    "tight"      => () -> ControlMapHunt.v10_tight_builder(blade_scale=1.0),
    "l069"       => () -> ControlMapHunt.v10_tight_builder(blade_scale=0.69),
    "reinforced" => () -> ControlMapHunt.v10_tight_builder(
        blade_scale=1.0, r_bottom_scale=1.30, tether_diameter=0.004),
    "l069-reinf" => () -> ControlMapHunt.v10_tight_builder(
        blade_scale=0.69, r_bottom_scale=1.30, tether_diameter=0.004),
)

# ── Arg parsing ───────────────────────────────────────
function parse_args()
    d = Dict{String, Any}(
        "builder" => "reinforced",
        "winds"   => [5.0, 7.0, 9.0, 11.0, 13.0, 15.0],
        "spokes"  => false,
        "verbose" => false,
        "name"    => "",
        "out_dir" => joinpath(@__DIR__, "results", "control_maps"),
        "dry_run" => false,
        "rated"   => 50000.0,
    )
    i = 1
    while i <= length(ARGS)
        a = ARGS[i]
        if a == "--builder" && i < length(ARGS)
            d["builder"] = ARGS[i += 1]; i += 1
        elseif startswith(a, "--builder=")
            d["builder"] = a[11:end]; i += 1
        elseif a == "--winds" && i < length(ARGS)
            d["winds"] = parse.(Float64, split(ARGS[i += 1], ",")); i += 1
        elseif startswith(a, "--winds=")
            d["winds"] = parse.(Float64, split(a[8:end], ",")); i += 1
        elseif a == "--name" && i < length(ARGS)
            d["name"] = ARGS[i += 1]; i += 1
        elseif startswith(a, "--name=")
            d["name"] = a[7:end]; i += 1
        elseif a == "--spokes"; d["spokes"] = true; i += 1
        elseif a == "--verbose"; d["verbose"] = true; i += 1
        elseif a == "--dry-run"; d["dry_run"] = true; i += 1
        elseif a == "--out" && i < length(ARGS)
            d["out_dir"] = ARGS[i += 1]; i += 1
        elseif startswith(a, "--out=")
            d["out_dir"] = a[6:end]; i += 1
        elseif a == "--rated" && i < length(ARGS)
            d["rated"] = parse(Float64, ARGS[i += 1]); i += 1
        else; i += 1
        end
    end
    return d
end

# ── Main ──────────────────────────────────────────────
args = parse_args()
bname = args["builder"]
winds = args["winds"]
spokes_on = args["spokes"]
rated = args["rated"]
out_dir = args["out_dir"]
out_name = isempty(args["name"]) ? "hunt_$(bname)" : args["name"]
verbose = args["verbose"]

if !haskey(BUILDERS, bname)
    error("Unknown builder: $bname. Known: $(join(keys(BUILDERS), ", "))")
end

sp = SpokeParams(enabled=spokes_on)
fn = BUILDERS[bname]()

println("═════════════════════════════════════════════════════════")
println("KTD Design Hunt")
println("  builder: $bname")
println("  winds:   $winds")
println("  spokes:  $spokes_on")
println("  rated:   $(rated/1000) kW")
println("  output:  $out_dir/$out_name.csv")
println("═════════════════════════════════════════════════════════")

if args["dry_run"]
    println("DRY RUN — exiting.")
    exit(0)
end

mkpath(out_dir)

# Clear compiled cache
rm.(filter(endswith(".ji") || endswith(".so"),
    vcat(glob("*.ji", joinpath(homedir(), ".julia/compiled/v1.12/KiteTurbineDynamics")),
         glob("*.so", joinpath(homedir(), ".julia/compiled/v1.12/KiteTurbineDynamics")))),
    force=true)

# GC fix is in hunt_control_map (committed 2026-07-07)
df = ControlMapHunt.hunt_control_map(fn, rated, winds;
    out_dir=out_dir, name=out_name, verbose=verbose, max_power=true)

println("\n═══ Hunt complete: $(nrow(df)) rows ═══")
println(df)

# Post-process spokes if enabled
if spokes_on
    println("\n── Post-processing spoke data ──")
    include(joinpath(@__DIR__, "postprocess_gate2_spokes.jl"))
    # postprocess_gate2_spokes auto-discovers CSV files in out_dir
end
